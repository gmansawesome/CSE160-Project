#include "../../includes/packet.h"

interface Flooding {
    command error_t flood(pack *msg, uint16_t dest);
   command void pass();  // Add the pass command here if needed
}