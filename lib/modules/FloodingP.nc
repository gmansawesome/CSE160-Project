#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingP{
   provides interface Flooding;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
}

implementation {
    uint16_t lastSeqNum = 0;

    command void Flooding.pass() {}

    command error_t Flooding.flood(uint16_t destination, uint8_t *payload) {
        pack message;
        error_t result;

        dbg(FLOODING_CHANNEL, "flood running...\n");

        // Prepare the flood packet
        message.dest = destination;  // Target destination
        message.src = TOS_NODE_ID;   // Source node ID, assuming TOS_NODE_ID is defined
        message.seq = ++lastSeqNum;  // Increment sequence number for uniqueness
        message.TTL = MAX_TTL;       // Set TTL to maximum value
        message.protocol = PROTOCOL_PING;  // Define protocol type for flood packets
        memcpy(message.payload, payload, PACKET_MAX_PAYLOAD_SIZE);

        // Send the flood message using SimpleSend
        result = call SimpleSend.send(message, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flooding message sent successfully to destination %d\n", destination);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send flooding message to destination %d\n", destination);
        }

        return result;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    
    }
}