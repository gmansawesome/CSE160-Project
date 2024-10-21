#include "../../includes/packet.h"

interface Neighbor{
   command void outputNeighbors();
   command uint8_t* requestNeighbors();
}