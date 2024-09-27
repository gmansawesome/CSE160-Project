#include "AM.h"            // Active message support
#include "message.h"        // TinyOS message structure
#include "Timer.h"          // Timer interface
#include "../../includes/packet.h"  // For NeighborBeacon and pack structures
#include "Receive.nc"  // Make sure this is included for the Receive interface

module NeighborP {
    provides interface Neighbor;
    uses interface AMSend;
    uses interface Packet;
    uses interface Receive;
    uses interface Timer<TMilli> as beaconTimer;
}

implementation {
    typedef struct {
        uint16_t neighborID;
        uint32_t lastHeard;
    } NeighborEntry;

    NeighborEntry neighborTable[10];  // Max 10 neighbors
    uint8_t neighborCount = 0;

    void addNeighbor(uint16_t neighborID);

    event void beaconTimer.fired() {
        NeighborBeacon beacon;
        beacon.nodeID = TOS_NODE_ID;
        beacon.timestamp = call beaconTimer.getNow();

        message_t beaconMsg;  // Declare the message_t structure here

        // Retrieve the payload
        void* payload = call Packet.getPayload(&beaconMsg, sizeof(NeighborBeacon));
        memcpy(payload, &beacon, sizeof(NeighborBeacon));  // Copy the beacon data into the payload

        dbg(NEIGHBOR_CHANNEL, "Node %d: Sending neighbor discovery beacon\n", TOS_NODE_ID);
        call AMSend.send(AM_BROADCAST_ADDR, &beaconMsg, sizeof(NeighborBeacon));  // Send the beacon message
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        NeighborBeacon* beacon = (NeighborBeacon*) payload;

        dbg(NEIGHBOR_CHANNEL, "Node %d: Received beacon from Node %d\n", TOS_NODE_ID, beacon->nodeID);
        addNeighbor(beacon->nodeID);
        return msg;
    }

    void addNeighbor(uint16_t neighborID) {
        uint8_t i;
        for (i = 0; i < neighborCount; i++) {
            if (neighborTable[i].neighborID == neighborID) {
                neighborTable[i].lastHeard = call beaconTimer.getNow();
                return;
            }
        }

        if (neighborCount < 10) {
            neighborTable[neighborCount].neighborID = neighborID;
            neighborTable[neighborCount].lastHeard = call beaconTimer.getNow();
            neighborCount++;
            dbg(NEIGHBOR_CHANNEL, "Node %d: Added neighbor %d\n", TOS_NODE_ID, neighborID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Neighbor table is full, cannot add neighbor %d\n", TOS_NODE_ID, neighborID);
        }
    }

    // Implement the Neighbor interface functions
    command void Neighbor.pass() {
        // Placeholder function, can be used for future implementation
    }

    command uint8_t Neighbor.getNeighborCount() {
        return neighborCount;
    }

    command uint16_t Neighbor.getNeighbor(uint8_t neighborIndex) {
        if (neighborIndex < neighborCount) {
            return neighborTable[neighborIndex].neighborID;
        } else {
            return 0;  // Return 0 if index is out of bounds
        }
    }

    event void AMSend.sendDone(message_t* msg, error_t result) {
        if (result == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Beacon sent successfully\n", TOS_NODE_ID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Failed to send beacon\n", TOS_NODE_ID);
        }
    }

    command void Neighbor.start() {
        dbg(NEIGHBOR_CHANNEL, "Node %d: Starting neighbor discovery\n", TOS_NODE_ID);
        call beaconTimer.startPeriodic(1000);  // Send beacons every second
    }
}