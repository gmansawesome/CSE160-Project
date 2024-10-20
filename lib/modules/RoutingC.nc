#include "../../includes/packet.h"

configuration RoutingC{
   provides interface Routing;
}

implementation{
    components RoutingP;
    Routing = RoutingP.Routing;

    components new TimerMilliC();
    RoutingP.Timer -> TimerMilliC;

    components MainC;
    RoutingP.Boot -> MainC.Boot;

    components NeighborC;
    RoutingP.Neighbor -> NeighborC;

    components FloodingC;
    RoutingP.Flooding -> FloodingC;
}