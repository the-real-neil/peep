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

#ifndef __PEEP_NOTICE_H__
#define __PEEP_NOTICE_H__

/* For time definitions for notice data structures */
#if TIME_WITH_SYS_TIME
  #include <sys/time.h>
  #include <time.h>
#else
  #if HAVE_SYS_TIME_H
    #include <sys/time.h>
  #else
    #include <time.h>
  #endif
#endif
#include <unistd.h>

typedef struct {
  char *host;
  char *client;
  char *sound;
  char *data;
  int type;
  int location;
  int priority;
  int volume;
  int dither;
  int metric;
  int flags;
  struct tm date;
} NOTICE;

#define NOTICE_INTEGER_NOT_SET -1

#define NOTICE_TIME_FORMAT "%a %b %d %H:%M:%S %Z %Y"

/* Create a notice structure that will contain parsed XML */
NOTICE *noticeCreateNotice (void);

/* Create a string to store in the notice structure */
char *noticeCreateNoticeString (int len);

/* Destroys an allocated notice structure and any allocated
 * sub-components.
 */
void noticeFreeNoticeString (char *string);

/* Processes the XML event notice string passed along with a
 * client event and passes control to the event notice hook
 */
void processEventNoticeString (char *xml_string, NOTICE *notice);

/* For definitions */
#include "server.h"
#include "notice.h"

/* A code hook for arbitrary processing of the notice data
 * given with a client event
 */
void executeEventNoticeHook (MSG_STRING xml, NOTICE *notice);

/* Construct an XML snippet from a notice */
void serializeNotice (NOTICE *notice);

#endif
