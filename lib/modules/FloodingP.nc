#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/floodingTable.h"

#define FLOOD_TIME_INTERVAL 10000 //100ms
#define INT_MAX 32767

module FloodingP{
    provides interface Flooding;
    uses interface Packet;
    uses interface Receive;
    uses interface SimpleSend;
    uses interface List<FloodingTable>;
    uses interface Timer<TMilli>;
    uses interface Boot;
    uses interface Routing;
}

implementation {
    event void Boot.booted() {
        uint8_t i;

        // Instantiate flooding cache on first iteration
        // dbg(FLOODING_CHANNEL, "Instantiating flooding cache...\n");
        for (i = 0; i < MAX_NODES; i++) {
            FloodingTable emptyFlood;
            emptyFlood.lastSeq = INT_MAX;
            emptyFlood.lastDest = 0;

            call List.pushback(emptyFlood);
        }

        call Timer.startPeriodic(FLOOD_TIME_INTERVAL);
    }

    event void Timer.fired() {
        uint8_t i;

        // clear flooding cache periodically
        for (i = 0; i < MAX_NODES; i++) {
            FloodingTable emptyFlood;
            emptyFlood.lastSeq = INT_MAX;
            emptyFlood.lastDest = 0;

            call List.replace(i, emptyFlood);
        }

        // dbg(FLOODING_CHANNEL, "FIRED\n");
    }

    command error_t Flooding.flood(pack msg) {
        error_t result;
        FloodingTable tempFlood;

        // logPack(&msg, FLOODING_CHANNEL);

        // Check if destination is sender
        if (msg.dest == TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "I received a message from %d. The message states: %s\n",
                msg.src, msg.payload);
            return result;
        }

        // Update flooding cache for flood source
        if (msg.src == TOS_NODE_ID) {
            tempFlood.lastSeq = msg.seq;
            tempFlood.lastDest = msg.dest;
            call List.replace(msg.src, tempFlood);
        }

        msg.seq++;
        msg.TTL--;

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
        FloodingTable tempFlood;

        // Cast the received payload to a packet structure
        pack* receivedMessage = (pack*)payload;

        dbg(FLOODING_CHANNEL, "Packet RECEIVED from flood source %d\n", receivedMessage->src);
        
        logPack(receivedMessage, FLOODING_CHANNEL);   

        // Check for end of TTL
        if (receivedMessage->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL reached. Dropping packet from flood source %d with sequence %d\n", receivedMessage->src, receivedMessage->seq);
            
            return msg;
        }

        tempFlood = call List.get(receivedMessage->src);
        
        // Check if new flood using Dest
        dbg(FLOODING_CHANNEL, "Latest Dest: %d, New Dest: %d\n", tempFlood.lastDest, receivedMessage->dest);  
        if (receivedMessage->dest > tempFlood.lastDest) {
            dbg(FLOODING_CHANNEL, "NEW FLOOD\n");  
            tempFlood.lastSeq = INT_MAX;
        }

        tempFlood.lastDest = receivedMessage->dest;

        // Check for duplicate sequence numbers
        dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", tempFlood.lastSeq, receivedMessage->seq);  
        if (tempFlood.lastSeq <= receivedMessage->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate detected. Dropping packet from flood source %d\n", receivedMessage->src);
            
            call List.replace(receivedMessage->src, tempFlood);
            return msg;
        }

        // Update flooding cache
        tempFlood.lastSeq = receivedMessage->seq;
        call List.replace(receivedMessage->src, tempFlood);

        // tempFlood = call List.get(receivedMessage->src);    
        // dbg(FLOODING_CHANNEL, "Latest Sequence: %d, New Sequence: %d\n", tempFlood.lastSeq, receivedMessage->seq);  

        // Check if Routing LSP
        if (receivedMessage->protocol == PROTOCOL_LINKSTATE) {
            if (receivedMessage->src == 1) {
                // dbg(ROUTING_CHANNEL, "I received a LSP from [%d] with offset %d\n", receivedMessage->src, receivedMessage->dest);
                // logPack(receivedMessage, ROUTING_CHANNEL);
            }

            call Routing.addNeighbors(receivedMessage->src, receivedMessage->payload);

            call Flooding.flood(*receivedMessage);

            return msg;
        }

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