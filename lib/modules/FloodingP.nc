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
        // Implement logic here, or leave it empty if pass doesn't require specific logic
    }
   // Command to initiate flooding
   command error_t Flooding.flood(pack *msg, uint16_t dest) {
       if (!busy) {
           pack* payload = (pack*)(call Packet.getPayload(&floodPkt, sizeof(pack)));
           *payload = *msg;  // Copy the message to the packet

           if (call AMSend.send(AM_BROADCAST_ADDR, &floodPkt, sizeof(pack)) == SUCCESS) {
               busy = TRUE;
               return SUCCESS;
           } else {
               return FAIL;
           }
       } else {
           return EBUSY;
       }
   }

   // Event when message sending is done
   event void AMSend.sendDone(message_t* msg, error_t error) {
       if (&floodPkt == msg) {
           busy = FALSE;
       }
   }

   // Handle received packets and re-flood them
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
       pack* receivedMsg = (pack*)payload;

       // Use `seq` instead of `sequenceNumber`
       if (receivedMsg->seq != lastSequenceNumber) {
           lastSequenceNumber = receivedMsg->seq;
           call Flooding.flood(receivedMsg, AM_BROADCAST_ADDR);  // Re-flood the message
       }

       return msg;
   }

   event void floodTimer.fired() {
       // Handle periodic flooding actions here
   }
}