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

#ifdef WITH_UDP_SERVER

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
#include <signal.h>
#include "udp_server.h"
#include "thread.h"
#include "debug.h"

/* server descriptors */
static struct hostent *host;      /* host info */
static struct in_addr *host_node; /* Pointer to host info */
static int server_fd;             /* copy of broadcast desc. */
static char *data_buffer = NULL;  /* For packet reception */

/* For keeping track of leasing */
static struct leaselist *hlhead = NULL;

/* Initialize to the local hostname */
char localhost[PROT_MAX_HOSTNAME];

int serverRealInit (void)
{

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR, "Initializing UDP server routines...\n");
#endif

    if (gethostname (localhost, PROT_MAX_HOSTNAME) < 0) {

        logMsg (DBG_GEN, "Uh Oh! Couldn't get my hostname: %s\n",
                strerror (errno));
        return SERVER_FAILURE;

    }

    if ((host = gethostbyname (localhost)) == NULL) {

        logMsg (DBG_GEN, "Uh Oh! Peep couldn't get local host information: %s\n",
                strerror (errno));
        return SERVER_FAILURE;

    }

    host_node = (struct in_addr *)host->h_addr;

    if ((server_fd = initializeBroadcast ()) < 0) {
        return SERVER_FAILURE;
    }

    /* Set the alarm signal handler and schedule an alarm */
    signal (SIGALRM, serverHandleAlarm);
    alarm (PROT_SERVER_WAKEUP_MIN * 60 + PROT_SERVER_WAKEUP_SEC);

    return SERVER_SUCCESS;

}

void serverRealStart (void)
{

    struct sockaddr_in from;
    PACKET msg;
    fd_set read_set;
    unsigned long from_len;
    int size_recv = 0;

    data_buffer = malloc (MAX_UDP_PACKET_SIZE * sizeof (char));

    logMsg (DBG_DEF, "%s | using INET address %s:%d\n", localhost,
            inet_ntoa (*host_node), serverGetPort ());

    /* start connections loop */
    while (1) {

        /* Initialize select file descriptors */
        FD_ZERO (&read_set);
        FD_SET (server_fd, &read_set);

        select (server_fd + 1, &read_set, NULL, NULL, NULL);

        /* Set the size for our recvfrom call */
        from_len = sizeof (struct sockaddr_in);

        /* Receive the header */
        size_recv = recvfrom (server_fd, data_buffer, MAX_UDP_PACKET_SIZE, 0,
                              (struct sockaddr *)&from, (socklen_t *)&from_len);

        if (size_recv == -1 && errno == ECONNREFUSED) {

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Server got connection refused. UDP packet did not reach its destination.\n");
            logMsg (DBG_SRVR, "\n");
#endif
            continue;

        }

#if DEBUG_LEVEL & DBG_SRVR
        logMsg (DBG_SRVR, "Server received a packet from: [%s], size: [%d]\n",
                inet_ntoa (from.sin_addr), size_recv);
#endif

        /* Move the data_buffer into the packet data structure */
        memcpy (&msg.header, data_buffer, sizeof (HEADER));

        /* Swap byte order between network and host */
        msg.header.magic = ntohl (msg.header.magic);
        msg.header.len   = ntohl (msg.header.len);

        /* Print out packet header */
#if DEBUG_LEVEL & DBG_SRVR
        logMsg (DBG_SRVR, "Packet header:\n");
        logMsg (DBG_SRVR, "\tversion: [%d]\n", msg.header.version);
        logMsg (DBG_SRVR, "\ttype:    [%d]\n", msg.header.type);
        logMsg (DBG_SRVR, "\tcontent: [%d]\n", msg.header.content);
        logMsg (DBG_SRVR, "\tmagic:   [0x%x]\n", msg.header.magic);
        logMsg (DBG_SRVR, "\tlen:     [%d]\n", msg.header.len);
#endif

        /* Check that the magic number is intact or discard */
        if (msg.header.magic != PROT_MAGIC_NUMBER) {

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Received packet with bad magic number. Discarding...\n");
#endif

            goto servletERR;

        }

        /* Process packet */
        switch (msg.header.type) {

        case PROT_BC_SERVER:

            msg.body = malloc (msg.header.len + 1);
            memcpy (msg.body, data_buffer + sizeof (HEADER), msg.header.len);

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Received broadcast from other server. Discarding...\n");
#endif
            break;

        case PROT_BC_CLIENT:

            msg.body = malloc (msg.header.len + 1);
            memcpy (msg.body, data_buffer + sizeof (HEADER), msg.header.len);
#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Received client broadcast packet.\n");
#endif
            serverProcessBC ((char *)msg.body, msg.header.len, &from);
            break;

        case PROT_SERVER_STILL_ALIVE:

            msg.body = malloc (msg.header.len);
            memcpy (msg.body, data_buffer + sizeof (HEADER), msg.header.len);

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Received still alive from other server. Discarding...\n");
#endif
            break;

        case PROT_CLIENT_STILL_ALIVE:
            msg.body = malloc (msg.header.len);
            memcpy (msg.body, data_buffer + sizeof (HEADER), msg.header.len);

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Apparently a client is still alive...\n");
#endif

            serverProcessClientAlive (msg.body, msg.header.len, &from);
            break;

        case PROT_CLIENT_EVENT:

            serverProcessClientEventPacket (&msg, data_buffer + sizeof (HEADER));
            continue; /* No need to free the body */

        default:

            msg.body = malloc (msg.header.len);
            memcpy (msg.body, data_buffer + sizeof (HEADER), msg.header.len);

#if DEBUG_LEVEL & DBG_SRVR
            logMsg (DBG_SRVR, "Received unsupported packet type. Discarding...\n");
#endif
            break;

        }

    servletERR:
        free (msg.body);

    }

}

void serverRealShutdown (void)
{

    struct leaselist *p = hlhead, *q = hlhead;

    if (data_buffer) {
        free (data_buffer);
    }

    /* The server socket gets closed in
     * server.c
     */

    /* Clean up the list of leases */
    while (p) {

        p = p->nextent;
        free (q);
        q = p;

    }

}

void serverProcessBC (MSG_STRING id_string, int id_len,
                      struct sockaddr_in *from)
{

    char delim = ((char *)PROT_CLASSDELIM)[0];
    char *p, *q;

    /* Ensure the string is null terminated at the given length */
    id_string[id_len] = '\0';

    /* Note: Perl pads strings with blank spaces. So let's check if we've
     * actually hit the end or just a blank space. We can also use strstr()
     * to find the class within our identifier since each classname will
     7 * be bounded by a "!"
    */
    for (p = id_string, q = id_string; *q != '\0' && !isspace (*q); q++) {

        if (*q == delim) {

            *q = '\0';

            /* Check if the string is part of our identifier */
            if (serverContainsIDClass (q)) {

                /* Then we are part of this class and should add the client */
                (void)serverAddClient (from->sin_addr, from->sin_port);
                break;

            }

        }

    }

}

void serverProcessClientAlive (void *data, int len,
                               struct sockaddr_in *from)
{

    /* Update the client lease */
    serverUpdateClient (from);

}

int serverUpdateClient (struct sockaddr_in *from)
{

    struct leaselist *p = NULL;
    struct timeval expired;

    if (from == NULL) {
        return SERVER_FAILURE;
    }

    for (p = hlhead; p; p = p->nextent) {

        if (from->sin_addr.s_addr == p->host.s_addr) {

            gettimeofday (&expired, NULL);
            expired.tv_sec += (PROT_SERVER_WAKEUP_MIN * 60 + PROT_SERVER_WAKEUP_SEC) *
                PROT_WAKEUPS_BEFORE_EXPIRED;
            expired.tv_usec = 0;  /* Adjust to appropriate resolution */
            p->expired = expired;
            break;

        }

    }

    return SERVER_SUCCESS;

}

int serverAddClient (struct in_addr host, unsigned int port)
{

    struct leaselist *lease = NULL;
    struct timeval expired;

    /* First search to see if we have an existing entry, so that
     * we don't add duplicates
     */
    if ((lease = serverFindLeaseEntry (&host, port)) == NULL) {
        lease = serverAddLeaseEntry (&host, port);
    }
    else {

#if DEBUG_LEVEL & DBG_AUTO
        logMsg (DBG_AUTO, "AUTODISCOVERY: Attempted to add client at %s:%d but client already in hostlist.\n",
                inet_ntoa (host), port);
        logMsg (DBG_AUTO, "AUTODISCOVERY: Updating client expiration time...\n");
#endif

    }

    /* Calculate the entry's expiry time */
    gettimeofday (&expired, NULL);
    expired.tv_sec += (PROT_SERVER_WAKEUP_MIN * 60 + PROT_SERVER_WAKEUP_SEC) *
        PROT_WAKEUPS_BEFORE_EXPIRED;
    expired.tv_usec = 0;  /* Adjust the resolution */
    lease->expired = expired;

    /* Now send the client directly a SERVER_STILL_ALIVE packet
     * so that it will add us to its lease list.
     * Note that we send the packet even though the host may
     * already by in the list. This is to tell the clients that
     * may have done a quick resstart to readd the server.
     */
    (void)serverRespondToClient (lease->host, lease->port);
    (void)serverNotifyClientLease (lease->host, lease->port);

#if DEBUG_LEVEL & DBG_AUTO
    logMsg (DBG_AUTO, "AUTODISCOVERY: Sent a response to the client\n");

    {
        int i = 0;
        struct leaselist *r;
        for (r = hlhead; r; r = r->nextent) {
            i++;
	}
        logMsg (DBG_AUTO, "AUTODISCOVERY: There are [%d] in the hostlist.\n", i);
    }
#endif

    return SERVER_SUCCESS;

}

int serverNotifyClientLease (struct in_addr host, unsigned int port)
{

    struct sockaddr_in client;
    HEADER header;
    LEASE_BODY body;
    char *buffer = NULL, *q = NULL;

    memset (&client, 0, sizeof (struct sockaddr_in));
    memset (&header, 0, sizeof (HEADER));
    memset (&body, 0, sizeof (LEASE_BODY));

    /* Prepare the client address */
    client.sin_family = AF_INET;
    client.sin_addr.s_addr = host.s_addr;
    client.sin_port = port;

    /* Prepare the header */
    header.version = PROT_VERSION;
    header.type = PROT_SERVER_STILL_ALIVE;
    header.content = PROT_CONTENT_LEASE;
    header.magic = htonl (PROT_MAGIC_NUMBER);
    header.len = sizeof (LEASE_BODY);

    body.lease.min = PROT_SERVER_LEASE_MIN;
    body.lease.sec = PROT_SERVER_LEASE_SEC;

    /* Allocate the buffer for the packet */
    if ((buffer = malloc (sizeof (HEADER) + header.len)) == NULL) {

        logMsg (DBG_GEN, "Error allocating server broadcast buffer: %s\n", strerror (errno));
        return SERVER_FAILURE;

    }

    /* Assemble the datagram into a single buffer for the sento call */
    q = buffer;
    memcpy (q, &header, sizeof (HEADER));
    q += sizeof (HEADER);
    memcpy (q, &body, sizeof (LEASE_BODY));

    if (sendto (server_fd, buffer, sizeof (HEADER) + sizeof (LEASE_BODY), 0,
                (struct sockaddr *)&client, sizeof (struct sockaddr_in)) < 0) {

        logMsg (DBG_SRVR, "Received an error responding to a client broadcast: %s\n", strerror (errno));
        free (buffer);
        return SERVER_FAILURE;

    }

    free (buffer);
    return SERVER_SUCCESS;

}

struct leaselist *serverFindLeaseEntry (struct in_addr *host, unsigned int port)
{

    struct leaselist *p = NULL;

    for (p = hlhead; p; p = p->nextent) {

        if (p->host.s_addr == host->s_addr && p->port == port) {
            return p;
	}

    }

    return NULL;

}

struct leaselist *serverAddLeaseEntry (struct in_addr *host, unsigned int port)
{

    struct leaselist *p = NULL;
    /* Now add the client if we're supposed to */

#if DEBUG_LEVEL & DBG_AUTO
    logMsg (DBG_AUTO, "AUTODISCOVERY: Adding client [%s]:[%d] to host list...\n",
            inet_ntoa (*host), port);
#endif

    if (hlhead == NULL) {

        hlhead = calloc (1, sizeof *hlhead);
        p = hlhead;

    }
    else {

        for (p = hlhead; p->nextent; p = p->nextent) {
            /* Search through the list */;
	}

        p->nextent = calloc (1, sizeof *(p->nextent));

        if ((p = p->nextent) == NULL) {
            return 0;
	}

    }

    p->host = *host;
    p->port = port;
    return p;

}

void serverPurgeHostList (void)
{

    struct leaselist *p = NULL, *q = NULL;
    struct timeval current;

#if DEBUG_LEVEL & DBG_AUTO
    int cnt = 0;

    {
        int i;
        for (i = 0, p = hlhead; p; p = p->nextent, i++);
        logMsg (DBG_AUTO, "AUTODISCOVERY: About to purge hostlist with [%d] entries.\n", i);
    }
#endif

    /* Get the current time of day for comparison */
    gettimeofday (&current, NULL);

    /* We write this as a while loop instead of a for loop to handle
     * the exception for p == hlhead
     */
    p = hlhead;
    q = NULL;
    while (p) {

        if (p->expired.tv_sec <= current.tv_sec) {

            if (p == hlhead) {

                p = p->nextent;
                free (hlhead);
                hlhead = p;

#if DEBUG_LEVEL & DBG_SRVR
                cnt++;
#endif
                continue;

            }
            else {

                q->nextent = p->nextent;
                free (p);

#if DEBUG_LEVEL & DBG_SRVR
                cnt++;
#endif

            }

        }

        q = p;
        p = p->nextent;

    }

#if DEBUG_LEVEL & DBG_AUTO
    logMsg (DBG_AUTO, "AUTODISCOVERY: Purged [%d] hosts from hostlist.\n", cnt);
#endif

}

void serverSendStillAlive (void)
{

    struct leaselist *p = NULL;
    struct sockaddr_in bc;
    HEADER header;
    LEASE_BODY body;
    char *buffer = NULL, *q = NULL;

    memset (&header, 0, sizeof (HEADER));
    memset (&body, 0, sizeof (LEASE_BODY));

    /* Assemble the header */
    header.version = PROT_VERSION;
    header.type = PROT_SERVER_STILL_ALIVE;
    header.content = PROT_CONTENT_LEASE;
    header.magic = htonl (PROT_MAGIC_NUMBER);
    header.len = sizeof (LEASE_BODY);

    /* Assemble the body */
    body.lease.min = PROT_SERVER_LEASE_MIN;
    body.lease.sec = PROT_SERVER_LEASE_SEC;

    if ((buffer = malloc (sizeof (HEADER) + sizeof (LEASE_BODY))) == NULL) {

        logMsg (DBG_GEN, "Error allocating buffer for still alive packet: %s\n", strerror (errno));
        return;

    }

    /* Copy the parts into the buffer */
    q = buffer;

    memcpy (q, &header, sizeof (HEADER));
    q += sizeof (HEADER);

    memcpy (q, &body, sizeof (LEASE_BODY));
    q += sizeof (LEASE_BODY);

    for (p = hlhead; p; p = p->nextent) {

        memset (&bc, 0, sizeof (bc));
        bc.sin_family = AF_INET;
        bc.sin_addr.s_addr = p->host.s_addr;
        bc.sin_port = p->port;

#if DEBUG_LEVEL & DBG_AUTO
        logMsg (DBG_AUTO, "AUTODISCOVERY: sending alive to: %s:%d\n",
                inet_ntoa (p->host), ntohs (p->port));
#endif

        sendto (server_fd, buffer, q - buffer, 0,
                (struct sockaddr *)&bc, sizeof (bc));

    }

    /* Free up the data buffer */
    free (buffer);

}

void serverHandleAlarm ()
{

#if DEBUG_LEVEL & DBG_AUTO
    logMsg (DBG_AUTO, "AUTODISCOVERY: Letting valid clients know we're still alive.\n");
#endif

    serverPurgeHostList ();
    serverSendStillAlive ();

    /* Reschedule the alarm */
    alarm (PROT_SERVER_WAKEUP_MIN * 60 + PROT_SERVER_WAKEUP_SEC);

}

#endif /* ifdef WITH_UDP_SERVER */
