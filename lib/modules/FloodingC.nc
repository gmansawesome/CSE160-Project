#include "../../includes/am_types.h"
#include "../../includes/channels.h"

configuration FloodingC{
   provides interface Flooding;
}
 
implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components new SimpleSendC(10);
    FloodingP.SimpleSend -> SimpleSendC;
}