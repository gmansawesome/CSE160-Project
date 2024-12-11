#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/tcp_packet.h"
#include "../../includes/socket.h"

configuration TransportC{
   provides interface Transport;
}

implementation{
    components TransportP;
    Transport = TransportP.Transport;

    components new SimpleSendC(AM_TRANSPORT);
    TransportP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_TRANSPORT);
    TransportP.Receive -> AMReceiverC;

    components ActiveMessageC;
    TransportP.Packet -> ActiveMessageC;

    components new TimerMilliC() as serverTimer;
    TransportP.serverTimer -> serverTimer;

    components new TimerMilliC() as clientTimer;
    TransportP.clientTimer -> clientTimer;

    components new TimerMilliC() as connectDone;
    TransportP.connectDone -> connectDone;

    components new TimerMilliC() as closeTimer;
    TransportP.closeTimer -> closeTimer;

    components MainC;
    TransportP.Boot -> MainC.Boot;

    components RoutingC;
    TransportP.Routing -> RoutingC;

    components new ListC(socket_store_t, MAX_NUM_OF_SOCKETS);
    TransportP.List -> ListC;

    components new ListC(retransmit_pack_t, 50) as packQueue;
	TransportP.packQueue -> packQueue;

    components ApplicationC;
    TransportP.Application -> ApplicationC;
}