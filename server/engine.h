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

#ifndef __PEEP_ENGINE_H__
#define __PEEP_ENGINE_H__

/* Include time definitions so we can use the u_char and clock_t
 * definitions
 */
#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif
#include <unistd.h>

typedef struct {
	unsigned char type;      /* state or single event */
	unsigned char loc;       /* stereo location (left - 0, right - 255) */
	unsigned char prior;     /* priority of the event */
	unsigned char vol;       /* volume of the event */
	unsigned char dither;    /* adjustable parameter for sound dithering
							  * 2 meanings:
							  *   1) Applies to states. sets the fade-in time
							  *      when mixing between state sounds
							  *   2) Applies delay to handle events which
							  *      occur in spurts - currently unimplemented
							  */
	char reserved[3];        /* reserved for future effects attributes */
	int flags;               /* effects flags */
	int sound_len;           /* Length of the sound string */
	char *sound;             /* sound to play, ref by name */
} EVENT;

typedef struct {
	EVENT event;
	struct timeval mix_time; /* time when an event was enqueued */
} ENGINE_EVENT;

typedef enum { EVENT_T, STATE_T } EVENT_TYPE;

struct engine_sched {
	double startt;    /* start times for each voicing */
	long priorit;     /* priority for currently playing sound */
	double minendt;   /* end time of the sound - currently unused */
};

#define ENGINE_SUCCESS 1
#define ENGINE_NOT_YET_ALLOC -1
#define ENGINE_ALLOC_FAILED -2
#define ENGINE_SOUND_NOT_FOUND -3
#define ENGINE_SOUND_EXISTS -4

#define EVENT_QUEUE_ENTRIES 64

/******************************************************************************
 * Sound table lookup functions
 ******************************************************************************/

#define HASHES                  256

typedef struct {
	short **snds;              /* array of event samples in mem */
	unsigned int *lens;        /* length of samples */
	unsigned int snd_cnt;      /* number of event sounds associated with an event */
} EVENT_ENTRY;

typedef struct {
	int mixer_index;           /* The index within the internal buffer of the mixer */
} STATE_ENTRY;

struct sound_entry {
	struct sound_entry *next;   /* Pointer to the next entry in the hash list */
	char *name;                 /* Name of the sound to look up */
	void *data;                 /* Pointer to the type of data. Depending on type,
	                             * this can be a pointer to a:
	                             *   EVENT_ENTRY, which contains the data
	                             *   associated with an event.
	                             *            or
	                             *   STATE_BUF, which contains the index of the
	                             *   mixer buffer that holds the states
	                             */
	EVENT_TYPE type;            /* Type of the event stored */
};

/* Allocate and create the sound table data structure */
int engineSoundTableInit (void);

/* Inserts an event entry into the sound table */
int engineSoundTableInsertEvent (char *name, EVENT_ENTRY *event);

/* Inserts a state entry into teh sound table */
int engineSoundTableInsertState (char *name, STATE_ENTRY *state);

/* Performs the actual insertion of the element into the hash table.
 * The element is a struct sound_entry, which provides a wrapper for
 * the EVENT_ENTRY and STATE_ENTRY structures
 */
int engineSoundTableInsert (struct sound_entry *entry);

/* Retrieves the sound entry from the hash table, referenced
 * by name.
 */
void *engineSoundTableRetrieve (char *name);

/* Retrieves the data field of the sound entry referenced by name.
 * The calling procedure should then cast the structure appropriately.
 */
void *engineSoundTableDataRetrieve (char *name);

/* Destroys and frees up the sound table data structure */
void engineSoundTableDestroy (void);

/* A simple hash function for turning names into indices */
int engineSoundHash (char *name);

/******************************************************************************
 * API to set engine data structures
 ******************************************************************************/

/* Initialize the engine. Parameters are a pointer to the device to use for
 * sound output, the snd port (applies to suns only), and the number of event
 * and state buffers to use for sound playback
 */
void engineInit (char *device, unsigned int snd_port,
				 unsigned int ebuf, unsigned int sbuf);

/* Initializing the scheduling data structures associated with a given
 * sound. Parameters are the start time of the sound, the priority of
 * the sound, and the minimum ending time of the sound (curently
 * not used).
 */
int engineSchedulerInit (int index, double start, long prior, double minendt);

/* Returns the number of sounds associated with an event */
int engineGetNoEventSnds (char *name);

/* Sets the number of sounds associated with an event to value */
int engineSetNoEventSnds (char *name, unsigned int value);

/* Creates an event entry data structure for a new sound mapping
 * with 'no_events' number of internal events.
 */
EVENT_ENTRY *engineAllocEventEntry (int no_events);

/* Frees an EVENT_ENTRY datastructure */
void engineFreeEventEntry (EVENT_ENTRY *entry);

/* Loads an array of sound data into the EVENT_ENTRY data structure,
 * at the appropriate index. The final argument specifies the length
 * of the sound data.
 */
int engineEventEntryAssignSnd (EVENT_ENTRY *entry, int event_no,
							   short *sound, unsigned int len);

/* Returns the array of sound data associated with the given name
 * and reference number
 */
short *engineGetEventSnd (char *name, int num);

/* Returns the length of the sound data array associated with the
 * given name and reference number
 */
unsigned int engineGetEventSndLen (char *name, int num);

/* Creates a state entry data structure where index is a reference
 * to the index of the state sound within the mixer.
 */
STATE_ENTRY *engineAllocStateEntry (int index);

/* Frees a STATE_ENTRY datastructure */
void engineFreeStateEntry (STATE_ENTRY *entry);

/* Create an ENGINE_EVENT to enqueue */
ENGINE_EVENT *engineEngineEventCreate (void);

/* Free the mixer ENGINE_EVENT */
void engineEngineEventFree (ENGINE_EVENT *event);

/* Performs the processing on an incoming sound event. This includes
 * all the algorithms for determining which channel the event will
 * play on or whether it will be placed into the priority queue
 * for later playback.
 */
void engineIO (EVENT *incoming_event);

/* Cleans up all of the engine data structures */
void engineShutdown (void);

/******************************************************************************
 * Functions internal to the engine's operation
 ******************************************************************************/

#define QUEUE_EXPIRED (5 * CLOCKS_PER_SEC)

#define TP_IN_FP_SECS(x) \
	( (double)x.tv_sec + ( (double)x.tv_usec * 0.000001) )

#endif
