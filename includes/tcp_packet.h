#ifndef TCP_PACKET_H
#define TCP_PACKET_H

#include "protocol.h"
#include "channels.h"

#define DATA_FLAG 0
#define DATA_ACK_FLAG 1
#define SYN_FLAG 2
#define SYN_ACK_FLAG 3
#define ACK_FLAG 4
#define FIN_FLAG 5
#define FIN_ACK_FLAG 6

enum{
	TCP_PACKET_HEADER_LENGTH = 8,
	TCP_PACKET_MAX_PAYLOAD_SIZE = 12
};

typedef nx_struct tcp_pack{
    nx_uint8_t srcPort;
	nx_uint8_t destPort;
	nx_uint8_t seq;
	nx_uint8_t ACK;
	nx_uint8_t lastACK;
	nx_uint8_t flag;
	nx_uint8_t window;
	nx_uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];
}tcp_pack;

#endif