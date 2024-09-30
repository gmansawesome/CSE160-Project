/**
 * ANDES Lab - University of California, Merced
 * This class provides a simple list.
 *
 * @author UCM ANDES Lab
 * @author Alex Beltran
 * @date   2013/09/03
 *
 */

generic module ListC(typedef t, int n){
	provides interface List<t>;
}

implementation{
	uint16_t MAX_SIZE = n;

	t container[n];
	uint16_t size = 0;

	command void List.pushback(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
		}
	}

	command void List.pushfront(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			int32_t i;
			// Shift everything to the right.
			for(i = size-1; i>=0; i--){
				container[i+1] = container[i];
			}

			container[0] = input;
			size++;
		}
	}

	command t List.popback(){
		t returnVal;

		returnVal = container[size];
		// We don't need to actually remove the value, we just need to decrement
		// the size.
		if(size > 0)size--;
		return returnVal;
	}

	command t List.popfront(){
		t returnVal;
		uint16_t i;

		returnVal = container[0];
		if(size>0){
			// Move everything to the left.
			for(i = 0; i<size-1; i++){
				container[i] = container[i+1];
			}
			size--;
		}

		return returnVal;
	}

	// This is similar to peek head.
	command t List.front(){
		return container[0];
	}

	// Peek tail
	command t List.back(){
		return container[size];
	}

	command bool List.isEmpty(){
		if(size == 0)
			return TRUE;
		else
			return FALSE;
	}

	command uint16_t List.size(){
		return size;
	}

	command t List.get(uint16_t position){
		return container[position];
	}

	command void List.insert(uint16_t position, t input) {
		int32_t i;

		dbg(FLOODING_CHANNEL, "Inserting...\n");
		//dbg(FLOODING_CHANNEL, "postition: %d, size: %d, max size: %d\n", position, size, MAX_SIZE);
		// Check if the position is within bounds and if there's room in the list
		if (position <= size && size <= MAX_SIZE) {
			//dbg(FLOODING_CHANNEL, "TRIGGER!\n");
			// Shift elements to the right to make room for the new element
			for (i = size; i > position; i--) {
				container[i] = container[i-1];
			}

			// Insert the input at the specified position
			container[position] = input;
			size++;  // Increase the size of the list
		}
	}
}
