#include "../../includes/packet.h"

interface Routing {
    command void floodLSP();
    command void addNeighbors(uint8_t src, uint8_t* receivedPayload);
    command void outputAllNeighbors();
    command void forwarding(pack message);
    command uint8_t nextHop(uint8_t target);
}