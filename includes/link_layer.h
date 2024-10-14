#ifndef __LINK_LAYER_H__
#define __LINK_LAYER_H__

# include "protocol.h"
# include "channels.h"

enum{
	LINK_HEADER_LENGTH = 4,
	LINK_MAX_PAYLOAD_SIZE = 32 - LINK_HEADER_LENGTH,
};

typedef nx_struct link{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint8_t payload[LINK_MAX_PAYLOAD_SIZE];
}link;

#endif