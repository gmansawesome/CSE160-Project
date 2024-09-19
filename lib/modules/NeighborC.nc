#include "../../includes/am_types.h"

configuration NeighborC{
   provides interface Neighbor;
}
 
implementation{
    components NeighborP;
    Neighbor = NeighborP.Neighbor;
}