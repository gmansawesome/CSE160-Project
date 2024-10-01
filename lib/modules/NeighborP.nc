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

implementation{
    command void Neighbor.pass(){}

    command error_t Neighbor.discoverNeighbors(pack msg) {
        uint8_t listSize;
        uint8_t i;
        NeighborTable checkNeighbor;

        logPack(&msg, NEIGHBOR_CHANNEL);

        // listSize = MAX_NODES;
        // dbg(FLOODING_CHANNEL, "Instantiating...\n");
        // for (i = 0; i < listSize; i++) {
        //     NeighborTable deadNeighbor;

        //     deadNeighbor.linkQuality = 0;
        //     deadNeighbor.isActive = FALSE;

        //     call List.pushback(deadNeighbor);
        // }

        // checkNeighbor = call List.get(0);
        // dbg(FLOODING_CHANNEL, "Neighbor Check Average: %d\n", checkNeighbor.linkQuality);

        return SUCCESS;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack* receivedMessage = (pack*)payload;

        dbg(FLOODING_CHANNEL, "Packet received from %d\n", receivedMessage->src);
        logPack(receivedMessage, FLOODING_CHANNEL);
    }
}