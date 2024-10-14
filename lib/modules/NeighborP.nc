#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/neighborTable.h"

#define ND_TIME_INTERVAL 120000 //120ms
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
        // Start running ND
        call Timer.startPeriodic(ND_TIME_INTERVAL);
    }

    event void Timer.fired() {
        error_t result;
        uint8_t i;
        pack msg;
        const char *payloadStr = "Are you my friend?";

        // Instantiate neighbor cache on first iteration
        if (!instList) {
            // dbg(NEIGHBOR_CHANNEL, "Instantiating neighbor cache...\n");
            for (i = 0; i < MAX_NODES; i++) {
                NeighborTable emptyNeighbor;

                emptyNeighbor.lastSeen = 0;
                emptyNeighbor.linkQuality = 0;
                emptyNeighbor.isActive = FALSE;

                call List.pushback(emptyNeighbor);
            }

            instList = TRUE;
        }

        // Setting up ND Packet
        msg.src = TOS_NODE_ID;
        msg.dest = 0;
        msg.TTL = 0;
        currSeq++;
        msg.seq = currSeq;
        msg.protocol = PROTOCOL_ND_REQUEST;
        memcpy(msg.payload, payloadStr, PACKET_MAX_PAYLOAD_SIZE);

        // Broadcasting ND packet
        result = call SimpleSend.send(msg, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "ND packet sent successfully from %d\n", TOS_NODE_ID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Failed to send ND packet from %d\n", TOS_NODE_ID);
        }

        // Fake packet loss
        // if (currSeq == 20) {
        //     currSeq += 10;
        // }

        // Update neighbors who missed all of the last 10 packets
        if (currSeq % 10 == 0) {
            for (i = 1; i <= MAX_NODES; i++) {
                NeighborTable tempNeighbor;

                tempNeighbor = call List.get(i);
                // dbg(GENERAL_CHANNEL, "Neighbor %d | Last Seen: %d, Average: %d, Active: %s\n",
                // i, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");

                if (currSeq-10 >= tempNeighbor.lastSeen) {
                    // dbg(GENERAL_CHANNEL, "Neighbor %d | Last Seen: %d, Average: %d, Active: %s\n",
                    // i, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");
                    tempNeighbor.lastSeen = currSeq;
                    tempNeighbor.linkQuality = 0;
                    tempNeighbor.isActive = FALSE;
                    // dbg(GENERAL_CHANNEL, "Neighbor %d | Last Seen: %d, Average: %d, Active: %s\n",
                    // i, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");

                    call List.replace(i, tempNeighbor);
                }
            }    
        }
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

        if (receivedMessage->protocol == PROTOCOL_ND_REPLY) {
            dbg(NEIGHBOR_CHANNEL, "Reply received from %d\n", receivedMessage->src);

            tempNeighbor = call List.get(receivedMessage->src);

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d Before | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");

            // Calculate expected packets
            expectedPackets = receivedMessage->seq - tempNeighbor.lastSeen;
            
            // Update lastSeen
            tempNeighbor.lastSeen = receivedMessage->seq;

            // Calculate average from last seen sequence to received sequence
            receivedAverage = 100 / expectedPackets;

            // Update linkQuality
            if (tempNeighbor.linkQuality == 0) {
                tempNeighbor.linkQuality = receivedAverage;
            } else {
                tempNeighbor.linkQuality = (tempNeighbor.linkQuality + receivedAverage) / 2;
            }

            // Update isActive
            if (tempNeighbor.linkQuality < QUALITY_THRESHOLD) {
                tempNeighbor.isActive = FALSE;
            } else {
                tempNeighbor.isActive = TRUE;
            }

            dbg(NEIGHBOR_CHANNEL, "Neighbor %d After | Last Seen: %d, Average: %d, Active: %s\n",
                receivedMessage->src, tempNeighbor.lastSeen, tempNeighbor.linkQuality, tempNeighbor.isActive ? "True" : "False");
        
            call List.replace(receivedMessage->src, tempNeighbor);

            // logPack(receivedMessage, NEIGHBOR_CHANNEL);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Request received from %d\n", receivedMessage->src);

            receivedMessage->dest = receivedMessage->src;
            receivedMessage->src = TOS_NODE_ID;
            receivedMessage->protocol = PROTOCOL_ND_REPLY;
            
            // logPack(receivedMessage, NEIGHBOR_CHANNEL);

            call SimpleSend.send(*receivedMessage, receivedMessage->dest);
        }

        return msg;
    }
}