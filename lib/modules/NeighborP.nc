#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborP {
    provides interface Neighbor;
    uses interface AMSend;
    uses interface Packet;
    uses interface Timer<TMilli> as beaconTimer;  // Timer to send beacons
    uses interface AMPacket;  // For receiving packets directly
    uses interface Receive;  // Declare the Receive interface for receiving messages
}

implementation {
    typedef struct {
        uint16_t neighborID;
        uint32_t lastHeard;
    } NeighborEntry;

    NeighborEntry neighborTable[10];  // Max 10 neighbors
    uint8_t neighborCount = 0;
    uint32_t NEIGHBOR_TIMEOUT = 60000;  // 60 seconds timeout for dead neighbors

    // Function to add or update a neighbor
    void addOrUpdateNeighbor(uint16_t neighborID);

    // Function to clean up dead neighbors
    void removeDeadNeighbors();

    // Timer event for sending periodic beacons every 30 seconds
    event void beaconTimer.fired() {
        // Declare the message and beacon structures
        message_t beaconMsg;  // Declare the message structure
        NeighborBeacon beacon;  // Declare the NeighborBeacon structure
        NeighborBeacon* msg;
        error_t result;
        // Set up the beacon with the current node ID and timestamp
        beacon.nodeID = TOS_NODE_ID;
        beacon.timestamp = call beaconTimer.getNow();

        // Retrieve the payload from the message packet
        msg = (NeighborBeacon*)(call Packet.getPayload(&beaconMsg, sizeof(NeighborBeacon)));
        
        // Check if the payload was retrieved successfully
        if (msg != NULL) {
            // Copy the beacon structure into the payload
            *msg = beacon;

            dbg(NEIGHBOR_CHANNEL, "Node %d: Sending neighbor discovery beacon\n", TOS_NODE_ID);

            // Declare the result variable for sending the message
            result = call AMSend.send(AM_BROADCAST_ADDR, &beaconMsg, sizeof(NeighborBeacon));
            
            // Check the result of the send operation
            if (result != SUCCESS) {
                dbg(NEIGHBOR_CHANNEL, "Node %d: Failed to send beacon message\n", TOS_NODE_ID);
            }
        } else {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Failed to get payload\n", TOS_NODE_ID);
        }
    }

    // Function to add or update a neighbor
    void addOrUpdateNeighbor(uint16_t neighborID) {
        uint8_t i;
        uint32_t currentTime = call beaconTimer.getNow();

        // Update existing neighbor
        for (i = 0; i < neighborCount; i++) {
            if (neighborTable[i].neighborID == neighborID) {
                neighborTable[i].lastHeard = currentTime;  // Update last heard time
                return;
            }
        }

        // Add new neighbor if not found
        if (neighborCount < 10) {
            neighborTable[neighborCount].neighborID = neighborID;
            neighborTable[neighborCount].lastHeard = currentTime;
            neighborCount++;
            dbg(NEIGHBOR_CHANNEL, "Node %d: Added new neighbor %d\n", TOS_NODE_ID, neighborID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Neighbor table full, cannot add neighbor %d\n", TOS_NODE_ID, neighborID);
        }
    }

    // Function to remove dead neighbors
    void removeDeadNeighbors() {
        uint8_t i, j;
        uint32_t currentTime = call beaconTimer.getNow();

        for (i = 0; i < neighborCount; i++) {
            if (currentTime - neighborTable[i].lastHeard > NEIGHBOR_TIMEOUT) {
                dbg(NEIGHBOR_CHANNEL, "Node %d: Removing dead neighbor %d\n", TOS_NODE_ID, neighborTable[i].neighborID);

                // Remove the neighbor and shift the remaining entries
                for (j = i; j < neighborCount - 1; j++) {
                    neighborTable[j] = neighborTable[j + 1];
                }

                neighborCount--;
                i--;  // Adjust index since we just shifted neighbors
            }
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        // Check if the received message is a NeighborBeacon
        if (len == sizeof(NeighborBeacon)) {
            NeighborBeacon* beacon = (NeighborBeacon*) payload;

            // Log the received beacon message
            dbg(NEIGHBOR_CHANNEL, "Node %d: Received beacon from Node %d\n", TOS_NODE_ID, beacon->nodeID);

            // Add or update the neighbor in the neighbor table
            addOrUpdateNeighbor(beacon->nodeID);
        }

        // Return the message to be reused
        return msg;
    }


    // Event for sending done
    event void AMSend.sendDone(message_t* msg, error_t result) {
        if (result == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Beacon sent successfully\n", TOS_NODE_ID);
        } else {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Failed to send beacon\n", TOS_NODE_ID);
        }
    }

    // Start function to begin neighbor discovery and dead neighbor cleanup
    command void Neighbor.start() {
        dbg(NEIGHBOR_CHANNEL, "Node %d: Starting neighbor discovery\n", TOS_NODE_ID);
        call beaconTimer.startPeriodic(30000);  // Send beacons every 30 seconds
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

    command void Neighbor.pass() {
        // Placeholder for any future functionality
    }
}