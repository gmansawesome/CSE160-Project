#include "../../includes/packet.h"

interface Routing {
    command void floodLSP();
    command void addNeighbors(uint8_t src, uint8_t* receivedPayload);
    command void outputAllNeighbors();
    command uint8_t forwarding(uint8_t dest);
}