#include "../../includes/packet.h"

interface Flooding{
   command void instantiateList();
   command void pass();
   command error_t flood(pack message); 
}
