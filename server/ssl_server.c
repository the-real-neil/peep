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

#include "config.h"

#ifdef WITH_OPENSSL

#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include "ssl_server.h"
#include "thread.h"
#include "debug.h"

/* SSL socket descriptors */
static struct sockaddr_in saddr;  /* server address */
static struct hostent *host;      /* host info */
static struct in_addr *host_node;
static SSL_CTX *ctx;              /* global ssl context structure */
static int server_fd;             /* server file descriptor */
static int broadcast_fd;          /* copy of broadcast desc. */

/* Initialize to the local hostname */
char localhost[PROT_MAX_HOSTNAME];

int serverRealInit (void)
{

#if DEBUG_LEVEL & DBG_SRVR
	log (DBG_SRVR, "Initializing SSL server routines...\n");
#endif

	if (gethostname (localhost, PROT_MAX_HOSTNAME) < 0) {

		log (DBG_GEN, "Uh Oh! Couldn't get my hostname: %s\n", strerror (errno));
		return SERVER_FAILURE;

	}

	if ((host = gethostbyname (localhost)) == NULL) {

		log (DBG_GEN, "Uh Oh! Peep couldn't get local host information: %s\n", strerror (errno));
		return SERVER_FAILURE;

	}

	host_node = (struct in_addr *)host->h_addr;

	if (!sslServerInit ())
		return SERVER_FAILURE;

	if (!serverInitSocket ())
		return SERVER_FAILURE;

	if ((broadcast_fd = initializeBroadcast ()) < 0)
		return SERVER_FAILURE;

	return SERVER_SUCCESS;

}

int sslServerInit (void)
{

#if DEBUG_LEVEL & DBG_SRVR
	log (DBG_SRVR, "Initializing SSL socket...\n");
#endif

	/* Initialize the SSL routines */
	if ((ctx = serverInitCTX ()) == NULL) {

		log (DBG_GEN, "Uh Oh! Initializing SSL routines failed. Aborting...\n");
		return 0;

	}

/* XXX Fix cert handling later */
#if 0
	if (!serverLoadCerts (ctx, CERTIFICATE_PATH, KEY_PATH)) {

		log (DBG_GEN, "Uh Oh! Loading private key and public ceritficate failed. Aborting...\n");
		return 0;

	}
#endif

	return 1;

}

int serverInitSocket (void)
{

	/* Create the tcp socket for connections */
	if ((server_fd = socket (AF_INET, SOCK_STREAM, 0)) < 0) {

		log (DBG_GEN, "Uh Oh! Couldn't create server socket: %s\n", strerror (errno));
		return 0;

	}

	{

		int x = 1;

		if (setsockopt (server_fd, SOL_SOCKET, SO_REUSEADDR, &x,
						sizeof (x)) == -1) {

			log (DBG_GEN, "Uh Oh! Error setting socket options: %s\n", strerror (errno));
			return 0;

		}

	}

	/* Set non blocking flag so we don't wait on a false accept */
	if (fcntl (server_fd, F_SETFL, O_NONBLOCK) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting socket O_NONBLOCK option: %s\n", strerror (errno));
		return 0;

	}

	memset (&saddr, 0, sizeof (struct sockaddr_in));

	saddr.sin_family = AF_INET;
	saddr.sin_addr.s_addr = INADDR_ANY;
	saddr.sin_port = htons (serverGetPort ());

	if (bind (server_fd, (struct sockaddr *)&saddr, sizeof (struct sockaddr_in)) < 0) {

		log (DBG_GEN, "Uh Oh! Couldn't bind to socket: %s\n", strerror (errno));
		return 0;

	}

	if (listen (server_fd, PROT_LISTEN_QUEUE) < 0) {

		log (DBG_GEN, "Uh Oh! Couldn't setup listen queue: %s\n", strerror (errno));
		return 0;

	}

	return 1;

}

SSL_CTX *serverInitCTX (void)
{

	SSL_METHOD *meth = NULL;
	SSL_CTX *ctx = NULL;

	/* Initialize the SSL library */
	SSL_library_init ();

	/* Load the SSL error strings */
	SSL_load_error_strings ();

	/* Add in the SSL algorithms */
	SSLeay_add_ssl_algorithms ();

	/* Create new SSL context object */
	meth = SSLv23_server_method ();  /* Support for v.2 & 3 */
	if ((ctx = SSL_CTX_new (meth)) == NULL) {

		log (DBG_GEN, "Uh Oh! Couldn't create SSL context object: %s\n",
					  ERR_reason_error_string (ERR_get_error ()));
		return NULL;

	}

	return ctx;

}

int serverLoadCerts (SSL_CTX *ctx, char *certf, char *keyf)
{

	/* load the certificate file */
	if (SSL_CTX_use_certificate_file (ctx, certf, SSL_FILETYPE_PEM) <= 0) {

		log (DBG_GEN, "Uh Oh! Couldn't load certificate file %s: %s\n", certf,
					  ERR_reason_error_string (ERR_get_error () ));
		return 0;

	}

	/* load private key file */
	if (SSL_CTX_use_PrivateKey_file (ctx, keyf, SSL_FILETYPE_PEM) <= 0) {

		log (DBG_GEN, "Uh Oh! Couldn't load private key file %s: %s\n", keyf,
					  ERR_reason_error_string (ERR_get_error () ));
		return 0;

	}

	/* check the private key */
	if (!SSL_CTX_check_private_key (ctx) ) {

		log (DBG_GEN, "Uh Oh! Private key and public certificate do not match!\n");
		return 0;

	}

#if DEBUG_LEVEL & DBG_SRVR
	log (DBG_SRVR, "Loaded certificate from: [%s].\n", certf);
	log (DBG_SRVR, "Loaded private key from: [%s].\n", keyf);
#endif

	return 1;

}

void serverRealStart (void)
{

	struct sockaddr_in from;
	unsigned long from_len = 0;
	SSL *ssl;                /* SSL connection object */
	pthread_t client_thread; /* handler for creating client thread */
	fd_set read_set;         /* for use with select */
	int cli = 0, highest_fd = 0;

	/* For passing data to the servlets */
	struct servlet_data *data = NULL;

	log (DBG_DEF, "%s | using INET address %s:%d\n", localhost,
		 inet_ntoa (*host_node), serverGetPort ());

	highest_fd = (server_fd < broadcast_fd) ? broadcast_fd : server_fd;

	/* start connections loop */
	while (1) {

		/* Initialize select file descriptors */
		FD_ZERO (&read_set);
		FD_SET (server_fd, &read_set);
		FD_SET (broadcast_fd, &read_set);

		select (highest_fd + 1, &read_set, NULL, NULL, NULL);

		/* Check if we've gotten a packet on the braodcast line */
		if (FD_ISSET (broadcast_fd, &read_set))
			receiveUDPPacket (broadcast_fd);

		/* Check if we've got an incoming connection */
		if (FD_ISSET (server_fd, &read_set)) {

			from_len = sizeof (struct sockaddr_in);
			if ((cli = accept (server_fd, (struct sockaddr *)&from,
			                              (socklen_t *)&from_len)) < 0) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Error accepting client connection: %s\n",
				               strerror (errno));
#endif
				continue;

			}

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Received connection: %s:%d\n",
				 inet_ntoa (from.sin_addr), ntohs (from.sin_port));
#endif

			ssl = SSL_new (ctx);
			SSL_set_fd (ssl, cli);

			/* Perform the SSL part of the accept */
			if (SSL_accept (ssl) <= 0) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Error performing SSL handshake during accept: %s\n",
					 ERR_reason_error_string (ERR_get_error ()));
#endif
				close (cli);
				SSL_free (ssl);
				continue;

			}

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Client connection using cipher: %s\n", SSL_get_cipher (ssl));
			serverLogCerts (ssl);
#endif

			/* Start connection thread */
			data = (struct servlet_data *)malloc (sizeof (struct servlet_data));
			data->ssl = ssl;
			data->client = from;
			startThread (serverServlet, data, &client_thread);
			threadDetach (client_thread);

		}

	}

}

void serverLogCerts (SSL *ssl)
{

	X509 *certificate;
	char *str;

	certificate = SSL_get_peer_certificate (ssl);
	log (DBG_SRVR, "Client certificate:\n");

	if (certificate != NULL) {

		str = X509_NAME_oneline (X509_get_subject_name (certificate), 0, 0);
		log (DBG_SRVR, "\tsubject: %s\n", str);
		free (str);

		str = X509_NAME_oneline (X509_get_issuer_name (certificate), 0, 0);
		log (DBG_SRVR, "\tIssuer: %s\n", str);
		free (str);

		X509_free (certificate);
	}
	else
		log (DBG_SRVR, "\tNo certificate for the client was found.\n");

}

void *serverServlet (void *thread_data)
{

	PACKET msg;
	fd_set read_set;
	int size_recv = 0;
	SSL *ssl = ((struct servlet_data *)thread_data)->ssl;
	int fd = SSL_get_fd (ssl);
	struct sockaddr_in client = ((struct servlet_data *)thread_data)->client;

	free (thread_data);
	thread_data = NULL;

	/* Continously read events from client */
	while (1) {

		FD_ZERO (&read_set);
		FD_SET (fd, &read_set);

		select (fd + 1, &read_set, NULL, NULL, NULL);

		size_recv = SSL_read (ssl, &msg.header, sizeof (HEADER));

		if (size_recv < 0) {

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Error while reading from SSL socket: %s\n",
							ERR_reason_error_string (ERR_get_error () ));
#endif

			close (fd);
			SSL_free (ssl);
			return NULL;

		}
		else if (size_recv == 0) {

			/* The connection has been severed - i.e we polled something
			 * but read 0 data.
			 */
			close (fd);
			SSL_free (ssl);
			return NULL;

		}

		/* Swap byte order between network and host */
		msg.header.magic = ntohl (msg.header.magic);
		msg.header.len = ntohl (msg.header.len);

		/* Print out packet header */
#if DEBUG_LEVEL & DBG_SRVR
		log (DBG_SRVR, "Packet header:\n");
		log (DBG_SRVR, "\tversion: [%d]\n", msg.header.version);
		log (DBG_SRVR, "\ttype:    [%d]\n", msg.header.type);
		log (DBG_SRVR, "\tcontent: [%d]\n", msg.header.content);
		log (DBG_SRVR, "\tmagic:   [0x%x]\n", msg.header.magic);
		log (DBG_SRVR, "\tlen:     [%d]\n", msg.header.len);
#endif

		if (msg.header.magic != PROT_MAGIC_NUMBER)
			continue;

		/* Process packet */
		switch (msg.header.type) {

		case PROT_BC_CLIENT:

			msg.body = (void *)malloc(msg.header.len);
			size_recv = SSL_read (ssl, msg.body, msg.header.len);

			if (size_recv != msg.header.len) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Error while reading body of client broadcast packet: %s\n",
								ERR_reason_error_string (ERR_get_error () ));
#endif
				goto servletERR;

			}

			serverProcessClientBC ((MSG_STRING)msg.body, msg.header.len, &client);
			break;

		case PROT_CLIENT_EVENT:

			{
				char *buffer = (char *)malloc (msg.header.len);
				size_recv = SSL_read (ssl, msg.body, msg.header.len);

				if (size_recv != msg.header.len) {

#if DEBUG_LEVEL & DBG_SRVR
					log (DBG_SRVR, "Error while reading body of client event packet: %s\n",
									ERR_reason_error_string (ERR_get_error () ));
#endif
					goto servletERR;

				}

				serverProcessClientEventPacket (&msg, buffer);
				free (buffer);
			}

			continue; /* No need to free the body */

		case PROT_BC_SERVER:

			msg.body = (void *)malloc (msg.header.len);
			size_recv = SSL_read (ssl, msg.body, msg.header.len);

			if (!size_recv != msg.header.len) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Error while reading body of server broadcast packet: %s\n",
								ERR_reason_error_string (ERR_get_error () ));
#endif
				goto servletERR;

			}

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Received broadcast from other server. Discarding...\n");
#endif
			break;

		default:

			msg.body = (void *)malloc (msg.header.len);
			size_recv = SSL_read (ssl, msg.body, msg.header.len);

			if (!size_recv != msg.header.len) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Error while reading body of unsupported packet type: %s\n",
								ERR_reason_error_string (ERR_get_error () ));
#endif
				goto servletERR;

			}

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Received unsupported packet type. Discarding...\n");
#endif
			break;

		}

servletERR:
		free (msg.body);

	}

}

void serverRealShutdown (void)
{

	/* Close server socket */
	close (server_fd);
	SSL_CTX_free (ctx);

}

#endif
