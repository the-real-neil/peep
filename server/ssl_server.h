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

#ifndef __PEEP_SSL_SERVER_H__
#define __PEEP_SSL_SERVER_H__

/* Include this for basic server definitions */
#include "server.h"

#ifndef PEEPD_SHARED
#define PEEPD_SHARED "./"
#endif
#ifndef CERTIFICATE_PATH
#define CERTIFICATE_PATH PEEPD_SHARED "peepd-cert.pem"
#endif
#ifndef KEY_PATH
#define KEY_PATH PEEPD_SHARED "peepd-cert.pem"
#endif

/* SSL includes for declarations */
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

struct servlet_data {
	SSL *ssl;                  /* pointer to SSL object */
	struct sockaddr_in client; /* client address */
};

/* Initialize the server routines, sets up SSL sockets
 * for communication, and calls the broadcast routines.
 */
int serverRealInit (void);

/* Initializes the ssl server compoennts and opens a server
 * socket
 */
int sslServerInit (void);

int serverInitSocket (void);

/* Starts the main server loop of listening for connections
 * and incoming packets
 */
void serverRealStart (void);

/* Clean up after the server datastructures */
void serverRealShutdown (void);

SSL_CTX *serverInitCTX (void);
int serverLoadCerts (SSL_CTX *ctx, char *certf, char *keyf);
void serverLogCerts (SSL *ssl);
void *serverServlet (void *thread_data);

#endif /* __PEEP_SSL_SERVER_H__ */
