#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;

   uses interface SimpleSend;
}
 
implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components SimpleSendC(AM_FLOODING);
    FloodingP.SimpleSend -> SimpleSendC;
}