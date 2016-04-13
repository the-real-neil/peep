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

#ifndef __PEEP_TCP_SERVER_H__
#define __PEEP_TCP_SERVER_H__

/* load the server definitions here to be sure */
#include "server.h"

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

/* Initializes the server socket. Returns 1 if successful, 0
 * otherwise
 */
int serverInitSocket (void);

struct servlet_data {
	int fd;                    /* client file descriptor */
	struct sockaddr_in client; /* client address */
};

/* A threaded servlet function that servers TCP client connections */
void *serverServlet (void *thread_data);

#endif
