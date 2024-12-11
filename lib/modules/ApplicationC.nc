#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"

configuration ApplicationC{
   provides interface Application;
}

implementation{
    components ApplicationP;
    Application = ApplicationP.Application;

    components new TimerMilliC() as readTimer;
    ApplicationP.readTimer -> readTimer;

    components MainC;
    ApplicationP.Boot -> MainC.Boot;

    components TransportC;
    ApplicationP.Transport -> TransportC;

    components new ListC(string_entry_t, MAX_NUM_OF_SOCKETS) as userList;
	ApplicationP.userList -> userList;
}