#include "../../includes/packet.h"

interface Neighbor{
   command void pass();
   command error_t discoverNeighbors(pack msg);
}