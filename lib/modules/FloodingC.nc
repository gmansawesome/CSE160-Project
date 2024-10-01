#include "../../includes/am_types.h"
#include "../../includes/packet.h"

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

    components new ListC(uint16_t, MAX_NODES);
    FloodingP.List -> ListC;
}