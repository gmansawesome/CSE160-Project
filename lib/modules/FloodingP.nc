#include "../../includes/packet.h"
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

    command void Flooding.pass() {}

    command void Flooding.instantiateList() {
        uint8_t listSize;
        uint8_t i;

        listSize = MAX_NODES;
        dbg(FLOODING_CHANNEL, "Instantiating...\n");
        for (i = 0; i < listSize; i++) {
            call List.pushback(INT_MAX);
        }

        instList = TRUE;
    }

    command error_t Flooding.flood(pack msg) {
        error_t result;

        logPack(&msg, FLOODING_CHANNEL);

        if (!instList) {
            call Flooding.instantiateList();
            call List.insert(msg.src, msg.seq);
        }        

        // Iterate TTL
        msg.TTL -= 1; 

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
        uint16_t latestSequence;

        // Cast the received payload to a packet structure
        pack* receivedMessage = (pack*)payload;

        dbg(FLOODING_CHANNEL, "Packet received from %d\n", receivedMessage->src);
        logPack(receivedMessage, FLOODING_CHANNEL);

        // Check for end of TTL
        if (receivedMessage->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        }

        // Instantiate List if not instantiated
        if (!instList) {
            call Flooding.instantiateList();
        }        

        latestSequence = call List.get(receivedMessage->src);  
        dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", latestSequence, receivedMessage->seq);  
        // Check for duplicate sequence numbers
        if (latestSequence <= receivedMessage->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate detected. Dropping packet from source %d with sequence %d\n", 
                receivedMessage->src, receivedMessage->seq);
            return msg;
        }

        call List.insert(receivedMessage->src, receivedMessage->seq);

        // Check if I am the destination!!!
        // Hello... is it me you're looking for?
        if (receivedMessage->dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "I received a message from %d. The message states: %s\n",
                receivedMessage->src, receivedMessage->payload);
            return msg;
        }
        
        latestSequence = call List.get(receivedMessage->src);  
        dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", latestSequence, receivedMessage->seq);  

        // Iterate sequence number
        receivedMessage->seq += 1;

        // Reflood using flood()
        call Flooding.flood(*receivedMessage);

        return msg;
    }
}