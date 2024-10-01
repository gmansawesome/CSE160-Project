#include "../../includes/packet.h"

interface Neighbor{
   command error_t discoverNeighbors(pack msg);
   command void outputNeighbors();
}