/*
PEEP: The Network Auralizer
Copyright (C) 2000 Michael Gilfix

This file is part of PEEP.

You should have received a file COPYING containing license terms
along with this program; if not, write to Michael Gilfix
(mgilfix@eecs.tufts.edu) for a copy.

This version of PEEP is open source; you can redistribute it and/or
modify it under the terms listed in the file COPYING.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

#ifndef __PEEP_SERVER_H__
#define __PEEP_SERVER_H__

/* Protocol constants */
#define PROT_VERSION     2

/* Packet types */
#define PROT_UNDEFINED    0
#define PROT_BC_SERVER    (1 << 0)
#define PROT_BC_CLIENT    (1 << 1)
#define PROT_CLIENT_EVENT (1 << 2)

/* Content types */
#define PROT_CONTENT_UNDEFINED 0
#define PROT_CONTENT_XML   (1 << 0)
#define PROT_CONTENT_EVENT (1 << 1)
#define PROT_CONTENT_MSG   (1 << 2)

#define PROT_CLASSDELIM  "!"
#define PROT_MAGIC_NUMBER 0xDEADBEEF

#define PROT_MAX_ZONES 16
#define PROT_LISTEN_QUEUE 10

/* The man pages tell us we should be safe with 255 */
#define PROT_MAX_HOSTNAME 255

/* Includes for packet definitions */
#include <netinet/in.h>

/* Peep protocol packet */
typedef struct {
	unsigned char version; /* major protocol version */
	unsigned char type;    /* type of packet */
	unsigned char content; /* contents format */
	char reserved[5];      /* reserved */
	int magic;             /* magic number for checking */
	int len;               /* length of the contents */
} HEADER;

/* Holder structure for the packet */
typedef struct {
	HEADER header;         /* packet header */
	void *body;            /* body of the actual message */
} PACKET;

/* For event definition */
#include "engine.h"

/* PACKET body types */
typedef char * XML_BUFFER;
typedef EVENT EVENT_BODY;
typedef char * MSG_STRING;

struct hostlist {
	struct in_addr host;      /* the ip address of the host */
	unsigned int port;        /* port address to use when addressing the host */
	struct hostlist *nextent; /* next entry in list */
};

typedef struct broadcast {
	int port;
	struct broadcast *next;
} BROADCAST;

#define MAX_UDP_PACKET_SIZE 512

#define SERVER_SUCCESS 1
#define SERVER_FAILURE -1
#define SERVER_ALLOC_FAILED -2
#define SERVER_NOT_YET_ALLOC -3

/**********************************************************************
 * External Functions
 **********************************************************************/

/* Set the server port. Should be called *before* serverInit () */
void serverSetPort (int p);

/* Gets the server port */
int serverGetPort (void);

/* Tell the server about a new broadcast port to notify upon
 * server start up
 */
int serverAddBroadcastPort (int port);

/* Adds a class to the identifier string and concatenates the
 * delimiter
 */
int serverAddIDClass (char *class);

/* Returns true if the class is within the identifier string,
 * else false
 */
int serverContainsIDClass (char *class);

/* Returns a pointer to the ID class */
char *serverGetIDString (void);

/**********************************************************************
 * Interface to modular server code
 **********************************************************************/

/* Initializes the underlying server routine and calls the function
 * int serverRealInit (void); within the server module. Returns
 * SERVER_SUCCESS upon success or < 0 for failure
 */
int serverInit (void);

/* Calls the underlying server routine void serverStart (void); to
 * start the main server loop of listening for connections and
 * incoming packets
 */
void serverStart (void);

/* Cleans up and shuts down the server code. This cleans up after
 * all static variables in server.c and calls the underlying server
 * module function void serverRealShutdown (void); to shutdown
 * the server module
 */
void serverShutdown (void);

/**********************************************************************
 * Common server functions
 **********************************************************************/

/* Initializes the udp broadcast port for the server. Returns
 * the positivie broadcast file descriptor upon success, or
 * SERVER_FAILURE
 */
int initializeBroadcast (void);

/* Converts a packet structure to a character buffer suitable
 * for transmission. Sets len to be the length of the newly
 * created buffer.
 */
char *createPacketBuffer (PACKET *packet, int *len);

/* Frees a buffer associated witha  packet structure */
void freePacketBuffer (char *buffer);

/* Receives a UDP broadcast packet from the file descriptor 'fd' */
void receiveUDPPacket (int fd);

/* Processes a client broadcast string */
void serverProcessClientBC (MSG_STRING id_string, int id_len,
							struct sockaddr_in *from);

/* Process a client packet */
void serverProcessClientEventPacket (PACKET *packet, void *data_buffer);

/* Process a client event */
void serverProcessClientEvent (int content, void *msg, int msg_len);

#include "notice.h"

/* Fills out the 'event' structure with the necessary attributes from
 * the notice structure.
 */
void serverConvertNoticeToEngineEvent (EVENT *event, NOTICE *notice);

/* Responds to a client broadcast */
void serverRespondToClient (struct in_addr newhost,
							unsigned int host_port);

/* Functions for TCP wrappers */

/* Returns 1 if the client found at the socket file descriptor
 * has tcp wrapper access to the server and 0 otherwise
 */
int serverVerifyTcpWrapperAccess (int fd);

#endif
