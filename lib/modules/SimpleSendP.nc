#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

generic module SimpleSendP() {
    provides interface SimpleSend;

    uses interface Queue<sendInfo*>;
    uses interface Pool<sendInfo>;

    uses interface Timer<TMilli> as sendTimer;

    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;

    uses interface Random;

    uses interface Flooding;
}

implementation {
    uint16_t sequenceNum = 0;
    bool busy = FALSE;
    message_t pkt;

    error_t send(uint16_t src, uint16_t dest, pack *message);

    // Use this to initiate a send task. We call this method so we can add
    // a delay between sends. If we don't add a delay there may be collisions.
    void postSendTask() {
        if (call sendTimer.isRunning() == FALSE) {
            dbg(GENERAL_CHANNEL, "Node %d: Starting send task with random delay\n", TOS_NODE_ID);
            call sendTimer.startOneShot((call Random.rand16() % 300));
        }
    }

    // Send wrapper with flooding integration
    command error_t SimpleSend.flood(pack msg) {
        dbg(FLOODING_CHANNEL, "Node %d: Flooding message with seq %d\n", TOS_NODE_ID, msg.seq);
        return call Flooding.flood(&msg, AM_BROADCAST_ADDR);  // Trigger flood
    }

    // This is a wrapper around the am sender, that adds queuing and delayed sending
    command error_t SimpleSend.send(pack msg, uint16_t dest) {
        dbg(GENERAL_CHANNEL, "Node %d: Attempting to send message with seq %d to %d\n", TOS_NODE_ID, msg.seq, dest);

        if (!call Pool.empty()) {
            sendInfo *input;

            input = call Pool.get();
            input->packet = msg;
            input->dest = dest;

            dbg(GENERAL_CHANNEL, "Node %d: Enqueuing message with seq %d for destination %d\n", TOS_NODE_ID, msg.seq, dest);

            call Queue.enqueue(input);

            // Start a send task which will be delayed.
            postSendTask();

            return SUCCESS;
        } else {
            dbg(GENERAL_CHANNEL, "Node %d: Pool is empty, unable to send message with seq %d\n", TOS_NODE_ID, msg.seq);
            return FAIL;
        }
    }

    task void sendBufferTask() {
        dbg(GENERAL_CHANNEL, "Node %d: Running send buffer task\n", TOS_NODE_ID);

        if (!call Queue.empty() && !busy) {
            sendInfo *info;
            info = call Queue.head();

            dbg(GENERAL_CHANNEL, "Node %d: Attempting to send queued message with seq %d to %d\n", TOS_NODE_ID, info->packet.seq, info->dest);

            if (SUCCESS == send(info->src, info->dest, &(info->packet))) {
                dbg(GENERAL_CHANNEL, "Node %d: Message with seq %d sent successfully\n", TOS_NODE_ID, info->packet.seq);

                call Queue.dequeue();
                call Pool.put(info);
            } else {
                dbg(GENERAL_CHANNEL, "Node %d: Failed to send message with seq %d, will retry\n", TOS_NODE_ID, info->packet.seq);
            }
        }

        // While the queue is not empty, keep rerunning this task.
        if (!call Queue.empty()) {
            postSendTask();
        }
    }

    // Once the timer fires, we post the sendBufferTask(). This allows
    // the OS's scheduler to attempt to send a packet at the next empty slot.
    event void sendTimer.fired() {
        dbg(GENERAL_CHANNEL, "Node %d: Timer fired, triggering sendBufferTask\n", TOS_NODE_ID);
        post sendBufferTask();
    }

    /*
     * Send a packet
     *
     * @param
     *   src - source address
     *   dest - destination address
     *   msg - payload to be sent
     *
     * @return
     *   error_t - Returns SUCCESS, EBUSY when the system is too busy using the radio, or FAIL.
     */
    error_t send(uint16_t src, uint16_t dest, pack *message) {
        if (!busy) {
            pack* msg = (pack *)(call Packet.getPayload(&pkt, sizeof(pack)));

            *msg = *message;

            dbg(GENERAL_CHANNEL, "Node %d: Sending packet with seq %d to %d\n", TOS_NODE_ID, message->seq, dest);

            if (call AMSend.send(dest, &pkt, sizeof(pack)) == SUCCESS) {
                busy = TRUE;
                return SUCCESS;
            } else {
                dbg(GENERAL_CHANNEL, "Node %d: AMSend failed, radio busy or other error\n", TOS_NODE_ID);
                return FAIL;
            }
        } else {
            dbg(GENERAL_CHANNEL, "Node %d: Cannot send, radio busy\n", TOS_NODE_ID);
            return EBUSY;
        }
    }

    // This event occurs once the message has finished sending. We can attempt
    // to send again at that point.
    event void AMSend.sendDone(message_t* msg, error_t error) {
        if (&pkt == msg) {
            busy = FALSE;

            if (error == SUCCESS) {
                dbg(GENERAL_CHANNEL, "Node %d: Message send completed successfully\n", TOS_NODE_ID);
            } else {
                dbg(GENERAL_CHANNEL, "Node %d: Error occurred while sending message: %d\n", TOS_NODE_ID, error);
            }

            postSendTask();  // Try to send next message in the queue
        }
    }
}