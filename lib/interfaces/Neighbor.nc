#include "../../includes/packet.h"

interface Neighbor{
   command void outputNeighbors();
   command uint16_t* requestNeighbors();
}