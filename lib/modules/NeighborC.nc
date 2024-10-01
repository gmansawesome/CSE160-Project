#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/neighborTable.h"

configuration NeighborC{
   provides interface Neighbor;
}

implementation{
    components NeighborP;
    Neighbor = NeighborP.Neighbor;

    components new SimpleSendC(AM_NEIGHBOR);
    NeighborP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_NEIGHBOR);
    NeighborP.Receive -> AMReceiverC;

    components ActiveMessageC;
    NeighborP.Packet -> ActiveMessageC;

    components new ListC(NeighborTable, MAX_NODES);
    NeighborP.List -> ListC;
}