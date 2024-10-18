#include "../../includes/packet.h"
#include "../../includes/neighborInfo.h"

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

    components new ListC(NeighborInfo, MAX_NODES*MAX_NODES);
    RoutingP.List -> ListC;
}