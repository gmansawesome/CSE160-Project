#include "../../includes/packet.h"

interface Flooding{
   command void pass();

   command error_t flood(uint16_t destination, uint8_t *payload); 
}
