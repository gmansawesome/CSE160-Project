#include "../../includes/packet.h"

interface Neighbor{
   command void pass();
   command error_t Neighbor.discoverNeighbors(pack msg);
}