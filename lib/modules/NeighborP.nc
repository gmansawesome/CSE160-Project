#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/neighborTable.h"

module NeighborP{
   provides interface Neighbor;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
   uses interface List<NeighborTable>;
}

}

implementation{
    command void Neighbor.pass(){
        
    }

    command error_t Neighbor.discoverNeighbors(pack msg) {

    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

    }
}