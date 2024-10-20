#include "../../includes/packet.h"
#include "../../includes/channels.h"

#define ROUTING_TIME_INTERVAL 100000 //100ms

module RoutingP{
    provides interface Routing;
    uses interface Packet;
    uses interface Timer<TMilli>;
    uses interface Boot;
    uses interface Neighbor;
    uses interface Flooding;
}

implementation {
    uint16_t* activeNeighborPointer;

    static uint16_t allNeighbors[MAX_NODES*MAX_NODES];

    // clear all array neighbors entries for a specific node
    void clearNeighbors(uint8_t node) {
        uint8_t i; 

        for (i = 0; i < MAX_NODES; i++) {
            allNeighbors[(node-1)*MAX_NODES + i] = 0;
        }
    }

    // update self neighbor entries and flood LSP to all other nodes.
    void floodLSP() {
        uint8_t i;
        uint8_t total = 0;
        uint8_t count = 0;
        pack msg;
        uint8_t tempPayload[MAX_NODES];
        uint8_t offset = 0;
    
        activeNeighborPointer = call Neighbor.requestNeighbors();

        clearNeighbors(TOS_NODE_ID);

        // update self neighbor entries
        for (i = 0; i < MAX_NODES; i++) {
            if (activeNeighborPointer[i] == 0) {
                // if (TOS_NODE_ID == 9 && i < 20) {
                //     activeNeighborPointer[i] = (i % 10) + 1; // remove later
                // }
                // else {
                //     break;
                // }
        
                break;
            }

            allNeighbors[(TOS_NODE_ID-1)*MAX_NODES + i] = activeNeighborPointer[i];
            total++;
        }

        // if (TOS_NODE_ID == 1) {
        //     dbg(ROUTING_CHANNEL, "Total: %d\n", total);
        // }

        // send out LSP, fragmented if necessary
        while (count <= total) {
            msg.dest = offset; // change later
            msg.src = TOS_NODE_ID;
            msg.seq = 0;
            msg.TTL = MAX_TTL;
            msg.protocol = PROTOCOL_LINKSTATE;
            tempPayload[0] = offset;

            for (i = 1; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
                tempPayload[i] = allNeighbors[(TOS_NODE_ID-1)*MAX_NODES + count];
                count++;

                if (count > total) {
                    tempPayload[i] = 0;
                }
                else {
                    offset++;
                }
            }
            
            memcpy(msg.payload, tempPayload, PACKET_MAX_PAYLOAD_SIZE);

            call Flooding.flood(msg);

            // logPack(&msg, ROUTING_CHANNEL);

            // if (TOS_NODE_ID == 1) {
            //     dbg(ROUTING_CHANNEL, "Packet sent from %d with offset %d\n", TOS_NODE_ID, msg.dest);
            // }
        }
    }

    event void Boot.booted() {
        uint8_t i; 

        // init array on startup
        for (i = 1; i <= MAX_NODES; i++) {
            clearNeighbors(i);
        }

        call Timer.startPeriodic(ROUTING_TIME_INTERVAL);
    }

    event void Timer.fired() {
        // dbg(ROUTING_CHANNEL, "FIRED\n");
        floodLSP();
    }

    // update neighbor entries for recieved LSP
    command void Routing.addNeighbors(uint16_t src, uint8_t* receivedPayload) {
        uint8_t i;
        uint8_t offset;

        // need to compare current neighbors to new, to see if anyone dropped

        offset = receivedPayload[0];

        if (offset == 0) {
            clearNeighbors(src);
        }

        for (i = 1; i <= PACKET_MAX_PAYLOAD_SIZE-1; i++) {
            if (receivedPayload[i] == 0) {
                break;
            }

            // if (TOS_NODE_ID == 4 && src == 1) {
            //     dbg(ROUTING_CHANNEL, "Source: %d, Offset: %d, Adding %d at position %d\n", src, offset, receivedPayload[i], (src-1)*MAX_NODES + offset + i - 1);
            // }
            
            allNeighbors[(src-1)*MAX_NODES + offset + i - 1] = receivedPayload[i];
        }
    }

    command void Routing.outputAllNeighbors() {
        uint8_t i;
        uint8_t j;

        for (i = 1; i <= MAX_NODES; i++) {
            for (j = 0; j < MAX_NODES; j++) {
                if (allNeighbors[(i-1)*MAX_NODES + j] == 0) {
                    // dbg(ROUTING_CHANNEL, "Breaking on Node: %d\n", i);
                    break;
                }

                if (j == 0) {
                    dbg(ROUTING_CHANNEL, "Current Node: %d\n", i);
                }

                dbg(ROUTING_CHANNEL, "Node: [%d], Position: %d, Neighbor: [%d]\n", i, (i-1)*MAX_NODES + j, allNeighbors[(i-1)*MAX_NODES + j]);
            }
        }
    }
}