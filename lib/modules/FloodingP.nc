#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingP {
   provides interface Flooding;
   uses interface AMSend;
   uses interface Packet;
   uses interface AMPacket;
   uses interface Timer<TMilli> as floodTimer;
   uses interface Receive;
}

implementation {
   bool busy = FALSE;
   message_t floodPkt;
   uint16_t lastSequenceNumber = 0;  // Used to track the last message seq

   command void Flooding.pass() {
       // Log when the pass command is called
       dbg(FLOODING_CHANNEL, "Node %d: Flooding.pass() called\n", TOS_NODE_ID);
   }

   // Command to initiate flooding
   command error_t Flooding.flood(pack *msg, uint16_t dest) {
       dbg(FLOODING_CHANNEL, "Node %d: Initiating flood with message seq %d\n", TOS_NODE_ID, msg->seq);

       if (!busy) {
           pack* payload = (pack*)(call Packet.getPayload(&floodPkt, sizeof(pack)));
           *payload = *msg;  // Copy the message to the packet

           dbg(FLOODING_CHANNEL, "Node %d: Sending flood message to dest %d\n", TOS_NODE_ID, dest);

           if (call AMSend.send(AM_BROADCAST_ADDR, &floodPkt, sizeof(pack)) == SUCCESS) {
               busy = TRUE;
               dbg(FLOODING_CHANNEL, "Node %d: Message sent successfully\n", TOS_NODE_ID);
               return SUCCESS;
           } else {
               dbg(FLOODING_CHANNEL, "Node %d: Failed to send message, radio busy or other error\n", TOS_NODE_ID);
               return FAIL;
           }
       } else {
           dbg(FLOODING_CHANNEL, "Node %d: Radio busy, cannot send message\n", TOS_NODE_ID);
           return EBUSY;
       }
   }

   // Event when message sending is done
   event void AMSend.sendDone(message_t* msg, error_t error) {
       if (&floodPkt == msg) {
           busy = FALSE;

           if (error == SUCCESS) {
               dbg(FLOODING_CHANNEL, "Node %d: Flood message send done successfully\n", TOS_NODE_ID);
           } else {
               dbg(FLOODING_CHANNEL, "Node %d: Error in message sending: %d\n", TOS_NODE_ID, error);
           }
       }
   }

   // Handle received packets and re-flood them
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
       pack* receivedMsg = (pack*)payload;

       dbg(FLOODING_CHANNEL, "Node %d: Received message with seq %d\n", TOS_NODE_ID, receivedMsg->seq);

       // Use `seq` instead of `sequenceNumber`
       if (receivedMsg->seq != lastSequenceNumber) {
           lastSequenceNumber = receivedMsg->seq;
           dbg(FLOODING_CHANNEL, "Node %d: Forwarding message with seq %d\n", TOS_NODE_ID, receivedMsg->seq);
           call Flooding.flood(receivedMsg, AM_BROADCAST_ADDR);  // Re-flood the message
       } else {
           dbg(FLOODING_CHANNEL, "Node %d: Duplicate message with seq %d, ignoring\n", TOS_NODE_ID, receivedMsg->seq);
       }

       return msg;
   }

   // Timer event for periodic actions
   event void floodTimer.fired() {
       dbg(FLOODING_CHANNEL, "Node %d: Flood timer fired\n", TOS_NODE_ID);
   }
}