#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborDiscoveryP
{

	//Provides the SimpleSend interface in order to neighbor discover packets
	provides interface NeighborDiscovery;


	//Uses SimpleSend interface to forward recieved packet as broadcast
	uses interface SimpleSend as Sender;
	//Uses the Receive interface to determine if received packet is meant for me.
	uses interface Receive as Receiver;

	uses interface Packet;
	uses interface AMPacket;
	//Uses the Queue interface to determine if packet recieved has been seen before
	uses interface List<neighbor> as Neighborhood;
	uses interface Timer<TMilli> as periodicTimer;

}


implementation{
    
	pack sendPackage; 
	neighbor neighborHolder;
	uint16_t SEQ_NUM=200;
	uint8_t * temp = &SEQ_NUM;
	uint16_t i;
	uint16_t x;
	void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);

	bool isNeighbor(uint8_t nodeid);
	error_t addNeighbor(uint8_t nodeid);
	void updateNeighbors();
	void printNeighborhood();
	uint8_t neighborCount;
	uint8_t neighbors[19]; //Maximum of 20 neighbors?

 
 	command void NeighborDiscovery.run()
	{
		dbg(NEIGHBOR_CHANNEL, "NeighborDiscovery run().\n");
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM , PROTOCOL_PING, temp , PACKET_MAX_PAYLOAD_SIZE);
		SEQ_NUM++;
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
		neighborCount = 0;
		call periodicTimer.startPeriodic(1000);
	}

   	event void periodicTimer.fired(){
    
		dbg(NEIGHBOR_CHANNEL, "Sending from NeighborDiscovery\n");
		updateNeighbors();

		//optional - call a funsion to organize the list
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM , PROTOCOL_PING, temp , PACKET_MAX_PAYLOAD_SIZE);
		SEQ_NUM++;
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    	}

	command void NeighborDiscovery.print() {
		printNeighborhood();
	}

	event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len){
	
		if (len == sizeof(pack)){ 
			//check if there's an actual packet
			pack *contents = (pack*) payload;
			dbg(NEIGHBOR_CHANNEL, "NeighborReciver Called \n");

			if (contents->TTL != 0){

				if (PROTOCOL_PING == contents-> protocol){ 
					//got a ping
					dbg(NEIGHBOR_CHANNEL, "Node %d recieved packet with protocol Ping, sending reply back to node %d\n", TOS_NODE_ID, contents->src); 
					// send PROTOCOL_PINGREPLY
					makePack(&sendPackage, TOS_NODE_ID, contents->src , 1, contents->seq, PROTOCOL_PINGREPLY, contents->payload, PACKET_MAX_PAYLOAD_SIZE);
					call Sender.send(sendPackage,contents->src);
					return msg;
				}
				if (PROTOCOL_PINGREPLY == contents-> protocol){
					// add to neighbors
					dbg(NEIGHBOR_CHANNEL, "Node %d recieved protocol PingReply from node %d\n", TOS_NODE_ID, contents->src);
					if(!isNeighbor(contents -> src){
						addNeighbors(contents -> src);
						dbg(NEIGHBOR_CHANNEL, "Node %d added node %d to neigbors\n", TOS_NODE_ID, contents->src);
					}
					return msg;				
				}

			}


		}
	}
	

    
    
    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, 
            uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length){
                // implementation
                Package->src = src;
                Package->dest = dest;
                Package->TTL = TTL;
                Package->seq = seq;
                Package->protocol = protocol;
                memcpy(Package->payload, payload, length);
                
            }


	bool isNeighbor(uint8_t nodeid){
	
	    for( x=0; x < 19; x++){
			if(neighbors[x] == nodeid){
			    return TRUE;
            }
		}
		return FALSE;
	    
	}
	
	error_t addNeighbor(uint8_t nodeid){
		// implementation
		for( x=0; x < 19; x++) {
			if(neighbors[x] == NULL){
				neighbors[x] = nodeid;
				neighborCount++;
				if(!neighbors[x] == NULL){
					break;
				}
			}
		}
        }

	void updateNeighbors(){
	
		for( x=0; x < 19; x++) {
			neighbors[x] = NULL;
		}
	}
	
	void printNeighborhood(){
		// implementation
		for( x=0; x < 19; x++) {
			    if(neighbors[x] != NULL){
				 dbg(NEIGHBOR_CHANNEL, "NEIGHBOURS  of node  %d is :%d\n",TOS_NODE_ID, neighbors[x]);
			}
		}
	}
         
        
    } 
    
