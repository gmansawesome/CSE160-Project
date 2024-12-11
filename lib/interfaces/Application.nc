#include "../../includes/packet.h"

interface Application {
    command void hello(uint8_t port, uint8_t *username);
    command void broadMessage(uint8_t *message);
    command void uniMessage(uint8_t *username, uint8_t *message);
    command void printUsers();
}