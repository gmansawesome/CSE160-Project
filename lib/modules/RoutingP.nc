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
    uint8_t* activeNeighborPointer;
    uint8_t clearCount = 0;

    uint8_t routingTableDist[MAX_NODES];
    uint8_t routingTableNextHop[MAX_NODES];
    bool visited[MAX_NODES];

    // flattened adjacency matrix for Link State info
    static uint8_t allNeighbors[MAX_NODES*MAX_NODES];

    void initializeRoutingTable() {
        uint8_t i;

        // dbg(ROUTING_CHANNEL, "Initializing Routing Table...\n");
        for (i = 0; i < MAX_NODES; i++) {
            routingTableDist[i] = 255;
            routingTableNextHop[i] = 0;
            visited[i] = FALSE;
        }

        routingTableDist[TOS_NODE_ID-1] = 0;
        routingTableNextHop[TOS_NODE_ID-1] = TOS_NODE_ID;
    }

    uint8_t findMinDistanceNode() {
        uint8_t i;
        uint8_t min = 255;
        uint8_t minIndex = MAX_NODES;

        for (i = 0; i < MAX_NODES; i++) {
            if (!visited[i] && routingTableDist[i] < min) {
                min = routingTableDist[i];
                minIndex = i;
            }
        }

        if (minIndex != MAX_NODES) {
            // dbg(ROUTING_CHANNEL, "Min distance node found: %d\n", minIndex+1);
        }

        return minIndex;
    }

    // build routing table using Dijkstra's algorithm
    void buildRoutingTable() {
        uint8_t i;
        uint8_t u;
        uint8_t neighborIndex;
        uint8_t neighbor;

        initializeRoutingTable();

        // Process each node
        for (i = 0; i < MAX_NODES-1; i++) {
            u = findMinDistanceNode();

            if (u == MAX_NODES) {
                break;
            }

            visited[u] = TRUE;

            for (neighborIndex = 0; neighborIndex < MAX_NODES; neighborIndex++) {
                neighbor = allNeighbors[u * MAX_NODES + neighborIndex];

                if (neighbor == 0) {
                    break;
                }

                if (!visited[neighbor-1]) {
                    if (routingTableDist[u] + 1 < routingTableDist[neighbor-1]) {
                        // dbg(ROUTING_CHANNEL, "On Node [%d]. Adding Neighbor [%d], with value %d\n", u+1, neighbor, routingTableDist[u] + 1);
                        routingTableDist[neighbor-1] = routingTableDist[u] + 1;
                        if (u+1 == TOS_NODE_ID) {
                            routingTableNextHop[neighbor-1] = neighbor;
                        }
                        else {
                            routingTableNextHop[neighbor-1] = routingTableNextHop[u];
                        }
                    }
                }
            }
        }
    }

    void printRoutingTable() {
        uint8_t i;

        dbg(ROUTING_CHANNEL, "Routing Table for: %d\n", TOS_NODE_ID);
        for (i = 0; i < MAX_NODES; i++) {
            // if (routingTableDist[i] == 255) {
            //     break;
            // }
            dbg(ROUTING_CHANNEL, "[%d] -> %d -> [%d]\n", i+1, routingTableDist[i], routingTableNextHop[i]);
        }
    }

    // clear all array neighbors entries for a specific node
    void clearNeighbors(uint8_t node) {
        uint8_t i; 

        for (i = 0; i < MAX_NODES; i++) {
            allNeighbors[(node-1)*MAX_NODES + i] = 0;
        }
    }

    // update self neighbor entries and flood LSP to all other nodes.
    command void Routing.floodLSP() {
        uint8_t i;
        uint8_t total = 0;
        uint8_t count = 0;
        pack msg;
        uint8_t tempPayload[MAX_NODES];
        uint8_t offset = 0;
    
        activeNeighborPointer = call Neighbor.requestNeighbors();

        // clearNeighbors(TOS_NODE_ID);

        // update self neighbor entries
        for (i = 0; i < MAX_NODES; i++) {
            if (activeNeighborPointer[i] == 0) {
                // if (TOS_NODE_ID == 1) {
                //     activeNeighborPointer[i] = (i % 10) + 1; // remove later
                // }
                // else {
                //     break;
                // }
        
                break;
            }

            // allNeighbors[(TOS_NODE_ID-1)*MAX_NODES + i] = activeNeighborPointer[i];
            total++;
        }

        // if (TOS_NODE_ID == 1) {
        //     dbg(ROUTING_CHANNEL, "Total: %d\n", total);
        // }

        // send out LSP, fragmented if necessary
        while (count <= total) {
            msg.dest = 0; // change later
            msg.src = TOS_NODE_ID;
            msg.seq = 0;
            msg.TTL = MAX_TTL;
            msg.protocol = PROTOCOL_LINKSTATE;
            tempPayload[0] = offset;

            for (i = 1; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
                tempPayload[i] = activeNeighborPointer[count];
                count++;

                if (count > total) {
                    tempPayload[i] = 0;
                }
                else {
                    offset++;
                }
            }

            call Routing.addNeighbors(TOS_NODE_ID, tempPayload);
            
            memcpy(msg.payload, tempPayload, PACKET_MAX_PAYLOAD_SIZE);

            call Flooding.flood(msg);

            // logPack(&msg, ROUTING_CHANNEL);

            // if (TOS_NODE_ID == 1) {
            //     dbg(ROUTING_CHANNEL, "Packet sent from %d with offset %d\n", TOS_NODE_ID, msg.dest);
            // }
        }
    }

    // update neighbor entries for recieved LSP
    command void Routing.addNeighbors(uint8_t src, uint8_t* receivedPayload) {
        uint8_t i;
        uint8_t j;
        uint8_t offset;
        bool found;

        offset = receivedPayload[0];

        // need to compare current neighbors to new, to see if anyone dropped
        for (i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++) {
            if (allNeighbors[(src-1)*MAX_NODES + offset + i] == 0 || (allNeighbors[(allNeighbors[(src-1)*MAX_NODES + offset + i]-1)*MAX_NODES] == 0 && src != allNeighbors[(src-1)*MAX_NODES + offset + i]-1)) {
                break;
            }

            // if (TOS_NODE_ID == 4 && src == 4) {
            //     dbg(ROUTING_CHANNEL, "Node [%d] at [%d]\n", allNeighbors[(src-1)*MAX_NODES + offset + i], src);
            // }
            
            found = FALSE;
            for (j = 1; j <= PACKET_MAX_PAYLOAD_SIZE; j++) {
                if (receivedPayload[j] == 0) {
                    break;
                }

                if (allNeighbors[(src-1)*MAX_NODES + offset + i] == receivedPayload[j]) {
                    found = TRUE;
                }
            }

            // if (TOS_NODE_ID == 4 && src == 4) {
                if (!found) {
                    // dbg(ROUTING_CHANNEL, "Node [%d] lost at [%d]\n", allNeighbors[(src-1)*MAX_NODES + offset + i], src);
                    clearNeighbors(allNeighbors[(src-1)*MAX_NODES + offset + i]);
                }
                else {
                    // dbg(ROUTING_CHANNEL, "Node [%d] found at [%d]\n", allNeighbors[(src-1)*MAX_NODES + offset + i], src);
                }
            // }
        }

        if (offset == 0) {
            // if (src == 8) {
            //     dbg(ROUTING_CHANNEL, "Clearing Node [%d]\n", src);
            // }
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

            // if (TOS_NODE_ID == 4 && src == 8) {
            //     dbg(ROUTING_CHANNEL, "Check %d at position %d\n", allNeighbors[(src-1)*MAX_NODES + offset + i - 1], (src-1)*MAX_NODES + offset + i - 1);
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
        uint8_t i; 

        // periodically flood LSP, and clear LSP table
        // dbg(ROUTING_CHANNEL, "FIRED\n");
        call Routing.floodLSP();
        // buildRoutingTable();
        clearCount++;

        if (clearCount == 20) {
            // dbg(ROUTING_CHANNEL, "CLEARING LSP TABLE\n");
            // for (i = 1; i <= MAX_NODES; i++) {
            //     clearNeighbors(i);
            // }
            clearCount = 0;
        }
    }

    // output all neighbors using LSP Table
    command void Routing.outputAllNeighbors() {
        uint8_t i;
        uint8_t j;

        buildRoutingTable();
        printRoutingTable();

        dbg(ROUTING_CHANNEL, "Link State info for: %d\n", TOS_NODE_ID);
        for (i = 1; i <= MAX_NODES; i++) {
            for (j = 0; j < MAX_NODES; j++) {
                if (allNeighbors[(i-1)*MAX_NODES + j] == 0) {
                    // dbg(ROUTING_CHANNEL, "Breaking on Node: %d\n", i);
                    break;
                }

                // if (i < 10) {
                    if (j == 0) {
                        dbg(ROUTING_CHANNEL, "Current Node: %d\n", i);
                    }

                    dbg(ROUTING_CHANNEL, "Node: [%d], Position: %d, Neighbor: [%d]\n", i, (i-1)*MAX_NODES + j, allNeighbors[(i-1)*MAX_NODES + j]);
                // }
            }
        }
    }

    // return next hop from Routing Table for packet forwarding
    command uint8_t Routing.forwarding(uint8_t dest) {
        buildRoutingTable();

        if (dest > 0 && dest <= MAX_NODES) {
            return routingTableNextHop[dest-1];
        }

        return dest;
    }
}