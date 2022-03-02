#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingP
{
	//Provides the SimpleSend interface in order to flood packets
	provides interface Flooding;
	//Uses the SimpleSend interface to forward recieved packet as broadcast
	uses interface SimpleSend as Sender;
	//Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;

	uses interface Packet;
   	uses interface AMPacket;
	//Uses the Queue interface to determine if packet recieved has been seen before
	uses interface List<pack> as KnownPacketsList;

	uses interface NeighborDiscovery;
}

implementation
{
	
	uint16_t seqNumber = 0;
	pack sendPackage;
	uint8_t * neighbors; //Maximum of 20 neighbors?
	
	// Prototypes
	void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);
	bool isInList(pack packet);
	error_t addToList(pack packet);

	//Broadcast packet
	command error_t Flooding.send(pack msg, uint16_t dest)
	{
		//Attempt to send the packet
		dbg(FLOODING_CHANNEL, "Sending from Flooding\n");
		msg.src = TOS_NODE_ID;
		msg.TTL = MAX_TTL;
		msg.seq = seqNumber++;
		msg.protocol = PROTOCOL_PING;
		

		if (call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS)
		{
			return SUCCESS;
		}
		return FAIL;
	}

	//Event signaled when a node recieves a packet
	event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len)
	{
		dbg(FLOODING_CHANNEL, "Packet Received in Flooding\n");
		// 1. CHECK IF WE SEEN IT BEFORE
		if (len == sizeof(pack)) {
			pack *contents = (pack *)payload;
			//If I am the original sender or have seen the packet before, drop it
			if ((contents->src == TOS_NODE_ID) || isInList(*contents))
			{
				dbg(FLOODING_CHANNEL, "Dropping packet.\n");
				return msg;
			}
			//Kill the packet if TTL is 0
			if (contents->TTL == 0){
			    // how to kill a packet
			    //do nothing
			}else {
			    	dbg(FLOODING_CHANNEL, "TTL: %d\n", contents-> TTL);
			    	return msg;
			}
			// CHECK IF THIS NODE IS DEST
			if(contents-> dest == TOS_NODE_ID){
				dbg(FLOODING_CHANNEL, "this is packet dest from : %d to %d\n",contents->src,contents->dest);
				if(contents->protocol == PROTOCOL_PING){
					// WE NEED PING REPLY
					 makePack(&sendPackage, contents->dest, contents->src, contents->TTL-1,  contents->seq, PROTOCOL_PINGREPLY, 
					 	(uint8_t *)contnets->payload, sizeof(contents->payload));
             				call Sender.send(sendPackage, AM_BROADCAST_ADDR);
					
				}
			}

		}	
