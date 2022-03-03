#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingP{
    
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

implementation{
	
	uint16_t seqNumber = 0;
	pack sendpackage;
	uint8_t * neighbors; //Maximum of 20 neighbors?
	
	// Prototypes
	void makePack(pack * package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);
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
	event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len){
	    
		dbg(FLOODING_CHANNEL, "Packet Received in Flooding\n");
		// CHECK 
		if (len == sizeof(pack)) {
			pack *contents = (pack *)payload;
			//If I am the original sender or have seen the packet before, drop it
			if ((contents->src == TOS_NODE_ID) || isInList(*contents)){
			    
				dbg(FLOODING_CHANNEL, "Dropping packet.\n");
				return msg;
			}
			//Kill the packet if TTL is 0
			if (contents->TTL == 0){
			    
			    	dbg(FLOODING_CHANNEL, "Dropping packet.\n");
				    return msg;
				    
			}else {
			    	dbg(FLOODING_CHANNEL, "TTL: %d\n", contents-> TTL);
			}
			// CHECK IF THIS NODE IS DEST
			if(contents-> dest == TOS_NODE_ID){
			    
				dbg(FLOODING_CHANNEL, "this = packet dest from : %d to %d\n", contents->src ,contents->dest);
				
				if(contents->protocol == PROTOCOL_PING){
					// WE NEED PING REPLY
					 makePack(&sendPackage, contents->dest, contents->src, contents->TTL-1,  contents->seq, PROTOCOL_PINGREPLY, 
						(uint8_t *)contents->payload, sizeof(contents->payload));
					    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
					    return msg;
                    
			    	}
			    
		        if(contents->protocol == PROTOCOL_PINGREPLY){
		            dbg(FLOODING_CHANNEL, "received a Ping_Reply from %d\n", contents->src);
		            return msg;
		        }
			    
			}else{
			    
			    if(contents-> dest == AM_BROADCAST_ADDR){
			        // Broadcast packet
                    if(contents->protocol == PROTOCOL_PING){
                        
                        dbg(GENERAL_CHANNEL,"NeighborDiscovery for %d\n",contents->src);
                        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, contents->TTL-1 , seqNumber, PROTOCOL_PINGREPLY, 
                                (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
                        call Sender.send(sendPackage, contents->src);
                        return msg;
                    }
        
                    if(contents->protocol == PROTOCOL_PINGREPLY){
                        
                        call NeighborDiscovery.neighborReceived(contents);
                        return msg;    
                    }
                    
			        return msg;
		    	}
		    	
			}
	    	
	    	return msg;


		}	
	}
	
	
void makePack(pack *package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol,  uint8_t* payload, uint8_t length){

	 package->src = src;
	 package->dest = dest;
	 package->TTL = TTL;
	 package->seq = seq;
	 package->protocol = protocol;
	 memcpy(package->payload, payload, length);
}  
	    
//Searches in known packet list
bool isInList(pack *packet){

	uint16_t size = call KnownPacketsList.size();
	uint16_t i = 0;
	pack temp;
	for(i = 0; i < size; i++) {
	  temp = call KnownPacketsList.get(i);
	  if(temp.src == packet->src && temp.dest == packet->dest && temp.seq == packet->seq) {
	    return TRUE;
	  }
	}
	return FALSE;
}

      void addToList(pack packet){
              if(call KnownPacketsList.isFull())
              { //check for List size. If it has reached the limit. #popfront
                call KnownPacketsList.popfront();
              }
              //Pushing Packet to PacketList
              call KnownPacketsList.pushback(packet);
            }
