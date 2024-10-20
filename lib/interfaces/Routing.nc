#include "../../includes/packet.h"

interface Routing {
    command void addNeighbors(uint16_t src, uint8_t* receivedPayload);
    command void outputAllNeighbors();
}