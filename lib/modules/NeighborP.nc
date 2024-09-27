#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborP {
    provides interface Neighbor;
    uses interface SimpleSend;  // Use SimpleSend for sending beacons
    uses interface Timer<TMilli> as beaconTimer;  // Timer to send beacons
    uses interface Random;  // Use the Random interface for random number generation
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
        pack beaconMsg;  // Declare the packet structure
        error_t result;

        // Set up the beacon with the current node ID and timestamp
        beaconMsg.src = TOS_NODE_ID;
        beaconMsg.seq = call Random.rand16();  // Generate a random sequence number for the beacon
        beaconMsg.TTL = MAX_TTL;  // Use maximum TTL
        beaconMsg.protocol = 0;  // You can define a custom protocol value for neighbor discovery beacons

        dbg(NEIGHBOR_CHANNEL, "Node %d: Sending neighbor discovery beacon\n", TOS_NODE_ID);

        // Use SimpleSend to send the beacon message
        result = call SimpleSend.send(beaconMsg, AM_BROADCAST_ADDR);  // Send to the broadcast address

        // Check the result of the send operation
        if (result != SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Failed to send beacon message\n", TOS_NODE_ID);
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