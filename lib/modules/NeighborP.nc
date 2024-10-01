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
        error_t result;
        uint8_t listSize;
        uint8_t i;
        NeighborTable checkNeighbor;

        // logPack(&msg, NEIGHBOR_CHANNEL);

        listSize = MAX_NODES;
        dbg(NEIGHBOR_CHANNEL, "Instantiating...\n");
        for (i = 0; i < listSize; i++) {
            NeighborTable deadNeighbor;

            deadNeighbor.lastSeen = 0;
            deadNeighbor.linkQuality = 0;
            deadNeighbor.isActive = FALSE;

            call List.pushback(deadNeighbor);
        }

        checkNeighbor = call List.get(0);
        dbg(NEIGHBOR_CHANNEL, "Neighbor Check | Last Seen: %d, Average: %d, Active: %s\n",
            checkNeighbor.lastSeen, checkNeighbor.linkQuality, checkNeighbor.isActive ? "True" : "False");

        msg.seq++;
        // logPack(&msg, NEIGHBOR_CHANNEL);

        // Send the neighbor discovery message using SimpleSend
        result = call SimpleSend.send(msg, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "ND message sent successfully from %d\n", TOS_NODE_ID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Failed to send ND message from %d\n", TOS_NODE_ID);
        }

        return result;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        NeighborTable tempNeighbor;

        pack* receivedMessage = (pack*)payload;

        // logPack(receivedMessage, NEIGHBOR_CHANNEL);

        if (receivedMessage->protocol == PROTOCOL_NEIGHBORREPLY) {
            dbg(NEIGHBOR_CHANNEL, "Response received from %d\n", receivedMessage->src);
            
            logPack(receivedMessage, NEIGHBOR_CHANNEL);

            tempNeighbor = call List.get(receivedMessage->src);

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d check | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");

            tempNeighbor.isActive = TRUE;

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d check | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");
        
            call List.insert(receivedMessage->src, tempNeighbor);

            return msg;
        }

        dbg(NEIGHBOR_CHANNEL, "Request received from %d\n", receivedMessage->src);

        receivedMessage->dest = receivedMessage->src;
        receivedMessage->src = TOS_NODE_ID;
        receivedMessage->protocol = PROTOCOL_NEIGHBORREPLY;
        // logPack(receivedMessage, NEIGHBOR_CHANNEL);

        call SimpleSend.send(*receivedMessage, receivedMessage->dest);

        return msg;
    }
}