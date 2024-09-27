#include "../../includes/packet.h"

configuration NeighborC {
    provides interface Neighbor;
}

implementation {
    components NeighborP;
    components new TimerMilliC() as BeaconTimer;
    components new AMSenderC(AM_NEIGHBOR_BEACON);  // For sending beacons
    components new AMReceiverC(AM_NEIGHBOR_BEACON) as BeaconReceiver;  // For receiving beacons

    Neighbor = NeighborP.Neighbor;

    NeighborP.beaconTimer -> BeaconTimer;
    NeighborP.AMSend -> AMSenderC;
    NeighborP.Receive -> BeaconReceiver.Receive;  // Wire the Receive interface here
    NeighborP.Packet -> AMSenderC;
}