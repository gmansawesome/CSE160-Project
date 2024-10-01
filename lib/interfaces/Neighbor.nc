#include "../../includes/packet.h"

interface Neighbor {
    command void start();
    command uint8_t getNeighborCount();
    command uint16_t getNeighbor(uint8_t neighborIndex);  // Rename index to neighborIndex
    command void pass();
    command void addOrUpdateNeighbor(uint16_t neighbor);
}