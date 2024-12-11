#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"

#define READ_TIME 10000
#define ADJ_ARRAY 1000


module ApplicationP{
    provides interface Application;
    uses interface Packet;
    uses interface Timer<TMilli> as readTimer;
    uses interface Boot;
    uses interface Transport;
    uses interface List<string_entry_t> as userList;
}

implementation {
    uint8_t clientPort = 0; 
    char clientName[MAX_STRING_LENGTH];
    uint8_t clientSocket; 
    uint8_t serverNode = 1;
    uint8_t serverPort = 41;

    uint8_t data[MAX_NUM_OF_SOCKETS*ADJ_ARRAY];

    event void Boot.booted() {
        string_entry_t emptyString;
        int i;

        emptyString.fd = 0;

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            call userList.pushback(emptyString);
        }
    }

    command void Application.hello(uint8_t port, uint8_t *username) {
        
        // dbg(TRANSPORT_CHANNEL, "port: %d, username: %s\n", port, username);
        clientPort = port;

        strncpy(clientName, (char *)username, MAX_STRING_LENGTH - 1);
        clientName[MAX_STRING_LENGTH - 1] = '\0';

        clientSocket = call Transport.setTestClient(clientPort, serverNode, serverPort, 0);
        // dbg(APPLICATION_CHANNEL, "socket: %d\n", clientSocket);
    }

    command void Application.broadMessage(uint8_t *message) {
        char payload[100];
        dbg(TRANSPORT_CHANNEL, "MESSAGE\n");

        snprintf(payload, sizeof(payload), "%s %s\r\n", "msg", message);

        call Transport.write(clientSocket, strlen(payload), (uint16_t *)payload);
    }

    command void Application.uniMessage(uint8_t *username, uint8_t *message) {
        char payload[100];
        dbg(TRANSPORT_CHANNEL, "WHISPER\n");

        snprintf(payload, sizeof(payload), "%s %s %s\r\n", "whisper", username, message);

        call Transport.write(clientSocket, strlen(payload), (uint16_t *)payload);
    }

    command void Application.printUsers() {
        char payload[100];
        dbg(TRANSPORT_CHANNEL, "PRINT USERS\n");

        snprintf(payload, sizeof(payload), "%s\r\n", "listusr");

        call Transport.write(clientSocket, strlen(payload), (uint16_t *)payload);
    }

    event void Transport.connected() {
        char message[100];

        dbg(TRANSPORT_CHANNEL, "CONNECTED\n");

        snprintf(message, sizeof(message), "%s %s\r\n", "hello", clientName);

        // dbg(TRANSPORT_CHANNEL, "Length: %d, Message: %s\n", strlen(message), message);
        call Transport.write(clientSocket, strlen(message), (uint16_t *)message);
    }

    event void Transport.accepted() {
        dbg(TRANSPORT_CHANNEL, "ACCEPTED\n");
        call readTimer.startPeriodic(READ_TIME);
    }

    void readCommands() {
        int i, j;
        char commandBuffer[ADJ_ARRAY + 1];
        char *payload;
        size_t len;
        string_entry_t string_entry;
        string_entry_t temp_entry;
        char *username;
        char *message;

        dbg(TRANSPORT_CHANNEL, "Parsing Commands from DATA Buffer:\n");

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            int sectionStart = i * ADJ_ARRAY;
            int sectionEnd = sectionStart + ADJ_ARRAY;
            int bufferIndex = 0;
            char *token;
            char payloadToSend[SOCKET_BUFFER_SIZE];
            char payloadToSend2[SOCKET_BUFFER_SIZE];

            memset(commandBuffer, 0, sizeof(commandBuffer));

            if (data[sectionStart] == 0) {
                continue;
            }

            for (j = sectionStart; j < sectionEnd && data[j] != 0; j++) {
                commandBuffer[bufferIndex++] = data[j];
            }
            commandBuffer[bufferIndex] = '\0';

            len = bufferIndex;
            // Validate that the command ends with '\r\n'
            if (len < 2 || commandBuffer[len-2] != '\r' || commandBuffer[len-1] != '\n') {
                dbg(APPLICATION_CHANNEL, "Invalid command: does not end with '\\r\\n': %s\n", commandBuffer);
                continue;
            }

            token = strtok(commandBuffer, "\r\n");
            while (token != NULL) {
                // dbg(APPLICATION_CHANNEL, "Socket <%d> Command: %s\n", i+1, token);

                if (strncmp(token, "hello", 5) == 0) {
                    dbg(TRANSPORT_CHANNEL, "--> Detected 'hello' command: %s\n", token);
                    dbg(APPLICATION_CHANNEL, "--> Detected 'hello' command: %s\n", token);
                    
                    payload = token + 6;

                    if (*payload != '\0') {
                        memset(&string_entry, 0, sizeof(string_entry));
                        strncpy(string_entry.value, payload, MAX_STRING_LENGTH - 1);

                        string_entry.fd = i+1;

                        dbg(APPLICATION_CHANNEL, "Adding user %s on <%d>\n", string_entry.value, string_entry.fd);                        
                        call userList.replace(string_entry.fd, string_entry);
                    }
                }

                else if (strncmp(token, "msg", 3) == 0) {
                    dbg(TRANSPORT_CHANNEL, "--> Detected 'msg' command: %s\n", token);
                    dbg(APPLICATION_CHANNEL, "--> Detected 'msg' command: %s\n", token);
                    
                    payload = token + 4;

                    while (*payload == ' ') {
                        payload++;
                    }

                    if (*payload != '\0') {
                        // dbg(APPLICATION_CHANNEL, "Extracted message: %s\n", payload);

                        temp_entry = call userList.get(i+1);

                        snprintf(payloadToSend, sizeof(payloadToSend), "I recevied a message from %s: %s\r\n", temp_entry.value, payload);
                            
                        dbg(APPLICATION_CHANNEL, "Sending message: %s\n", payloadToSend);
                        call Transport.write(0, strlen(payloadToSend), (uint16_t *)payloadToSend);
                    }
                }

                else if (strncmp(token, "whisper", 7) == 0) {
                    dbg(TRANSPORT_CHANNEL, "--> Detected 'whisper' command: %s\n", token);
                    dbg(APPLICATION_CHANNEL, "--> Detected 'whisper' command: %s\n", token);

                    payload = token + 8;

                    username = strtok(payload, " ");
                    message = strtok(NULL, "");

                    if (username != NULL && message != NULL) {
                        // dbg(APPLICATION_CHANNEL, "Extracted username: %s, message: %s\n", username, message);

                        for (j = 0; j < call userList.size(); j++) {
                            string_entry = call userList.get(j+1);
                            temp_entry = call userList.get(i+1);
                            if (strncmp(string_entry.value, username, MAX_STRING_LENGTH) == 0) {
                                dbg(APPLICATION_CHANNEL, "Found user: %s with socket: %d\n", string_entry.value, string_entry.fd);

                                snprintf(payloadToSend, sizeof(payloadToSend), "I recevied a message from %s: %s\r\n", temp_entry.value, message);
                                
                                // dbg(APPLICATION_CHANNEL, "Sending message: %s\n", payloadToSend);
                                call Transport.write(string_entry.fd, strlen(payloadToSend), (uint16_t *)payloadToSend);
                                break;
                            }
                        }
                    }
                }

                else if (strncmp(token, "listusr", 7) == 0) {
                    dbg(TRANSPORT_CHANNEL, "--> Detected 'listusr' command\n");
                    dbg(APPLICATION_CHANNEL, "--> Detected 'listusr' command\n");
                    
                    len = snprintf(payloadToSend2, sizeof(payloadToSend2), "User list:\n");

                    for (j = 0; j < call userList.size(); j++) {
                        string_entry = call userList.get(j + 1);
                        if (string_entry.fd != 0 && string_entry.value[0] != '\0') {
                            len += snprintf(payloadToSend2 + len, sizeof(payloadToSend2) - len, "- %s\n", string_entry.value);
                        }
                    }
                    strncat(payloadToSend2, "\r\n", sizeof(payloadToSend2) - len - 1);

                    temp_entry = call userList.get(i+1);
                        
                    // dbg(APPLICATION_CHANNEL, "Sending message: %s\n", payloadToSend2);
                    call Transport.write(temp_entry.fd, strlen(payloadToSend2), (uint16_t *)payloadToSend2);
                }

                else {
                    dbg(TRANSPORT_CHANNEL, "--> %s\n", token);
                    dbg(APPLICATION_CHANNEL, "--> %s\n", token);
                }

                token = strtok(NULL, "\r\n");
            }

            memset(&data[sectionStart], 0, ADJ_ARRAY);
        }
    }

    event void readTimer.fired() {
        uint8_t* tempData;
        int i;
        int j;
        char buffer[MAX_NUM_OF_SOCKETS*ADJ_ARRAY+1];
        int bufIndex = 0;
        bool dataPresent = FALSE;

        tempData = call Transport.read();

        for (i = 0; i < MAX_NUM_OF_SOCKETS*SOCKET_BUFFER_SIZE; i++) {
            if (tempData[i] != 0) {
                dataPresent = TRUE;
                break;    
            }
        }
        if (!dataPresent) {
            return;
        }

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            int topStartIndex = i * ADJ_ARRAY;
            int bottomStartIndex = i * SOCKET_BUFFER_SIZE;
            int topNextAvailable = topStartIndex;

            while (topNextAvailable < topStartIndex + ADJ_ARRAY && data[topNextAvailable] != 0) {
                topNextAvailable++;
            }

            // dbg(TRANSPORT_CHANNEL, "Socket (%d) topNextAvailable: %d topStartIndex: %d\n", i, topNextAvailable, topStartIndex + ADJ_ARRAY);

            for (j = 0; j < SOCKET_BUFFER_SIZE; j++) {
                if (tempData[bottomStartIndex + j] == 0) {
                    break;
                }

                if (topNextAvailable < topStartIndex + ADJ_ARRAY) {
                    data[topNextAvailable++] = tempData[bottomStartIndex + j];
                } else {
                    dbg(TRANSPORT_CHANNEL, "Section %d in top data array is full, truncating additional data.\n", i);
                    break;
                }
            }
        }

        dbg(TRANSPORT_CHANNEL, "Accumulated DATA Buffer:\n");
        for (i = 0; i < MAX_NUM_OF_SOCKETS*ADJ_ARRAY; i++) {
            if (data[i] != 0) {
                buffer[bufIndex++] = data[i];            
            }
        }
        buffer[bufIndex] = '\0';
        dbg(TRANSPORT_CHANNEL, "%s\n", buffer);

        readCommands();
    }
}