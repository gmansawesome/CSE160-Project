#include "../../includes/packet.h"

configuration NeighborC {
    provides interface Neighbor;
}

implementation {
    components NeighborP;
    components new TimerMilliC() as BeaconTimer;
    components new SimpleSendC(AM_PACK);  // Using SimpleSend for sending beacons
    components RandomC;  // Add RandomC to provide random number generation

    Neighbor = NeighborP.Neighbor;

    NeighborP.beaconTimer -> BeaconTimer;
    NeighborP.SimpleSend -> SimpleSendC;
    NeighborP.Random -> RandomC;
}