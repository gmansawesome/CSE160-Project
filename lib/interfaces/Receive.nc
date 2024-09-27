#ifndef RECEIVE_H
#define RECEIVE_H

interface Receive {
    event message_t* receive(message_t* msg, void* payload, uint8_t len);
}

#endif /* RECEIVE_H */