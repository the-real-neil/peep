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
#include <sys/ioctl.h>
#include "server.h"
#include "debug.h"

static int broadcast_fd = 0;
static int port = 0;
static BROADCAST *broadcast_list = NULL;
static MSG_STRING identifier = NULL;

void serverSetPort (int p)
{

  port = p;

}

int serverGetPort (void)
{

  return port;

}

int serverAddBroadcastPort (int port)
{

  BROADCAST *cur_bc = NULL;

  if (broadcast_list == NULL) {

    if ((broadcast_list = malloc (sizeof *broadcast_list)) == NULL) {
      return SERVER_FAILURE;
    }

    memset (broadcast_list, 0, sizeof (BROADCAST));
    cur_bc = broadcast_list;

  } else {

    /* Loop through to the end of the list if a list exists */
    for (cur_bc = broadcast_list; cur_bc->next; cur_bc = cur_bc->next);

    if ((cur_bc->next = calloc (1, sizeof *(cur_bc->next))) == NULL) {
      return SERVER_FAILURE;
    }

    cur_bc = cur_bc->next;

  }

  cur_bc->port = port;

  return SERVER_SUCCESS;

}

int initializeBroadcast (void)
{

  struct protoent *prot;      /* entry from getprotobyname */
  struct sockaddr_in baddr;   /* socket addresses for server */
  int prot_no = 0;
  BROADCAST *cur_bc;

#if DEBUG_LEVEL & DBG_SRVR
  logMsg (DBG_SRVR, "Opening udp socket for initial broadcast...\n");
#endif

  if ((prot = getprotobyname ("udp")) == NULL) {

    logMsg (DBG_GEN, "Uh Oh! Error resolving protocl info for 'udp': %s\n",
            strerror (errno));
    return SERVER_FAILURE;

  }

  prot_no = prot->p_proto;

  if ((broadcast_fd = socket (AF_INET, SOCK_DGRAM, prot_no)) < 0) {

    logMsg (DBG_GEN, "Uh Oh! Couldn't open udp socket for broadcasting: %s\n",
            strerror (errno));
    return SERVER_FAILURE;

  }

  /* Let's set the SO_BROADCAST so we can send n' receive broadcasts */
  {
    int x = 1;

    if (setsockopt (broadcast_fd, SOL_SOCKET, SO_BROADCAST, &x,
                    sizeof (x)) == -1) {

      logMsg (DBG_GEN, "Uh Oh! Error setting socket options: %s\n", strerror (errno));
      return SERVER_FAILURE;

    }

  }

  {
    int x = 1;

    if (setsockopt (broadcast_fd, SOL_SOCKET, SO_REUSEADDR, &x,
                    sizeof (x)) == -1) {

      logMsg (DBG_GEN, "Uh Oh! Error setting socket options: %s\n", strerror (errno));
      return SERVER_FAILURE;

    }

  }

  memset (&baddr, 0, sizeof (struct sockaddr_in) );
  baddr.sin_family = AF_INET;
  baddr.sin_addr.s_addr = htonl (INADDR_ANY);
  baddr.sin_port = htons (port);

  if (bind (broadcast_fd, (struct sockaddr *)&baddr,
            sizeof (struct sockaddr_in)) < 0) {

    logMsg (DBG_GEN, "Uh Oh! Couldn't bind to udp broadcast port: %s\n",
            strerror (errno));
    return SERVER_FAILURE;

  }

  /* Check to see if we set the identifier. If not, set it to a blank
   * string
   */
  if (identifier == NULL) {

    identifier = malloc (2 * sizeof (char));
    strcpy ((char *)identifier, "");
    logMsg (DBG_DEF, "\nWarning: Could not assemble a class identifier strings.\n");
    logMsg (DBG_DEF,
            "Check your classes in peep.conf. Using blank identifier instead.\n");

  }

  logMsg (DBG_DEF, "Server class identifier string: %s\n", identifier);

  for (cur_bc = broadcast_list; cur_bc; cur_bc = cur_bc->next) {

    struct sockaddr_in bc;
    PACKET outgoing;
    char *buffer = NULL;
    int buf_len = 0;

    memset (&bc, 0, sizeof (struct sockaddr_in));
    memset (&outgoing, 0, sizeof (PACKET));

    bc.sin_family = AF_INET;
    bc.sin_addr.s_addr = INADDR_BROADCAST;
    bc.sin_port = htons (cur_bc->port);

    /* Build the broadcast packet */
    outgoing.header.version = PROT_VERSION;
    outgoing.header.type = PROT_BC_SERVER;
    outgoing.header.content = PROT_CONTENT_MSG;
    outgoing.header.magic = htonl (PROT_MAGIC_NUMBER);

    outgoing.body = identifier;
    outgoing.header.len = htonl (strlen (outgoing.body));

    /* Now create the buffer */
    buffer = createPacketBuffer (&outgoing, &buf_len);

    if (sendto (broadcast_fd, buffer, buf_len, 0,
                (struct sockaddr *)&bc, sizeof (struct sockaddr_in)) < 0) {

      logMsg (DBG_GEN, "Warning: received a broadcast error message: %s\n",
              strerror (errno));
      /* Don't return. Let's try to continue */

    }

    freePacketBuffer (buffer);

    logMsg (DBG_DEF, "Broadcasting existence to port [%d].\n", cur_bc->port);

  }

  return broadcast_fd;

}

void receiveUDPPacket (int fd)
{

  char buffer[MAX_UDP_PACKET_SIZE];
  PACKET msg;
  struct sockaddr_in from;
  unsigned long int fromlen;
  int size_recv = 0;

  memset (&msg, 0, sizeof (PACKET));

  /* Set the size for our recvfrom call */
  fromlen = sizeof (struct sockaddr_in);

  size_recv = recvfrom (fd, buffer, MAX_UDP_PACKET_SIZE, 0,
                        (struct sockaddr *)&from,
                        (socklen_t *)&fromlen);

  if (size_recv == -1 && errno == ECONNREFUSED) {

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR,
            "Hmm, it seems a UDP packet did not reach its destination.\n");
    return;
#endif

  }

  /* Move the data_buffer into the packet data structure */
  memcpy (&msg.header, buffer, sizeof (HEADER));

  /* Swap byte order */
  msg.header.magic = ntohl (msg.header.magic);
  msg.header.len   = ntohl (msg.header.len);

  /* Check that the magic number is intact or discard */
  if (msg.header.magic != PROT_MAGIC_NUMBER) {

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR, "Received UDP packet with bad magic number. Discarding...\n");
#endif

    return;

  }

  /* Print out packet header */
#if DEBUG_LEVEL & DBG_SRVR
  logMsg (DBG_SRVR, "Packet header:\n");
  logMsg (DBG_SRVR, "\tversion: [%d]\n", msg.header.version);
  logMsg (DBG_SRVR, "\ttype:    [%d]\n", msg.header.type);
  logMsg (DBG_SRVR, "\tcontent: [%d]\n", msg.header.content);
  logMsg (DBG_SRVR, "\tmagic:   [0x%x]\n", msg.header.magic);
  logMsg (DBG_SRVR, "\tlen:     [%d]\n", msg.header.len);
#endif

  switch (msg.header.type) {

  case PROT_BC_SERVER:

    /* Do nothing */
    break;

  case PROT_BC_CLIENT:

    msg.body = malloc (msg.header.len + 1);
    memcpy (msg.body, buffer + sizeof (HEADER), msg.header.len);
    ((char *)msg.body)[msg.header.len] = '\0';

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR, "Received client broadcast packet.\n");
#endif

    serverProcessClientBC ((MSG_STRING)msg.body, msg.header.len, &from);
    break;

  default:

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR,
            "Received unsupported packet type from broadcast. Discarding...\n");
#endif
    break;

  }

udpERR:
  free (msg.body);

}

void serverProcessClientBC (MSG_STRING id_string, int id_len,
                            struct sockaddr_in *from)
{

  char delim = ((char *)PROT_CLASSDELIM)[0];
  char *p, *q;

  /* Ensure the string is null terminated at the given length */
  id_string[id_len] = '\0';

  /* Note: Perl pads strings with blank spaces. So let's check if we've
   * actually hit the end or just a blank space. We can also use strstr()
   * to find the class within our identifier since each classname will
   * be bounded by a "!"
   */
  for (p = id_string, q = id_string; *q != '\0' && !isspace (*q); q++) {

    if (*q == delim) {

      *q = '\0';

      /* Check if the string is part of our identifier */
      if (serverContainsIDClass (q)) {

        /* Then we are part of this class and should add the client */
        serverRespondToClient (from->sin_addr, from->sin_port);
        break;

      }

    }

  }

}

void serverProcessClientEventPacket (PACKET *packet, void *data_buffer)
{

  HEADER *header = &(packet->header);
  EVENT *event = NULL;

  switch (header->content) {

  case PROT_CONTENT_XML:

    packet->body = data_buffer;
    serverProcessClientEvent (header->content, packet->body, header->len);
    break;

  case PROT_CONTENT_EVENT:

    packet->body = malloc (sizeof (EVENT_BODY));
    memcpy (packet->body, data_buffer, sizeof (EVENT_BODY) - sizeof (char *));
    event = (EVENT *)packet->body;

    /* convert integers from network byte order */
    event->flags = ntohl (event->flags);
    event->sound_len = ntohl (event->sound_len);

    /* Copy over the sound string.
     * This string will get freed later when we're done with the sound event
     * in the engineLoop. Not the most elegant but at least it's documented.
     * Will have to revisit later.
     */
    event->sound = malloc ((event->sound_len + 1) * sizeof (char));
    memcpy (event->sound, data_buffer + sizeof (EVENT_BODY) - sizeof (char *),
            event->sound_len);
    event->sound[event->sound_len] = '\0';

    serverProcessClientEvent (header->content, (void *)event, header->len);

    /* free (event->sound); */
    free (packet->body);
    packet->body = NULL;
    break;

  }

}

void serverProcessClientEvent (int content, void *msg, int msg_len)
{

  EVENT *event = NULL;
  NOTICE *notice = NULL;
  char *notice_string = NULL;

  switch (content) {

  case PROT_CONTENT_XML:

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR, "Got client event with XML content.\n");
#endif

    notice_string = malloc (msg_len + 1);
    notice = noticeCreateNotice ();

    /* Copy the notice string and null terminate it */
    memcpy (notice_string, msg, msg_len);
    notice_string[msg_len] = '\0';

    processEventNoticeString (notice_string, notice);

    free (notice_string);

    event = malloc (sizeof *event);
    serverConvertNoticeToEngineEvent (event, notice);
    engineEnqueue (*event);
    free (event);

    if (notice == NULL) {

#if DEBUG_LEVEL & DBG_SRVR
      logMsg (DBG_SRVR,
              "Error converting XML notice to engine event. Discarding...\n");
#endif

      noticeFreeNotice (notice);
      break;

    }

    /* Now execute the notice hook */
    executeEventNoticeHook ((MSG_STRING)msg, notice);
    noticeFreeNotice (notice);
    break;

  case PROT_CONTENT_EVENT:

#if DEBUG_LEVEL & DBG_SRVR
    logMsg (DBG_SRVR, "Got client event with ENGINE EVENT type content.\n");
#endif

    engineEnqueue (* (EVENT *)msg);
    break;

  }

}

void serverConvertNoticeToEngineEvent (EVENT *event, NOTICE *notice)
{


  /* If we get passed a NULL event or notice, do nothing */
  if (event == NULL || notice == NULL || notice->sound == NULL) {

    notice = NULL;
    return;

  }

  /* Extract the event parse from the notice */
  memset (event, 0, sizeof (EVENT));
  event->type      = notice->type;
  event->loc       = notice->location;
  event->prior     = notice->priority;
  event->vol       = notice->volume;
  event->dither    = notice->dither;

  memset (&event->reserved, 0, 2);
  event->flags     = notice->flags;
  event->sound_len = strlen (notice->sound);

  event->sound     = malloc (event->sound_len + 1);
  strcpy (event->sound, notice->sound);

}

char *createPacketBuffer (PACKET *packet, int *len)
{

  char *buffer = NULL;
  int length = 0;

  if (packet == NULL) {
    return NULL;
  }

  switch (packet->header.type) {

  case PROT_BC_SERVER:

    length = sizeof (HEADER) + strlen (packet->body) + 1;
    buffer = malloc (length);
    memcpy (buffer, &packet->header, sizeof (HEADER));
    strcpy (buffer + sizeof (HEADER), packet->body);

    if (len != NULL) {
      *len = length;
    }

    break;

  default:

    return NULL;

  }

  return buffer;

}

void freePacketBuffer (char *buffer)
{

  free (buffer);
  buffer = NULL;

}

int serverAddIDClass (char *class)
{

  if (!identifier) {

    if ((identifier = malloc (strlen (class) + strlen (PROT_CLASSDELIM) + 1)) ==
        NULL) {
      return SERVER_ALLOC_FAILED;
    }

    strcpy (identifier, class);

  } else {

    if ((identifier = realloc (identifier,
                               strlen (identifier) + strlen (class) + strlen (PROT_CLASSDELIM) + 1)) == NULL) {
      return SERVER_ALLOC_FAILED;
    }

    strcat (identifier, class);

  }

  /* Tack on the delimeter */
  strcat (identifier, PROT_CLASSDELIM);

  return SERVER_SUCCESS;

}

char *serverGetIDString (void)
{

  return identifier;

}

int serverContainsIDClass (char *class)
{

  char *myclass = malloc (strlen (class) + strlen (PROT_CLASSDELIM) + 1);
  int success = 0; /* start with failure */

  if (!identifier) {
    return 0;
  }

  sprintf (myclass, "%s%s", class, PROT_CLASSDELIM);

  if (strstr (identifier, myclass)) {
    success = SERVER_SUCCESS;
  }

  free (myclass);
  return success;

}

void serverRespondToClient (struct in_addr newhost, unsigned int host_port)
{

  struct sockaddr_in addr;
  PACKET outgoing;
  char *buffer = NULL;
  int buf_len = 0;

  memset (&addr, 0, sizeof (struct sockaddr_in));

  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = newhost.s_addr;
  addr.sin_port = host_port;

  /* Build the broadcast packet */
  outgoing.header.version = PROT_VERSION;
  outgoing.header.type = PROT_BC_SERVER;
  outgoing.header.content = PROT_CONTENT_MSG;
  outgoing.header.magic = htonl (PROT_MAGIC_NUMBER);

  outgoing.body = identifier;
  outgoing.header.len = htonl (strlen (outgoing.body));

  buffer = createPacketBuffer (&outgoing, &buf_len);

  if (sendto (broadcast_fd, buffer, buf_len, 0,
              (struct sockaddr *)&addr, sizeof (struct sockaddr_in)) < 0) {

    logMsg (DBG_GEN, "Warning: received a broadcast error message: %s\n",
            strerror (errno));
    /* Don't return. Let's try to continue */

  }

  freePacketBuffer (buffer);

#if DEBUG_LEVEL & DBG_SRVR
  logMsg (DBG_SRVR, "Sent response to client.\n");
#endif

}

int serverInit (void)
{

  return serverRealInit ();

}

void serverStart (void)
{

  serverRealStart ();

}

void serverShutdown (void)
{

  BROADCAST *p = NULL, *q = NULL;

  serverRealShutdown ();

  /* Free the broadcast list */
  for (p = broadcast_list; p; p = q) {

    q = p->next;
    free (p);

  }


  /* Clean up our identifier if we have one */
  if (identifier) {

    free (identifier);
    identifier = NULL;

  }

  /* Close server sockets */
  close (broadcast_fd);

}
