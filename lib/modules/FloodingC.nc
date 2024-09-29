#include "../../includes/am_types.h"
#include "../../includes/packet.h"

configuration FloodingC{
   provides interface Flooding;
}
 
implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components new AMReceiverC(AM_PACK);
    FloodingP.Receive -> AMReceiverC;

    components new SimpleSendC(AM_PACK);
    FloodingP.SimpleSend -> SimpleSendC;

    components ActiveMessageC;
    FloodingP.Packet -> ActiveMessageC;
}