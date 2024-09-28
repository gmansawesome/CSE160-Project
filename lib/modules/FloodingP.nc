#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingP{
   provides interface Flooding;

   uses interface SimpleSend;

   uses interface Packet;
   // uses interface Receive;
}

implementation {
    uint16_t sequenceNum = 0; // Unique sequence number for packets

    // This function initiates the flooding process
    command error_t Flooding.flood(uint8_t *data, uint16_t destination) {

        dbg(FLOODING_CHANNEL, "Node %d is running...\n", TOS_NODE_ID);

        // Create a packet structure and populate it
        pack msg;
        msg.src = TOS_NODE_ID; // Set source address
        msg.seq = sequenceNum++; // Increment sequence number
        memcpy(msg.payload, data, PACKET_MAX_PAYLOAD_SIZE); // Copy the payload data

        logPack(&msg);

        Use SimpleSend to send the packet to all neighbors (using broadcast address 0xFFFF)
        return call SimpleSend.send(&msg, AM_BROADCAST_ADDR);
    }
    
    command void Flooding.pass(){
        
    }
}