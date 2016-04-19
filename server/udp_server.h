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

#ifndef __PEEP_UDP_SERVER_H__
#define __PEEP_UDP_SERVER_H__

/* load the server definitions here to be sure */
#include "server.h"

/**********************************************************
 * Define the interface functions
 **********************************************************/

/* Initializes the server routines, sets up the server
 * socket for communication, and calls the broadcast
 * routines
 */
int serverRealInit (void);

/* Starts the main server loop of listening for connections
 * and incoming packets
 */
void serverRealStart (void);

/* Clean up after the server datastructures */
void serverRealShutdown (void);

/***********************************************************
 * End of the interface functions
 ***********************************************************/

#define MAX_UDP_PACKET_SIZE 512

/* For UDP leasing */
#define PROT_SERVER_LEASE_MIN 5
#define PROT_SERVER_LEASE_SEC 0
#define PROT_SERVER_WAKEUP_MIN 4
#define PROT_SERVER_WAKEUP_SEC 30
#define PROT_WAKEUPS_BEFORE_EXPIRED 2

/* Extra protocol constants */
#define PROT_SERVER_STILL_ALIVE (1 << 3)
#define PROT_CLIENT_STILL_ALIVE (1 << 4)

/* Extra content constants */
#define PROT_CONTENT_LEASE    (1 << 4)

/* Peep leasing is a very low resolution leasing and is not meant to be
 * used for long periods of time. After lease time has expired, the
 * information associated with the broadcast should be considered
 * obsolete
 */
struct lease {
  unsigned char min;
  unsigned char sec;
};

/* We need this header for struct in_addr */
#include <netinet/in.h>

/* The entry in the linked list database of active clients */
struct leaselist {
  struct in_addr host;       /* The ip address of the active host */
  unsigned int port;         /* The port to address the host with */
  struct timeval expired;    /* The time remaining at which this has expired */
  struct leaselist *nextent; /* The next entry in the list */
};

/* Definition for body of a packet whose sole purpose is to send
 * leasing information
 */
typedef struct {
  struct lease lease;
} LEASE_BODY;

/* Breaks up a client broadcast string and extracts the info
 * into the appropriate datastructures */
void serverProcessBC (MSG_STRING id_string, int id_len,
                      struct sockaddr_in *from);

/* Processes a client still alive by updating the client lease
 * time in the lease list and sending the client a server still
 * alive.
 */
void serverProcessClientAlive (void *data, int len, struct sockaddr_in *from);

/* Creats a server still alive packet containing the leasing info
 * and sends it to the client whose address uses the given host
 * and port structures.
 */
int serverNotifyClientLease (struct in_addr host, unsigned int port);

/* Updates the lease time for a client within the server host list */
int serverUpdateClient (struct sockaddr_in *from);

/* Adds a client and creates a new lease time within the server's
 * autodiscovery and leasing host list */
int serverAddClient (struct in_addr newhost, unsigned int hostport);

/* Attempts to find a lease for a given client in the lease list.
 * Returns the entry if found, otherwise NULL.
 */
struct leaselist *serverFindLeaseEntry (struct in_addr *host,
                                        unsigned int port);

/* Creates a new entry in the lease list for the given client
 * and returns a pointer to the entry.
 */
struct leaselist *serverAddLeaseEntry (struct in_addr *host,
                                       unsigned int port);

/* Function to remove expired hosts from the list. Should only occur
 * when a warning alarm has gone off */
void serverPurgeHostList (void);

/* Lets all the clients know we're still alive so our lease doesn't expire */
void serverSendStillAlive (void);

/* Handles an alarm signal, which allows an extra thread to run
 * concurrently and clean up the server host list at given
 * intervals */
void serverHandleAlarm ();

#endif
