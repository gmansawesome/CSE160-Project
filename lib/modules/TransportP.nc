#include "../../includes/packet.h"
#include "../../includes/tcp_packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"

module TransportP{
    provides interface Transport;
    uses interface Packet;
    uses interface Receive;
    uses interface SimpleSend;
    uses interface Timer<TMilli>;
    uses interface Boot;
    uses interface Routing;
    uses interface List<socket_store_t>;
}

implementation {

    event void Boot.booted() {
        int i;
        int j;
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
        emptySocket.lastAck = 0;
        emptySocket.lastSent = 0;

        for (j = 0; j < SOCKET_BUFFER_SIZE; j++) {
            emptySocket.rcvdBuff[j] = 0;
        }
        emptySocket.lastRead = 0;
        emptySocket.lastRcvd = 0;
        emptySocket.nextExpected = 0;

        emptySocket.RTT = 0;
        emptySocket.effectiveWindow = 0;

        // dbg(TRANSPORT_CHANNEL, "Initializing Sockets\n");
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            // dbg(TRANSPORT_CHANNEL, "Initialized Socket %d\n", i);
            call List.pushback(emptySocket);
        }
    }


   /**
    * Get a socket if there is one available.
    * @Side Client/Server
    * @return
    *    socket_t - return a socket file descriptor which is a number
    *    associated with a socket. If you are unable to allocated
    *    a socket then return a NULL socket_t.
    */
    command socket_t Transport.socket() {
        int i;
        socket_t fd;
        socket_store_t currSocket;

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            currSocket = call List.get(i);
            if (currSocket.state == CLOSED) {
                fd = i;
                // dbg(TRANSPORT_CHANNEL, "Found Socket %d\n", fd);
                return fd;
            }
        }

        fd = NULL;
        return fd;
    }


   /**
    * Bind a socket with an address.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       you are binding.
    * @param
    *    socket_addr_t *addr: the source port and source address that
    *       you are biding to the socket, fd.
    * @Side Client/Server
    * @return error_t - SUCCESS if you were able to bind this socket, FAIL
    *       if you were unable to bind.
    */
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


   /**
    * Listen to the socket and wait for a connection.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    * @side Server
    * @return error_t - returns SUCCESS if you are able change the state 
    *   to listen else FAIL.
    */
    command error_t Transport.listen(socket_t fd) {
        socket_store_t socket;

        socket = call List.get(fd);

        socket.state = LISTEN;

        call List.replace(fd, socket);

        return SUCCESS;
    }


    /**
    * Attempts a connection to an address.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that you are attempting a connection with. 
    * @param
    *    socket_addr_t *addr: the destination address and port where
    *       you will atempt a connection.
    * @side Client
    * @return socket_t - returns SUCCESS if you are able to attempt
    *    a connection with the fd passed, else return FAIL.
    */
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
        msg.TTL = 10;
        msg.protocol = PROTOCOL_TCP;

        TCPmsg.srcPort = socket.src;
        TCPmsg.destPort = addr->port;
        TCPmsg.seq = 0;
        TCPmsg.ACK = 0;
        TCPmsg.lastACK = 0;
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

    event void Timer.fired() {
        dbg(TRANSPORT_CHANNEL, "FIRED");
    }

    command error_t Transport.close(socket_t fd) {
        pack msg;
        tcp_pack TCPmsg;
        socket_store_t socket;
        uint8_t nextHop;

        socket = call List.get(fd);

        msg.dest = socket.dest.addr;
        msg.src = TOS_NODE_ID;
        msg.seq = 0;
        msg.TTL = 10;
        msg.protocol = PROTOCOL_TCP;

        TCPmsg.srcPort = socket.src;
        TCPmsg.destPort = socket.dest.port;
        TCPmsg.seq = 0;
        TCPmsg.ACK = 0;
        TCPmsg.lastACK = 0;
        TCPmsg.flag = FIN_FLAG;
        TCPmsg.window = 0;

        if (sizeof(TCPmsg) <= PACKET_MAX_PAYLOAD_SIZE) {
            // dbg(TRANSPORT_CHANNEL, "copying\n");
            memcpy(msg.payload, &TCPmsg, sizeof(TCPmsg));
        } else {
            return FAIL;
        }

        call SimpleSend.send(msg, call Routing.nextHop(msg.dest));
        
        return SUCCESS;
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
    }


    command void Transport.setTestClient(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t transfer) {
        socket_t fd;
        socket_addr_t srcAddr;
        socket_addr_t destAddr;
        socket_store_t socket;

        fd = call Transport.socket();

        dbg(TRANSPORT_CHANNEL, "Client [%d] on Socket %d, Port %d. Attempting to reach Server [%d] at Port %d\n", TOS_NODE_ID, fd, srcPort, dest, destPort);

        srcAddr.port = srcPort;
        srcAddr.addr = TOS_NODE_ID;
        call Transport.bind(fd, &srcAddr);

        destAddr.port = destPort;
        destAddr.addr = dest;
        call Transport.connect(fd, &destAddr);
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


    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack* receivedMessage = (pack*)payload;
        tcp_pack* tcpMessage = (tcp_pack*)receivedMessage->payload;
        int i;
        socket_store_t socket;
        uint16_t temp;

        if (receivedMessage->dest != TOS_NODE_ID) {
            // dbg(TRANSPORT_CHANNEL, "[%d] -> [%d]\n", TOS_NODE_ID, call Routing.nextHop(receivedMessage->dest));
            call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
            
            return msg;
        }

        dbg(TRANSPORT_CHANNEL, "I am [%d]. Packet received from [%d]\n", TOS_NODE_ID, receivedMessage->src);

        for (i = 1; i <= MAX_NUM_OF_SOCKETS; i++) {
            socket = call List.get(i);

            // dbg(TRANSPORT_CHANNEL, "destPort = %d, srcPort = %d\n", tcpMessage->destPort, socket.src);
            if (tcpMessage->destPort == socket.src) {
                // dbg(TRANSPORT_CHANNEL, "destPort = %d, srcPort = %d\n", tcpMessage->destPort, socket.src);
                // dbg(TRANSPORT_CHANNEL, "State: %d\n", socket.state);
                if (socket.state == LISTEN) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is LISTENING\n");
                    if (tcpMessage->flag == SYN_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: SYN_FLAG\n");
                        socket.state = SYN_RCVD;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: LISTENING -> SYN_RCVD\n");

                        temp = receivedMessage->dest;
                        receivedMessage->dest = receivedMessage->src;
                        receivedMessage->src = temp;

                        tcpMessage->flag = SYN_ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;
                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));
                        
                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
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

                        tcpMessage->flag = ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;
                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));
                        
                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
                    }
                }
                else if (socket.state == SYN_RCVD) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is SYN_RCVD\n");
                    if (tcpMessage->flag == ACK_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: ACK_FLAG\n");
                        socket.state = ESTABLISHED;
                        socket.dest.port = tcpMessage->srcPort;
                        socket.dest.addr = receivedMessage->src;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: SYN_RCVD -> ESTABLISHED\n");
                        dbg(TRANSPORT_CHANNEL, "Three-way handshake complete between Nodes [%d] <-> [%d]\n", receivedMessage->src, TOS_NODE_ID);
                    }
                }
                else if (socket.state == ESTABLISHED) {
                    // dbg(TRANSPORT_CHANNEL, "My current state is ESTABLISHED\n");
                    if (tcpMessage->flag == FIN_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: FIN_FLAG\n");
                        socket.state = CLOSED;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> CLOSED\n");

                        temp = receivedMessage->dest;
                        receivedMessage->dest = receivedMessage->src;
                        receivedMessage->src = temp;

                        tcpMessage->flag = FIN_ACK_FLAG;
                        tcpMessage->destPort = tcpMessage->srcPort;
                        tcpMessage->srcPort = socket.src;

                        memcpy(receivedMessage->payload, tcpMessage, sizeof(tcpMessage));
                        
                        call SimpleSend.send(*receivedMessage, call Routing.nextHop(receivedMessage->dest));
                    }

                    else if (tcpMessage->flag == FIN_ACK_FLAG) {
                        dbg(TRANSPORT_CHANNEL, "FLAG: FIN_ACK_FLAG\n");
                        socket.state = CLOSED;
                        call List.replace(i, socket);
                        dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> CLOSED\n");
                        dbg(TRANSPORT_CHANNEL, "Stream closed between Nodes [%d] <-> [%d]\n", TOS_NODE_ID, receivedMessage->src);
                    }
                }
            }
        }

        return msg;
    }
}