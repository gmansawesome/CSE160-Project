#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/neighborInfo.h"

#define ROUTING_TIME_INTERVAL 100000 //10ms

module RoutingP{
    provides interface Routing;
    uses interface Packet;
    uses interface Timer<TMilli>;
    uses interface Boot;
    uses interface Neighbor;
    uses interface List<NeighborInfo>;
}

implementation {
    uint16_t* activeNeighborPointer;

    command void Routing.pass() {};

    void initNodeList(uint8_t node) {
        uint8_t i; 
        NeighborInfo emptyInfo;

        for (i = 0; i < MAX_NODES; i++) {
            emptyInfo.from = TOS_NODE_ID;
            emptyInfo.to = 0;

            call List.replace(TOS_NODE_ID+i, emptyInfo);
        }
    }

    event void Boot.booted() {
        call Timer.startPeriodic(ROUTING_TIME_INTERVAL);
    }

    event void Timer.fired() {
        uint8_t i; 
        NeighborInfo emptyInfo;
        
        activeNeighborPointer = call Neighbor.requestNeighbors();

        for (i = 0; i < MAX_NODES; i++) {
            if (activeNeighborPointer[i] == 0) {
                break;
            }
            emptyInfo.from = TOS_NODE_ID;
            emptyInfo.to = activeNeighborPointer[i];

            call List.replace(TOS_NODE_ID+i, emptyInfo);
        }
        
        for (i = 0; i < MAX_NODES; i++) {
            emptyInfo = call List.get(TOS_NODE_ID+i);

            // if (emptyInfo.from == 0) {
            //     break;
            // }

            dbg(ROUTING_CHANNEL, "I am [%d] | Neighbor: [%d]\n", TOS_NODE_ID, emptyInfo.to);
        }
    }

    void floodLSP() {
        uint8_t i; 
        NeighborInfo emptyInfo;
        
        activeNeighborPointer = call Neighbor.requestNeighbors();

        for (i = 0; i < MAX_NODES; i++) {

        }
    }
}