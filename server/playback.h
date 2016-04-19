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

#ifndef __PEEP_PLAYBACK_H__
#define __PEEP_PLAYBACK_H__

#define PLAYBACK_MAJOR_VER 1
#define PLAYBACK_MINOR_VER 1

#define MAX_PLAYBACK_EVENTS 3200

/* Time to sleep before exiting after trailing event */
#define PLAYBACK_TRAIL_TIME 5

/* For time definitions */
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

struct playback_h {
  char major_ver;          /* version of the playback format */
  char minor_ver;
  unsigned int max_events; /* number of events in the file */
  unsigned long written;   /* number of events written to the file */
  long start_pos;          /* position of the starting event */
  struct timeval start_t;  /* start time of the recording */
  struct timeval end_t;    /* last time recorded */
};

/* Format is:
 * "<day of week> <month> <day of month> <24 hr>:<min>:<sec> <year>"
 */
#define PLAYBACK_TIME_FORMAT "%a %b %d %H:%M:%S %Y"

/* For the meaning of an EVENT type */
#include "engine.h"

/* The playback record includes the event with the mix-in time filled
 * in so we can determine when to play back an event
 */
typedef struct {
  ENGINE_EVENT record;
} playback_t;

typedef enum mode
{ PLAY_MODE, RECORD_MODE }
playback_mode_t;

/**********************************************************************
 * API for interfacing with the playback datastructures
 **********************************************************************/

/* Sets the playback mode to the boolean value of t if t is non-
 * null and always returns the current playback value
 */
int playbackModeOn(int *t);

/* If m is a non-null pointer, sets the playback mode (play or record)
 * and always returns the current mode
 */
playback_mode_t playbackSetMode(playback_mode_t *m);

/* Initialize the playback routines to use the given file */
int playbackFileInit (char *file);

/* Write out an event into the recording file */
int playbackRecordEvent (ENGINE_EVENT e);

/* Read the events from the playback file. User can optionally specify
 * the starting and ending time to listen to. If these aren't specified,
 * i.e start_t == NULL || end_t == NULL, then playback starts at the
 * earliest event in the file, which should be pointed at in the file
 * stream by the time this function is called
 */
void playbackGo (char *start_t, char *end_t);

/* Close the playback file and write out the header if in record mode.
 * Also print statistics on the number of sounds heard
 */
int playbackFileShutdown (void);

/**********************************************************************
 * Internal functions
 **********************************************************************/

/* Figure out which event is the starting event in the round-robin
 * event file because events have incremental times
 */
long playbackFindFirstOffset (void);

/* Finds a time within the playback file from a given stating
 * position
 */
long playbackFindTime (struct timeval t, long start_pos);

#endif
