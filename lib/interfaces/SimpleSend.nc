#include "../../includes/packet.h"

interface SimpleSend{
   command error_t send(pack msg, uint16_t dest );
   command error_t flood(pack msg);  // Add this for flooding
}
