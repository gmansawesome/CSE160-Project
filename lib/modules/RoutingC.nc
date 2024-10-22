#include "../../includes/am_types.h"
#include "../../includes/packet.h"

configuration RoutingC{
   provides interface Routing;
}

implementation{
    components RoutingP;
    Routing = RoutingP.Routing;

    components new SimpleSendC(AM_ROUTING);
    RoutingP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    RoutingP.Receive -> AMReceiverC;

    components ActiveMessageC;
    RoutingP.Packet -> ActiveMessageC;

    components new TimerMilliC();
    RoutingP.Timer -> TimerMilliC;

    components MainC;
    RoutingP.Boot -> MainC.Boot;

    components NeighborC;
    RoutingP.Neighbor -> NeighborC;

    components FloodingC;
    RoutingP.Flooding -> FloodingC;
}