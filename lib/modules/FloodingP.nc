#include "../../includes/packet.h"
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

    command error_t Flooding.flood(uint16_t destination, uint8_t *payload, uint8_t timeToLive) {
        pack message;
        error_t result;

        // Prepare the flood packet
        message.dest = destination;  // Target destination
        message.src = TOS_NODE_ID;   // Source node ID, assuming TOS_NODE_ID is defined
        message.seq = ++lastSeqNum;  // Increment sequence number for uniqueness
        message.TTL = timeToLive;       // Set TTL to maximum value
        message.protocol = PROTOCOL_PING;  // Define protocol type for flood packets
        memcpy(message.payload, payload, PACKET_MAX_PAYLOAD_SIZE);

        // Send the flood message using SimpleSend
        result = call SimpleSend.send(message, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flooding message sent successfully from %d\n", TOS_NODE_ID, destination);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send flooding message from %d\n", TOS_NODE_ID, destination);
        }

        return result;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        // Cast the received payload to a packet structure
        pack* receivedMessage = (pack*)payload;

        // Log the received packet information
        logPack(receivedMessage);

        dbg(FLOODING_CHANNEL, "Current seq: %d\n", lastSeqNum);

        if (receivedMessage->seq <= lastSeqNum) {
            dbg(FLOODING_CHANNEL, "Duplicate packet detected. Dropping packet from source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        }

        if (receivedMessage->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        }

        lastSeqNum = receivedMessage->seq;

        call Flooding.flood(receivedMessage->dest, receivedMessage->payload, receivedMessage->TTL - 1);

        return msg;
    }
}