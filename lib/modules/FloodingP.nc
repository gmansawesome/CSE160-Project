#include "../../includes/packet.h"
#include "../../includes/channels.h"

module FloodingP{
   provides interface Flooding;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
}

implementation {
    command void Flooding.pass() {}

    command error_t Flooding.flood(pack msg) {
        error_t result;

        logPack(&msg, FLOODING_CHANNEL);

        // Send the flood message using SimpleSend
        result = call SimpleSend.send(msg, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flooding message sent successfully from %d\n", TOS_NODE_ID);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send flooding message from %d\n", TOS_NODE_ID);
        }

        return result;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        // Cast the received payload to a packet structure
        pack* receivedMessage = (pack*)payload;

        dbg(FLOODING_CHANNEL, "Packet received from %d\n", receivedMessage->src);

        logPack(receivedMessage, FLOODING_CHANNEL);

        if (receivedMessage->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        }

        receivedMessage->TTL -= 1; 

        call Flooding.flood(*receivedMessage);

        return msg;
    }
}