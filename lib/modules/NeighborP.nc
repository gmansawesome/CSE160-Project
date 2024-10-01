#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/neighborTable.h"

#define ND_TIME_INTERVAL 40000 //40s
#define QUALITY_THRESHOLD 40

module NeighborP{
   provides interface Neighbor;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
   uses interface List<NeighborTable>;
   uses interface Timer<TMilli>;
   uses interface Boot;
}

implementation{
    bool instList = FALSE;
    uint8_t currSeq = 0;

    event void Boot.booted() {
        // dbg(NEIGHBOR_CHANNEL, "BOOTED\n");
        call Timer.startPeriodic(ND_TIME_INTERVAL);
    }

    event void Timer.fired() {
        pack msg;
        const char *payloadStr = "Are you my friend?";

        msg.src = TOS_NODE_ID;
        msg.dest = 0;
        msg.TTL = 0;
        msg.seq = 0;
        msg.protocol = PROTOCOL_NEIGHBOR;

        memcpy(msg.payload, payloadStr, PACKET_MAX_PAYLOAD_SIZE);

        // dbg(NEIGHBOR_CHANNEL, "FIRING\n");
        call Neighbor.discoverNeighbors(msg);
    }

    command error_t Neighbor.discoverNeighbors(pack msg) {
        error_t result;
        uint8_t listSize;
        uint8_t i;
        NeighborTable checkNeighbor;

        // logPack(&msg, NEIGHBOR_CHANNEL);
        
        // Instantiate list on first iteration
        if (!instList) {
            listSize = MAX_NODES;
            dbg(NEIGHBOR_CHANNEL, "Instantiating Table...\n");
            for (i = 0; i < listSize; i++) {
                NeighborTable deadNeighbor;

                deadNeighbor.lastSeen = 0;
                deadNeighbor.linkQuality = 0;
                deadNeighbor.isActive = FALSE;

                call List.pushback(deadNeighbor);
            }

            instList = TRUE;
        }

        // checkNeighbor = call List.get(8);
        // dbg(NEIGHBOR_CHANNEL, "Neighbor 8 check | Last Seen: %d, Average: %d, Active: %s\n",
        //     checkNeighbor.lastSeen, checkNeighbor.linkQuality, checkNeighbor.isActive ? "True" : "False");

        currSeq++;
        // if (currSeq == 2) {
        //     currSeq++;
        //     currSeq++;
        //     currSeq++;
        // }

        msg.seq = currSeq;

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

    command void Neighbor.outputNeighbors() {
        NeighborTable tempNeighbor;
        uint8_t i;
        char buffer[30 + (MAX_NODES * 8)];
        uint8_t pos = 0;

        pos += snprintf(buffer + pos, sizeof(buffer) - pos, "I am [%d]. My neighbors are: ", TOS_NODE_ID);
        // dbg(GENERAL_CHANNEL, "I am [%d]. My neighbors are:\n", TOS_NODE_ID);
        for (i = 1; i <= MAX_NODES; i++) {
            tempNeighbor = call List.get(i);
            // dbg(GENERAL_CHANNEL, "Neighbor %d check | Last Seen: %d, Average: %d, Active: %s\n",
            //     i, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");
            if (tempNeighbor.isActive) {
                pos += snprintf(buffer + pos, sizeof(buffer) - pos, "[%d] ", i);
                // dbg(GENERAL_CHANNEL, "Node %d\n", i);
            }
        }
        
        dbg(GENERAL_CHANNEL, "%s\n", buffer);
    }


    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        NeighborTable tempNeighbor;
        uint8_t expectedPackets;
        uint8_t lostPackets;
        uint8_t receivedAverage;

        pack* receivedMessage = (pack*)payload;

        // logPack(receivedMessage, NEIGHBOR_CHANNEL);

        if (receivedMessage->protocol == PROTOCOL_NEIGHBORREPLY) {
            dbg(NEIGHBOR_CHANNEL, "Response received from %d\n", receivedMessage->src);

            // logPack(receivedMessage, NEIGHBOR_CHANNEL);

            tempNeighbor = call List.get(receivedMessage->src);

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d Before | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");

            // Calculate expected packets
            expectedPackets = receivedMessage->seq - tempNeighbor.lastSeen;
            
            // Update lastSeen
            tempNeighbor.lastSeen = receivedMessage->seq;

            // Calculate average from last seen sequence to received sequence
            receivedAverage = 100 / expectedPackets;

            // Update linkQuality using running average formula
            if (tempNeighbor.linkQuality == 0) {
                tempNeighbor.linkQuality = receivedAverage;  // Initialize link quality on first receipt
            } else {
                tempNeighbor.linkQuality = (tempNeighbor.linkQuality + receivedAverage) / 2;  // Simple running average
            }

            // Update isActive based on defined threshold for quality
            if (tempNeighbor.linkQuality < QUALITY_THRESHOLD) {
                tempNeighbor.isActive = FALSE;
            } else {
                tempNeighbor.isActive = TRUE;
            }

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d After | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");
        
            call List.replace(receivedMessage->src, tempNeighbor);

            // logPack(receivedMessage, NEIGHBOR_CHANNEL);

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