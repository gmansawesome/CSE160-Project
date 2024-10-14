#include "../../includes/packet.h"
#include "../../includes/link_layer.h"
#include "../../includes/channels.h"

#define INT_MAX 32767

module FloodingP{
   provides interface Flooding;
   uses interface Packet;
   uses interface Receive;
   uses interface SimpleSend;
   uses interface List<uint16_t>;
}

implementation {
    bool instList = FALSE;

    void instantiateList() {
        uint8_t i;

        // dbg(FLOODING_CHANNEL, "Instantiating flooding cache...\n");
        for (i = 0; i < MAX_NODES; i++) {
            call List.pushback(INT_MAX);
        }

        instList = TRUE;
    }

    command error_t Flooding.flood(pack msg) {
        error_t result;

        // logPack(&msg, FLOODING_CHANNEL);

        // Check if flood source is sender
        if (msg.dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "I received a message from %d. The message states: %s\n",
                msg.src, msg.payload);
            return result;
        }

        // Instantiate flooding cache if not instantiated
        if (!instList) {
            instantiateList();
            call List.replace(msg.src, msg.seq);
        }        

        msg.seq += 1;
        msg.TTL -= 1; 

        // Send the flood message using SimpleSend
        result = call SimpleSend.send(msg, AM_BROADCAST_ADDR);

        if (result == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Packet SENT successfully from %d\n", TOS_NODE_ID);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send packet from %d\n", TOS_NODE_ID);
        }

        return result;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        uint16_t latestSequence;

        // Cast the received payload to a packet structure
        pack* receivedMessage = (pack*)payload;

        dbg(FLOODING_CHANNEL, "Packet RECEIVED from flood source %d\n", receivedMessage->src);
        
        // logPack(receivedMessage, FLOODING_CHANNEL);

        // Instantiate flooding cache if not instantiated
        if (!instList) {
            instantiateList();
        }        

        // Check for end of TTL
        if (receivedMessage->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from flood source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        } 

        // Check for duplicate sequence numbers
        latestSequence = call List.get(receivedMessage->src);  
        // dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", latestSequence, receivedMessage->seq);  
        if (latestSequence <= receivedMessage->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate detected. Dropping packet from flood source %d\n", 
                receivedMessage->src);
            return msg;
        }

        // Update flooding cache
        call List.replace(receivedMessage->src, receivedMessage->seq);

        // latestSequence = call List.get(receivedMessage->src);  
        // dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", latestSequence, receivedMessage->seq);  

        // Check if I am the destination!!!
        // Hello... is it me you're looking for?
        if (receivedMessage->dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "I received a message from %d. The message states: %s\n",
                receivedMessage->src, receivedMessage->payload);
            return msg;
        }

        // Reflood using flood()
        call Flooding.flood(*receivedMessage);

        return msg;
    }
}