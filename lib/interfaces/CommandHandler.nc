interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void flood(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t port);
   event void setTestClient(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint16_t transfer);
   event void closeTestClient(uint8_t srcPort, uint16_t dest, uint8_t destPort);
   event void setAppServer();
   event void setAppClient();
   event void sayHello(uint8_t port, uint8_t *username);
   event void broadcastMessage(uint8_t *message);
   event void unicastMessage(uint8_t *username, uint8_t *message);
   event void printUsers();
}
