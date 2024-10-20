#include "../../includes/packet.h"
#include "../../includes/channels.h"

#define ROUTING_TIME_INTERVAL 100000 //10ms

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

    // update self neighbor entries, and flood LSP to all nodes.
    void floodLSP() {
        uint8_t i;
        uint8_t total = 0;
        uint8_t count = 0;
        pack msg;
        uint8_t tempPayload[MAX_NODES];

        clearNeighbors(TOS_NODE_ID);
    
        activeNeighborPointer = call Neighbor.requestNeighbors();

        for (i = 0; i < MAX_NODES; i++) {
            if (activeNeighborPointer[i] == 0) {
                break;
            }

            allNeighbors[(TOS_NODE_ID-1)*MAX_NODES + i] = activeNeighborPointer[i];
            total++;
        }

        while (count < total) {
            msg.dest = 0;
            msg.src = TOS_NODE_ID;
            msg.seq = 0;
            msg.TTL = MAX_TTL;
            msg.protocol = PROTOCOL_LINKSTATE;

            for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
                tempPayload[i] = allNeighbors[(TOS_NODE_ID-1)*MAX_NODES + count];
                count++;
            }
            
            memcpy(msg.payload, tempPayload, PACKET_MAX_PAYLOAD_SIZE);

            call Flooding.flood(msg);

            // logPack(&msg, ROUTING_CHANNEL);
        }
    }

    event void Boot.booted() {
        uint8_t i; 

        // init array on startup
        for (i = 1; i <= MAX_NODES; i++) {
            clearNeighbors(i);
        }

        floodLSP();

        call Timer.startPeriodic(ROUTING_TIME_INTERVAL);
    }

    event void Timer.fired() {
        floodLSP();
    }

    command void Routing.addNeighbors(uint16_t src, uint8_t* receivedPayload) {
        uint8_t i;

        clearNeighbors(src);

        for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
            if (receivedPayload[i] == 0) {
                break;
            }

            // if (TOS_NODE_ID == 4) {
            //     dbg(ROUTING_CHANNEL, "Source: %d, Adding %d at %d\n", src, receivedPayload[i], (src-1)*MAX_NODES + i);
            // }
            
            allNeighbors[(src-1)*MAX_NODES + i] = receivedPayload[i];
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