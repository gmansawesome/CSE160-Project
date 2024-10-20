#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/floodingTable.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components new SimpleSendC(AM_FLOODING);
    FloodingP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_FLOODING);
    FloodingP.Receive -> AMReceiverC;

    components ActiveMessageC;
    FloodingP.Packet -> ActiveMessageC;

    components new ListC(FloodingTable, MAX_NODES);
    FloodingP.List -> ListC;

    components new TimerMilliC();
    FloodingP.Timer -> TimerMilliC;

    components MainC;
    FloodingP.Boot -> MainC.Boot;

    components RoutingC;
    FloodingP.Routing -> RoutingC;
}