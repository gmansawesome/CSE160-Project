#include "../../includes/am_types.h"
#include "Receive.nc"  // Make sure this is included for the Receive interface

configuration NeighborC {
    provides interface Neighbor;
}

implementation {
    components NeighborP;
    components new TimerMilliC() as BeaconTimer;
    components new AMSenderC(TOS_BCAST_ADDR);  // Use a valid broadcast address

    Neighbor = NeighborP.Neighbor;

    // Wire the interfaces properly
    NeighborP.beaconTimer -> BeaconTimer;
    NeighborP.AMSend -> AMSenderC;
    NeighborP.Packet -> AMSenderC;
    NeighborP.Receive -> AMSenderC.Receive;  // Wire Receive interface
}