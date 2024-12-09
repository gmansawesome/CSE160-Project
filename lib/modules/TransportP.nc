#include "../../includes/packet.h"
#include "../../includes/tcp_packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"

#define READ_TIME 10000
#define RETRANSMIT_TIME 1000
#define CONNECT_DONE_TIME 1000

module TransportP{
    provides interface Transport;
    uses interface Packet;
    uses interface Receive;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as serverTimer;
    uses interface Timer<TMilli> as clientTimer;
    uses interface Timer<TMilli> as connectDone;
    uses interface Timer<TMilli> as closeTimer;
    uses interface Boot;
    uses interface Routing;
    uses interface List<socket_store_t>;
    uses interface List<retransmit_pack_t> as packQueue;
}

implementation {
    uint16_t transferData[MAX_NUM_OF_SOCKETS];
    uint16_t totalRead[MAX_NUM_OF_SOCKETS];
    uint8_t skips[MAX_NUM_OF_SOCKETS];
    uint8_t skipFrequency[MAX_NUM_OF_SOCKETS];

    void enqueueRetransmit(socket_t fd, pack msg) {
        retransmit_pack_t retransmitEntry;
        retransmitEntry.socket = fd;
        retransmitEntry.retransmitPacket = msg;
        retransmitEntry.retries = 0;

        dbg(TRANSPORT_CHANNEL, "Enqueueing packet for retransmission on socket %d, Seq: %d, Flag: %d\n", fd, msg.seq, ((tcp_pack*)msg.payload)->flag);
        call packQueue.pushback(retransmitEntry);
        call clientTimer.startOneShot(RETRANSMIT_TIME);
    }

    static inline bool seqNumGreaterThan(uint8_t a, uint8_t b) {
        return ((a > b) && (a - b < 128)) || ((a < b) && (b - a > 128));
    }

    static inline bool seqNumLessThanOrEqual(uint8_t a, uint8_t b) {
        return !seqNumGreaterThan(a, b);
    }

    static inline bool seqNumLessThan(uint8_t a, uint8_t b) {
        return ((a < b) && (b - a < 128)) || ((a > b) && (a - b > 128));
    }

    void removeAcknowledgedPackets(socket_t fd, uint16_t ack) {
        retransmit_pack_t retransmitEntry;
        uint8_t i;

        for (i = 1; i <= call packQueue.size(); i++) {
            retransmitEntry = call packQueue.get(i);
            if (retransmitEntry.socket == fd && seqNumLessThan(retransmitEntry.retransmitPacket.seq, ack)) {
                dbg(TRANSPORT_CHANNEL, "Removing acknowledged packet on socket %d with Seq: %d\n", fd, retransmitEntry.retransmitPacket.seq);
                call packQueue.remove(i);
                i--;
            }
        }
    }

    event void Boot.booted() {
        uint8_t i;
        uint8_t j;
        socket_store_t emptySocket;

        emptySocket.flag = 0;
        emptySocket.state = CLOSED;
        emptySocket.src = 0;
        emptySocket.dest.port = 0;
        emptySocket.dest.addr = 0;

        for (j = 0; j < SOCKET_BUFFER_SIZE; j++) {
            emptySocket.sendBuff[j] = 0;
        }
        emptySocket.lastWritten = 0;
        emptySocket.lastSent = 0;

        for (j = 0; j < SOCKET_BUFFER_SIZE; j++) {
            emptySocket.rcvdBuff[j] = 0;
        }
        emptySocket.lastRead = 0;
        emptySocket.lastRcvd = 0;
        emptySocket.nextExpected = 0;

        emptySocket.RTT = 0;
        emptySocket.effectiveWindow = SOCKET_BUFFER_SIZE;

        // dbg(TRANSPORT_CHANNEL, "Initializing Sockets\n");
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            // dbg(TRANSPORT_CHANNEL, "Initialized Socket %d\n", i);
            call List.pushback(emptySocket);
            transferData[i] = 0;
            totalRead[i] = 0;
            skips[i] = 0;
            skipFrequency[i] = 0;
        }
    }

    command socket_t Transport.socket() {
        uint8_t i;
        socket_t fd;
        socket_store_t socket;

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);
            // dbg(TRANSPORT_CHANNEL, "Socket %d state: %d\n", i, socket.state);
            if (socket.state == CLOSED) {
                fd = i;
                // dbg(TRANSPORT_CHANNEL, "Found Socket %d\n", fd);
                return fd;
            }
        }

        fd = NULL;
        return fd;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {
        socket_store_t socket;

        socket = call List.get(fd);

        if (addr->addr == TOS_NODE_ID) {
            socket.src = addr->port;
            // dbg(TRANSPORT_CHANNEL, "Socket.src = %d\n", socket.src);
        }

        call List.replace(fd, socket);

        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd) {
        socket_store_t socket;

        socket = call List.get(fd);

        socket.state = LISTEN;

        call List.replace(fd, socket);

        return SUCCESS;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
        pack msg;
        tcp_pack TCPmsg;
        socket_store_t socket;
        uint8_t nextHop;

        // dbg(TRANSPORT_CHANNEL, "Starting connection\n");
        socket = call List.get(fd);

        msg.dest = addr->addr;
        msg.src = TOS_NODE_ID;
        msg.seq = 0;
        msg.TTL = MAX_TTL;
        msg.protocol = PROTOCOL_TCP;

        TCPmsg.srcPort = socket.src;
        TCPmsg.destPort = addr->port;
        TCPmsg.seq = 1;
        TCPmsg.ACK = 0;
        TCPmsg.flag = SYN_FLAG;
        TCPmsg.window = 0;

        // dbg(TRANSPORT_CHANNEL, "Dest: %d\n", msg.dest);

        if (sizeof(TCPmsg) <= PACKET_MAX_PAYLOAD_SIZE) {
            // dbg(TRANSPORT_CHANNEL, "copying\n");
            memcpy(msg.payload, &TCPmsg, sizeof(TCPmsg));
        } else {
            return FAIL;
        }

        socket.state = SYN_SENT;
        // dbg(TRANSPORT_CHANNEL, "CLOSED -> SYN_SENT\n");
        call List.replace(fd, socket);

        call SimpleSend.send(msg, call Routing.nextHop(msg.dest));
        
        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {
        pack msg;
        tcp_pack TCPmsg;
        socket_store_t socket;
        uint8_t nextHop;

        socket = call List.get(fd);

        dbg(TRANSPORT_CHANNEL, "CLOSING Socket <%d>\n", fd);

        socket.state = FIN_WAIT_1;

        msg.dest = socket.dest.addr;
        msg.src = TOS_NODE_ID;
        msg.seq = 0;
        msg.TTL = MAX_TTL;
        msg.protocol = PROTOCOL_TCP;

        TCPmsg.srcPort = socket.src;
        TCPmsg.destPort = socket.dest.port;
        TCPmsg.seq = 0;
        TCPmsg.ACK = 0;
        TCPmsg.flag = FIN_FLAG;

        if (sizeof(TCPmsg) <= PACKET_MAX_PAYLOAD_SIZE) {
            // dbg(TRANSPORT_CHANNEL, "copying\n");
            memcpy(msg.payload, &TCPmsg, sizeof(TCPmsg));
        } else {
            return FAIL;
        }

        dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> FIN_WAIT_1\n");
        call List.replace(fd, socket);

        call SimpleSend.send(msg, call Routing.nextHop(msg.dest));

        enqueueRetransmit(fd, msg);
        
        return SUCCESS;
    }

    event void closeTimer.fired() {
        socket_store_t socket;
        int i;
        
        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);
            if (socket.state == CLOSE_WAIT) {
                dbg(TRANSPORT_CHANNEL, "STATE: CLOSE_WAIT -> CLOSED\n");
                socket.state = CLOSED;
                call List.replace(i, socket);

                dbg(TRANSPORT_CHANNEL, "Stream closed from [%d]:%d <-> [%d]:%d on <%d>\n", TOS_NODE_ID, socket.src, socket.dest.addr, socket.dest.port, i);
                dbg(APPLICATION_CHANNEL, "Stream closed from [%d]:%d <-> [%d]:%d on <%d>\n", TOS_NODE_ID, socket.src, socket.dest.addr, socket.dest.port, i);
            }
        }
    }

    command void Transport.setTestServer(uint8_t port) {
        socket_t fd;
        socket_addr_t srcAddr;
        socket_store_t socket;

        fd = call Transport.socket();

        srcAddr.port = port;
        srcAddr.addr = TOS_NODE_ID;

        call Transport.bind(fd, &srcAddr);

        call Transport.listen(fd);

        dbg(TRANSPORT_CHANNEL, "Server [%d] listening on Socket %d, Port %d\n", TOS_NODE_ID, fd, port);
        // socket = call List.get(fd);
        // dbg(TRANSPORT_CHANNEL, "Socket.src = %d\n", socket.src);
        // dbg(TRANSPORT_CHANNEL, "Socket.state = %d\n", socket.state);

        call serverTimer.startPeriodic(READ_TIME);        
    }

    event void serverTimer.fired() {
        socket_store_t socket;
        int i;
        int j;
        uint8_t bytesAvailable;
        uint8_t data[SOCKET_BUFFER_SIZE];

        // dbg(TRANSPORT_CHANNEL, "Server timer\n");
        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);
            if (socket.state == ESTABLISHED || socket.state == CLOSE_WAIT) {
                // if (socket.lastRcvd == socket.lastRead) {
                //     if (socket.effectiveWindow == 0) {
                //         bytesAvailable = SOCKET_BUFFER_SIZE;
                //     } else {
                //         bytesAvailable = 0;
                //     }
                // } else {
                //     bytesAvailable = (socket.lastRcvd - socket.lastRead + SOCKET_BUFFER_SIZE) % SOCKET_BUFFER_SIZE;
                // }
                // dbg(TRANSPORT_CHANNEL, "Effective Window: %d\n", socket.effectiveWindow);
                bytesAvailable = SOCKET_BUFFER_SIZE - socket.effectiveWindow;

                if (bytesAvailable == 0) {
                    // dbg(TRANSPORT_CHANNEL, "No data available to read!\n");
                    continue;
                }

                dbg(TRANSPORT_CHANNEL, "READING from socket %d -----------------------\n", i);

                for (j = 0; j < bytesAvailable; j++) {
                    data[j] = socket.rcvdBuff[(socket.lastRead + j) % SOCKET_BUFFER_SIZE];
                }

                dbg(TRANSPORT_CHANNEL, "lastRead %d -> %d\n", socket.lastRead, (socket.lastRead + bytesAvailable) % SOCKET_BUFFER_SIZE);
                socket.lastRead = (socket.lastRead + bytesAvailable) % SOCKET_BUFFER_SIZE;
                socket.effectiveWindow += bytesAvailable;

                totalRead[i-1] += bytesAvailable;
                dbg(TRANSPORT_CHANNEL, "SERVER [%d] read %d bits from SOCKET <%d> (total: %d)\n", TOS_NODE_ID, bytesAvailable, i, totalRead[i-1]);
                dbg(APPLICATION_CHANNEL, "SERVER [%d] read %d bits from SOCKET <%d> (total: %d)\n", TOS_NODE_ID, bytesAvailable, i, totalRead[i-1]);

                call List.replace(i, socket);
            }
        }
    }

    command void Transport.setTestClient(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint16_t transfer) {
        socket_t fd;
        socket_addr_t srcAddr;
        socket_addr_t destAddr;
        socket_store_t socket;
        int i;

        fd = call Transport.socket();

        dbg(TRANSPORT_CHANNEL, "Client [%d] on Socket %d, Port %d. Attempting to reach Server [%d] at Port %d\n", TOS_NODE_ID, fd, srcPort, dest, destPort);

        srcAddr.port = srcPort;
        srcAddr.addr = TOS_NODE_ID;
        call Transport.bind(fd, &srcAddr);

        destAddr.port = destPort;
        destAddr.addr = dest;
        call Transport.connect(fd, &destAddr);

        transferData[fd-1] = transfer * 8;
        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            if (transferData[i-1]) {
                dbg(TRANSPORT_CHANNEL, "Socket: %d, Data: %d\n", i, transferData[i-1]);
            }
        }
        // call clientTimer.startPeriodic(RETRANSMIT_TIME);
    }

    event void clientTimer.fired() {
        retransmit_pack_t retransmitEntry;
        tcp_pack *tcpMessage;
        socket_store_t socket;
        uint8_t i;

        // dbg(TRANSPORT_CHANNEL, "Checking for retransmissions...\n");

        for (i = 1; i <= call packQueue.size(); i++) {
            retransmitEntry = call packQueue.get(i);
            socket = call List.get(retransmitEntry.socket);
            tcpMessage = (tcp_pack *)retransmitEntry.retransmitPacket.payload;
            
            // Special case for SYN_ACK + ACK
            if (tcpMessage->flag == SYN_ACK_FLAG || tcpMessage->flag == ACK_FLAG || tcpMessage->flag == FIN_FLAG || tcpMessage->flag == FIN_ACK_FLAG) {
                // dbg(TRANSPORT_CHANNEL, "Retransmitting special packet on socket %d. Seq: %d, Flag: %d, Retries: %d\n",
                //     retransmitEntry.socket, retransmitEntry.retransmitPacket.seq, tcpMessage->flag, retransmitEntry.retries);

                call SimpleSend.send(retransmitEntry.retransmitPacket, call Routing.nextHop(retransmitEntry.retransmitPacket.dest));

                call packQueue.remove(i);

                continue;
            }
           
            // Check if retries exceeded
            if (retransmitEntry.retries >= MAX_RETRIES) {
                dbg(TRANSPORT_CHANNEL, "Max retries exceeded for socket %d. Closing connection.\n", retransmitEntry.socket);
                socket.state = CLOSED;
                call List.replace(retransmitEntry.socket, socket);
                call packQueue.remove(i);
                i--;
                continue;
            }

            // Retransmit the packet
            dbg(TRANSPORT_CHANNEL, "RETRANSMITTING packet on socket %d. Seq:%d. Retry count: %d\n", retransmitEntry.socket, retransmitEntry.retransmitPacket.seq, retransmitEntry.retries + 1);
            call SimpleSend.send(retransmitEntry.retransmitPacket, call Routing.nextHop(retransmitEntry.retransmitPacket.dest));
            retransmitEntry.retries++;
            call packQueue.replace(i, retransmitEntry);
        }
    }

    command void Transport.closeTestClient(uint8_t srcPort, uint16_t dest, uint8_t destPort) {
        int i;
        socket_store_t socket;

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);
            if (socket.src == srcPort && socket.dest.addr == dest && socket.dest.port == destPort) {
                dbg(TRANSPORT_CHANNEL, "Found Socket [%d]:%d -> [%d]:%d. Closing stream...\n", TOS_NODE_ID, socket.src, socket.dest.addr, socket.dest.port);
                call Transport.close(i);
            }
        }
    }

    event void connectDone.fired() {
        socket_store_t socket;
        pack msg;
        tcp_pack TCPmsg;
        int i = 0;
        uint8_t j = 0;
        uint8_t bytesToSend = 0;

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);
            if ((socket.state == ESTABLISHED || socket.state == FIN_WAIT_1) && transferData[i-1] > 0) {
                dbg(TRANSPORT_CHANNEL, "SENDING ON SOCKET %d\n", i);
                for (j = 1; j <= MAX_NUM_OF_SOCKETS; j++) {
                    if (transferData[j-1]) {
                        // dbg(TRANSPORT_CHANNEL, "Socket: %d, Data: %d\n", j, transferData[j-1]);
                    }
                }

                if (socket.effectiveWindow < (SOCKET_BUFFER_SIZE / 4)) {
                    skipFrequency[i] = 4;
                } else if (socket.effectiveWindow < (SOCKET_BUFFER_SIZE / 2)) {
                    skipFrequency[i] = 2;
                } else {
                    skipFrequency[i] = 1;
                }

                if (skips[i] % skipFrequency[i] != 0) {
                    dbg(TRANSPORT_CHANNEL, "Skipping packet for socket %d due to small Window (<%d)\n", i, SOCKET_BUFFER_SIZE / skipFrequency[i]);
                    // dbg(APPLICATION_CHANNEL, "Skipping packet for socket %d due to small Window (<%d)\n", i, SOCKET_BUFFER_SIZE / skipFrequency[i]);
                    skips[i]++;
                    continue;
                }

                msg.dest = socket.dest.addr;
                msg.src = TOS_NODE_ID;
                msg.seq = 0;
                msg.TTL = MAX_TTL;
                msg.protocol = PROTOCOL_TCP;

                TCPmsg.srcPort = socket.src;
                TCPmsg.destPort = socket.dest.port;
                TCPmsg.flag = DATA_FLAG;
                TCPmsg.seq = socket.lastSent;
                TCPmsg.ACK = socket.nextExpected;

                if (transferData[i-1] <= TCP_PACKET_MAX_PAYLOAD_SIZE) {
                    if (transferData[i-1] <= socket.effectiveWindow) {
                        bytesToSend = transferData[i-1];
                    } else {
                        bytesToSend = socket.effectiveWindow;
                    }
                } else {
                    if (TCP_PACKET_MAX_PAYLOAD_SIZE <= socket.effectiveWindow) {
                        bytesToSend = TCP_PACKET_MAX_PAYLOAD_SIZE;
                    } else {
                        bytesToSend = socket.effectiveWindow;
                    }
                }

                if (bytesToSend == 0) {
                    dbg(TRANSPORT_CHANNEL, "No data can be sent due to window size\n");
                    continue;
                }

                dbg(TRANSPORT_CHANNEL, "Effective window: %d\n", socket.effectiveWindow);
                dbg(TRANSPORT_CHANNEL, "Bits to send: %d\n", bytesToSend);
                dbg(TRANSPORT_CHANNEL, "Sequence: %d\n", TCPmsg.seq);
                for (j = 0; j < bytesToSend; j++) {
                    TCPmsg.payload[j] = j;
                }
                TCPmsg.length = bytesToSend;

                memcpy(msg.payload, &TCPmsg, sizeof(TCPmsg));
                call SimpleSend.send(msg, call Routing.nextHop(msg.dest));

                msg.seq = socket.lastSent;

                dbg(TRANSPORT_CHANNEL, "lastSent: %d -> %d\n", socket.lastSent, (uint8_t)(socket.lastSent + bytesToSend));
                socket.lastSent += bytesToSend;
                socket.effectiveWindow -= bytesToSend;
                transferData[i-1] -= bytesToSend;

                call List.replace(i, socket);

                skips[i]++;
                
                enqueueRetransmit(i, msg);
            }
            else if (socket.state == ESTABLISHED && transferData[i-1] == 0) {
                call Transport.close(i);
            }
            else if (socket.state == FIN_WAIT_1 && socket.lastSent == socket.lastAck) {
                dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_1 -> FIN_WAIT_2\n");
                socket.state = FIN_WAIT_2;
                call List.replace(i, socket);
            }
        }

        call clientTimer.startOneShot(RETRANSMIT_TIME);
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack* receivedMessage = (pack*)payload;
        tcp_pack* tcpMessage = (tcp_pack*)receivedMessage->payload;
        int i;
        int j;
        socket_store_t socket;
        uint16_t temp;
        uint8_t bytesReceived;
        pack ackMsg;
        tcp_pack ackTCPMsg;

        if (receivedMessage->dest != TOS_NODE_ID) { 
            if (receivedMessage->TTL == 0) {
                dbg(TRANSPORT_CHANNEL, "[%d] dropped 0 TTL packet!\n", TOS_NODE_ID);
                return msg;
            }

            receivedMessage->TTL--;
            // dbg(TRANSPORT_CHANNEL, "[%d] -> [%d]\n", TOS_NODE_ID, call Routing.nextHop(receivedMessage->dest));
            call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
            
            return msg;
        }

        // dbg(TRANSPORT_CHANNEL, "I am [%d]. Packet received from [%d]\n", TOS_NODE_ID, receivedMessage->src);

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);

            // dbg(TRANSPORT_CHANNEL, "destPort = %d, srcPort = %d\n", tcpMessage->destPort, socket.src);
            if (tcpMessage->destPort == socket.src) {
                // dbg(TRANSPORT_CHANNEL, "socket %d: destPort = %d, srcPort = %d\n", i, tcpMessage->destPort, socket.src);
                // dbg(TRANSPORT_CHANNEL, "State: %d\n", socket.state);
                if (socket.state == LISTEN) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is LISTENING\n");
                    if (tcpMessage->flag == SYN_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: SYN_FLAG\n");
                        socket.state = SYN_RCVD;
                        socket.dest.port = tcpMessage->srcPort;
                        socket.dest.addr = receivedMessage->src;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: LISTENING -> SYN_RCVD\n");

                        temp = receivedMessage->dest;
                        receivedMessage->dest = receivedMessage->src;
                        receivedMessage->src = temp;
                        receivedMessage->TTL = MAX_TTL;

                        tcpMessage->flag = SYN_ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;
                        tcpMessage->ACK = tcpMessage->seq+1;
                        tcpMessage->seq = 1;
                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));
                        
                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
                        
                        enqueueRetransmit(i, *receivedMessage);
                        call clientTimer.startOneShot(RETRANSMIT_TIME);
                    }
                }
                else if (socket.state == SYN_SENT) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is SYN_SENT\n");
                    if (tcpMessage->flag == SYN_ACK_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: SYN_ACK_FLAG\n");
                        socket.state = ESTABLISHED;
                        socket.dest.port = tcpMessage->srcPort;
                        socket.dest.addr = receivedMessage->src;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: SYN_SENT -> ESTABLISHED\n");
                        
                        temp = receivedMessage->dest;
                        receivedMessage->dest = receivedMessage->src;
                        receivedMessage->src = temp;
                        receivedMessage->TTL = MAX_TTL;

                        tcpMessage->flag = ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;
                        temp = tcpMessage->ACK;
                        tcpMessage->ACK = tcpMessage->seq+1;
                        tcpMessage->seq = temp;
                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));

                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
                        enqueueRetransmit(i, *receivedMessage);

                        call connectDone.startPeriodic(CONNECT_DONE_TIME);
                        call clientTimer.startOneShot(RETRANSMIT_TIME);
                    }
                }
                else if (socket.state == SYN_RCVD) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is SYN_RCVD\n");
                    if (tcpMessage->flag == ACK_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: ACK_FLAG\n");
                        socket.state = ESTABLISHED;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: SYN_RCVD -> ESTABLISHED\n");

                        dbg(APPLICATION_CHANNEL, "Three-way handshake complete from [%d]:%d <-> [%d]:%d on <%d>\n", TOS_NODE_ID, socket.src, socket.dest.addr, socket.dest.port, i);
                        dbg(TRANSPORT_CHANNEL, "Three-way handshake complete from [%d]:%d <-> [%d]:%d on <%d>\n", TOS_NODE_ID, socket.src, socket.dest.addr, socket.dest.port, i);
                    }
                }
                else if (socket.state == ESTABLISHED || socket.state == CLOSE_WAIT) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is ESTABLISHED\n");
                    if (tcpMessage->flag == DATA_FLAG) {
                        // dbg(TRANSPORT_CHANNEL, "FLAG: DATA_FLAG\n");
                        dbg(TRANSPORT_CHANNEL, "recevied packet from [%d] with Seq: %d\n", receivedMessage->src, tcpMessage->seq);
                        
                        if (tcpMessage->seq < socket.nextExpected) {
                            dbg(TRANSPORT_CHANNEL, "Old packet. Expected: %d, Received: %d\n", socket.nextExpected, tcpMessage->seq);
                            return msg;
                        }
                        if (tcpMessage->seq != socket.nextExpected) {
                            dbg(TRANSPORT_CHANNEL, "Out-of-order packet. Expected: %d, Received: %d\n", socket.nextExpected, tcpMessage->seq);

                            ackMsg.dest = socket.dest.addr;
                            ackMsg.src = TOS_NODE_ID;
                            ackMsg.seq = 0;
                            ackMsg.TTL = MAX_TTL;
                            ackMsg.protocol = PROTOCOL_TCP;

                            ackTCPMsg.srcPort = socket.src;
                            ackTCPMsg.destPort = socket.dest.port;
                            ackTCPMsg.flag = DATA_ACK_FLAG;
                            ackTCPMsg.seq = 0;
                            ackTCPMsg.ACK = socket.nextExpected;
                            ackTCPMsg.window = SOCKET_BUFFER_SIZE - ((socket.nextExpected % SOCKET_BUFFER_SIZE) - socket.lastRead + SOCKET_BUFFER_SIZE) % SOCKET_BUFFER_SIZE;

                            memcpy(ackMsg.payload, &ackTCPMsg, sizeof(ackTCPMsg));
                            call SimpleSend.send(ackMsg, call Routing.nextHop(ackMsg.dest));

                            return msg;
                        }

                        bytesReceived = tcpMessage->length;
                        dbg(TRANSPORT_CHANNEL, "Bits received: %d\n", bytesReceived);
                        for (j = 0; j < bytesReceived; j++) {
                            socket.rcvdBuff[(socket.lastRcvd + j) % SOCKET_BUFFER_SIZE] = tcpMessage->payload[j];
                        }

                        dbg(TRANSPORT_CHANNEL, "lastRcvd %d -> %d\n", socket.lastRcvd, (socket.lastRcvd + bytesReceived) % SOCKET_BUFFER_SIZE);
                        dbg(TRANSPORT_CHANNEL, "nextExpected %d -> %d\n", socket.nextExpected, (uint8_t)(tcpMessage->seq + bytesReceived));
                        socket.lastRcvd = (socket.lastRcvd + bytesReceived) % SOCKET_BUFFER_SIZE;
                        socket.nextExpected = tcpMessage->seq + bytesReceived;

                        ackMsg.dest = receivedMessage->src;
                        ackMsg.src = TOS_NODE_ID;
                        ackMsg.seq = 0;
                        ackMsg.TTL = MAX_TTL;
                        ackMsg.protocol = PROTOCOL_TCP;

                        ackTCPMsg.srcPort = socket.src;
                        ackTCPMsg.destPort = socket.dest.port;
                        ackTCPMsg.flag = DATA_ACK_FLAG;
                        ackTCPMsg.seq = 0;
                        ackTCPMsg.ACK = socket.nextExpected;
                        if (socket.lastRcvd >= socket.lastRead) {
                            if ((socket.nextExpected % SOCKET_BUFFER_SIZE) == socket.lastRead) {
                                ackTCPMsg.window = 0;
                            } else {
                                ackTCPMsg.window = SOCKET_BUFFER_SIZE - (socket.lastRcvd - socket.lastRead);
                            }
                        } else {
                            ackTCPMsg.window = SOCKET_BUFFER_SIZE - (SOCKET_BUFFER_SIZE - socket.lastRead + socket.lastRcvd);
                        }

                        socket.effectiveWindow = ackTCPMsg.window;

                        memcpy(ackMsg.payload, &ackTCPMsg, sizeof(ackTCPMsg));
                        call SimpleSend.send(ackMsg, call Routing.nextHop(ackMsg.dest));

                        call List.replace(i, socket);

                        dbg(TRANSPORT_CHANNEL, "lastRead: %d\n", socket.lastRead);
                        dbg(TRANSPORT_CHANNEL, "Window: %d\n", ackTCPMsg.window);
                        dbg(TRANSPORT_CHANNEL, "Acknowledged data up to %d\n", ackTCPMsg.ACK);
                    }
                    
                    else if (tcpMessage->flag == DATA_ACK_FLAG) {
                        // dbg(TRANSPORT_CHANNEL, "FLAG: DATA_ACK_FLAG\n");
                        dbg(TRANSPORT_CHANNEL, "recevied Ack from [%d] for %d\n", receivedMessage->src, tcpMessage->ACK);

                        if (seqNumLessThanOrEqual(tcpMessage->ACK, socket.lastAck) || seqNumGreaterThan(tcpMessage->ACK, socket.lastSent)) {
                            dbg(TRANSPORT_CHANNEL, "Invalid Ack. last Ack: %d, new ACK: %d, last Sent: %d\n", socket.lastAck, tcpMessage->ACK, socket.lastSent);
                            return msg;
                        }

                        bytesReceived = tcpMessage->ACK - socket.lastAck;
                        dbg(TRANSPORT_CHANNEL, "Bits acked: %d\n", bytesReceived);

                        socket.lastAck = tcpMessage->ACK;

                        dbg(TRANSPORT_CHANNEL, "Received window: %d, LastSent: %d, LastAck: %d\n", tcpMessage->window, socket.lastSent, socket.lastAck);
                        dbg(TRANSPORT_CHANNEL, "Calculating effective window: %d - (%d - %d)\n", tcpMessage->window, socket.lastSent, socket.lastAck);
                        socket.effectiveWindow = tcpMessage->window - ((uint8_t)(socket.lastSent - socket.lastAck));
                        dbg(TRANSPORT_CHANNEL, "New window: %d\n", socket.effectiveWindow);
                        
                        call List.replace(i, socket);

                        removeAcknowledgedPackets(i, tcpMessage->ACK);
                    }

                    else if (tcpMessage->flag == FIN_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: FIN_FLAG\n");
                        socket.state = CLOSE_WAIT;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> CLOSE_WAIT\n");

                        temp = receivedMessage->dest;
                        receivedMessage->dest = receivedMessage->src;
                        receivedMessage->src = temp;

                        tcpMessage->flag = FIN_ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;

                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));

                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
                        enqueueRetransmit(i, *receivedMessage);
                        
                        call closeTimer.startOneShot(READ_TIME*2);
                    }
                }
                else if (socket.state == FIN_WAIT_2) {
                    if (tcpMessage->flag == FIN_ACK_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: FIN_ACK_FLAG\n");
                        socket.state = CLOSE_WAIT;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_2 -> CLOSE_WAIT\n");

                        call closeTimer.startOneShot(READ_TIME*2);
                    }

                } 
            }
        }

        return msg;
    }
}