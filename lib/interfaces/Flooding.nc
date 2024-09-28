#include "../../includes/packet.h"

interface Flooding{
   command error_t flood(uint8_t *payload, uint16_t destination);
   command void pass();
}