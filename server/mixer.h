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

#ifndef __PEEP__MIXER_H__
#define __PEEP__MIXER_H__

#define SAMPLE_RATE 44100
#define STEREO 2

#define MIXER_SUCCESS 1
#define MIXER_ALLOC_FAILED -1
#define MIXER_ALREADY_ALLOC -2
#define MIXER_NOT_YET_ALLOC -3
#define MIXER_CHAN_BUSY -4
#define MIXER_ERROR -5
#define MIXER_OUT_OF_BOUNDS -6

/* For autoconf time */
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

/* Event buffer descriptor */
typedef struct {
	short *snd_buf;    /* array of sound data */
	unsigned int len;  /* length of data */
	unsigned int pos;  /* current position ptr */
	double stereo_pos; /* stereo (left) */
	int filter_flag;   /* flag of effect filters to apply */
} EVENT_BUF;

/* A single state sound entry */
typedef struct {
	short **snd_buf;      /* array of state segments */
	unsigned int *len;    /* length of segments */
	unsigned int snd_cnt; /* number of sounds per state */
	unsigned int snd_no;  /* current segment to look at */
	unsigned int pos;     /* position in that segment */
} STATE_SND;

/* Threshold describing the bounds for at which an event applies */
typedef struct {
	double l_bound;       /* lower bound for the state */
	double h_bound;       /* upper bound for the state */
	STATE_SND state_snd;  /* the state sound associated with
	                       * the entry
	                       */
} THRESHOLD;

/* State buffer descriptor */
typedef struct {
	THRESHOLD *thresh;     /* threshold of each state segment */
	int thresh_cnt;        /* number of thresholds */
	double stereo_pos;     /* stereo (left) */
	double vol;            /* volume */
	int filter_flag;       /* flag of effect filters to apply */
} STATE_BUF;

/**************************************************************************
 * API functions to mixer
 **************************************************************************/

/* Initialize the mixer datastructures and make the calls to the sound
 * API to setup the sound card for play
 */
void mixerInit (void *device,
				unsigned int snd_port,
				unsigned int ebuf,
				unsigned int sbuf);

/* Returns the number of allocated event buffers */
unsigned int mixerEBuffs (void);

/* Returns the number of allocated state buffers */
unsigned int mixerSBuffs (void);

/* Adds an event samples into the sound buffers for play.  Accepts an array
 * of sound data to play, the lengthe of the data, the stereo location, and
 * the voicing to play the sound on.
 * Returns the mixer success values.
 */
int mixerAddEvent (short *snd, unsigned int len,
				   double loc, int flags, unsigned int voice);

/* Allocates memory for a new state, and assigns 'thresh_cnt' number of
 * different thresholds to the state. To create a state, this function
 * should be called, followed by mixerAddStateThreshold (), and then
 * mixerAddState ()
 */
int mixerAllocNewState (unsigned int state, int thresh_cnt);

/* Adds a threshold to the state buffer descriptor */
int mixerAddStateThreshold (unsigned int state, unsigned int thresh_index,
							double l_bound, double h_bound,
							unsigned int snd_cnt);

/* Adds a state sound within a threshold */
int mixerAddState (unsigned int state, unsigned int thresh_index,
				   unsigned int no_snd, short *sound, unsigned int len);

/* Change the settings of a continuous playing state sound */
void mixerSetStateSnd (unsigned int j, double vol,
					   double stereo, int flags);

/* Returns whether a state sound with the given index exists within
 * the mixer data structures - 1 if true, 0 if false.
 */
int mixerExistsStateSound (int index);

/* Returns 1 if the sound has been loaded into the mixer data structure */
int mixerLoadedStateSound (int index);

/* Returns the number of states actually loaded into the mixer */
int mixerGetNoLoadedStates (void);

/* Stop a sound from playing in a given event buffer */
void mixerInterrupt (unsigned int j);

/* The actual mixer subroutine. Mixes the current sound "frame" and outputs
 * it to the sound device
 */
void mixer (void);

/* Cleans up the mixer datastructures and shuts down the mixer */
void mixerShutdown (void);

/**************************************************************************
 * Internal mixer functions
 **************************************************************************/

/* Clears the datastructures associated with a particular event */
void mixerRemoveEvent (unsigned int j);

/* Gets an old event from the queue and adds it into the mixer */
void mixerAddOldEvent (unsigned int j);

/* Picks the next randomg state sound segment for a state buffer
 * denoted by j
 */
unsigned int mixerPickRndStateSnd (int j);

#define STATE_MULT 0.4
#define EVENT_MULT 0.6

/* Returns the percentage available as a group multiplier to
 * determine the volume of the sound about to be played
 */
double mixerDynGMul (void);

/* Returns the invdividual multiplier, which multiplies the group
 * multiplier so that the end result has a logarithmic
 * characteristic. More detail can be found on the website docs of
 * dynamic mixing
 */
double mixerDynIMul (void);

/* Computes the total volume multipliers currently in use */
double mixerDynTotVol (void);

/* Returns a new multiplier for a channel being added */
double mixerDynVol (void);

#define DYNAMIC_MULT(x) ( dyn_mul[x] )

/* Returns the index of the state sound structure according to
 * the current volume of the state sound
 */
int mixerGetStateThreshIndex (unsigned int j);

/* Returns a pointer to a state sound record with the given index and
 * volume
 */
STATE_SND *mixerGetStateSndPtr (int j, double vol);

/* Returns a pointer to a threshold entry found at sound index 'j' with
 * threshold index 'index'
 */
THRESHOLD *mixerGetThresholdEntry (int j, int index);

/***************************************************************************
 * Effects related functions
 ***************************************************************************/

/* Filter flag definitions. Not that both event and state filter flags
 * should have a MAX_*_FLAG at the end of the bunch
 */

#define MAX_EVENT_FLAG (1 << 0)

#define STATE_LINEAR_FADE_FLAG (1 << 0)
#define MAX_STATE_FLAG (1 << 1)

/* Applies all filters tagged in the event buffer descriptor's filter
 * flag to the sound chunk and returns the result
 */
short mixerApplyEventFilters (short data, unsigned int pos, unsigned int j);

/* Applies all filters tagged in the state buffer descriptor's filter
 * flag to the sound chunk and returns the result
 */
short mixerApplyStateFilters (short data, unsigned int pos, unsigned int j);

typedef struct {
	double fade_time; /* time remaining at which to begin fading */
	unsigned int snd; /* next random sound to play */
	unsigned int pos; /* position in the next random sound */
	int old_thresh;   /* old sound threshold index */
} FADE_REC;

/* Functions for linear fading between states */

#define MAX_FADE_TIME 2.0

/* Initialize the fade effect data structures */
void mixerFadeEffectInit (void);

/* Set the fade time for a given state sound */
int mixerSetFadeTime (unsigned int j, double time);

/* Get the linear fade time for a given state sound */
double mixerGetFadeTime (unsigned int j);

/* Perform the actual operation of linear fading between a current
 * playing sound a new one selected internally to the function.
 * This effect is applied by the effect loop
 */
short mixerFadeEffect (short data, unsigned int pos, unsigned int j);

/* Deallocate any datastructures used for the linear fade effect */
void mixerFadeEffectShutdown (void);

#endif
