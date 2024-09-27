#include "../../includes/packet.h"

configuration NeighborC {
    provides interface Neighbor;
}

implementation {
    components NeighborP;
    components new TimerMilliC() as BeaconTimer;
    components new AMSenderC(AM_BROADCAST_ADDR);  // Use broadcast to send neighbor beacons

    Neighbor = NeighborP.Neighbor;

    NeighborP.beaconTimer -> BeaconTimer;
    NeighborP.AMSend -> AMSenderC;
    NeighborP.Packet -> AMSenderC;
}