/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Flooding;
   uses interface Neighbor;
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");

      dbg(GENERAL_CHANNEL, "Starting Neighbor Discovery\n");
      call Neighbor.start();  // Start neighbor discovery at boot time

   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
      if (len == sizeof(NeighborBeacon)) {
         NeighborBeacon* beacon = (NeighborBeacon*) payload;
         dbg(NEIGHBOR_CHANNEL, "Node %d: Received beacon from Node %d\n", TOS_NODE_ID, beacon->nodeID);
      } else {
         dbg(GENERAL_CHANNEL, "Received unknown packet length: %d\n", len);
      }
    // Check if the received packet is a regular pack
    if (len == sizeof(pack)) {
        pack* myMsg = (pack*) payload;

        dbg(GENERAL_CHANNEL, "Packet Received\n");
        dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);

        // Check if the packet is a neighbor discovery packet (you can set a special protocol value for neighbor discovery)
        if (myMsg->protocol == NEIGHBOR_DISCOVERY_PROTOCOL) {
            dbg(NEIGHBOR_CHANNEL, "Node %d: Neighbor discovery packet received\n", TOS_NODE_ID);
            
            // Handle neighbor discovery packet (pass src ID)
            Neighbor.addOrUpdateNeighbor(myMsg->src);  // Assuming myMsg->src contains the neighbor's node ID
        }

        return msg;
    }

    // Check if the received packet is a NeighborBeacon
    if (len == sizeof(NeighborBeacon)) {
        NeighborBeacon* beacon = (NeighborBeacon*) payload;

        dbg(NEIGHBOR_CHANNEL, "Node %d: Received beacon from Node %d\n", TOS_NODE_ID, beacon->nodeID);

        // Add or update the neighbor in the neighbor table
        Neighbor.addOrUpdateNeighbor(beacon->nodeID);

        return msg;
    }

    // If the packet type is unknown, log the length
    dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
    return msg;
}


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
