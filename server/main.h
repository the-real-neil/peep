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

#ifndef __PEEP_MAIN_H__
#define __PEEP_MAIN_H__

#define DEFAULT_PID_PATH "/var/run/peepd.pid"

/* Select the default sound device to use */
#ifdef __USING_ALSA__
  #define DEFAULT_SND_DEVICE NULL
#else
  #define DEFAULT_SND_DEVICE "/dev/audio"
#endif

/* Default to using the sound jack output instead of speakers
 * for suns and other such machines.
 */
#define DEFAULT_SND_JACK 2

/* Constants for initializing the mixer */
#define DEFAULT_MIXER_VOICES 16
#define PERCENT_STATE_SOUNDS ( (1.0) / (4.0) )

#define DEFAULT_RECORD_FILE "/var/log/peepd.log"

#define DEFAULT_PORT 2001

#define MIXER_THREAD_USLEEP 5000 /* 0.05 secs */

/* Prints the Peep greeting to the console */
void printGreeting (void);

/* For signal handling convenience */
typedef void (*sighandler_t)(int);

/* Registers the signal handlers */
void setSigHandlers (void);

/* Enters the mixing loop */
void *doMixing (void *data);

/* Loops to handle events that are added into the engine queue */
void *engineLoop (void *data);

/* Shuts down and cleans up the server */
void shutDown (void);

/* Signal handler for asynchronous shutdown and restart */
void handleSignal (int sig);

#endif
