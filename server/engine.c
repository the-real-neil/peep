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
#include <stdlib.h>
#include <string.h>
#include "engine.h"
#include "engine_queue.h"
#include "thread.h"
#include "mixer.h"
#include "playback.h"
#include "debug.h"

/* For the sound table */
static struct sound_entry **sound_table = NULL;

/* Engine scheduling datastructure (calloc'd to half the number of channels */
struct engine_sched *sched = NULL;

/* Number of event and state channels */
static unsigned int no_ebuffs = 0;
static unsigned int no_sbuffs = 0;

/* lock for modifying timing data structures */
pthread_mutex_t tlock;

void engineInit (char *device, unsigned int snd_port,
				 unsigned int ebuf, unsigned int sbuf)
{

	no_ebuffs = ebuf;
	no_sbuffs = sbuf;

	/* Start the mixer */
	mixerInit (device, snd_port, ebuf, sbuf);

	/* Initialize the internal scheduler */
	sched = (struct engine_sched *)calloc (sizeof (struct engine_sched), ebuf);

	/* Initialize the sound table */
	engineInitSoundTable ();

	/* Initialize the queue interfacing to the engine */
	engineQueueInit ();

	/* Initialize the heap to the default queue entries */
	mixerQueueInit (EVENT_QUEUE_ENTRIES);

	/* Init the mutex lock */
	pthread_mutex_init (&tlock, NULL);

}

int engineInitSoundTable (void)
{

	sound_table = (struct sound_entry **)calloc (sizeof (struct sound_entry *), HASHES);

	if (sound_table == NULL)
		return ENGINE_ALLOC_FAILED;

	return ENGINE_SUCCESS;

}

int engineSoundTableInsertEvent (char *name, EVENT_ENTRY *event)
{

	struct sound_entry *entry = (struct sound_entry *)calloc (sizeof (struct sound_entry), 1);

	entry->name = (char *)calloc (sizeof (char), strlen (name) + 1);
	strcpy (entry->name, name);
	entry->type = EVENT_T;
	entry->data = (void *)event;

	return engineSoundTableInsert (entry);

}

int engineSoundTableInsertState (char *name, STATE_ENTRY *state)
{

	struct sound_entry *entry = (struct sound_entry *)calloc (sizeof (struct sound_entry), 1);

	entry->name = (char *)calloc (sizeof (char), strlen (name) + 1);
	strcpy (entry->name, name);
	entry->type = STATE_T;
	entry->data = (void *)state;

	return engineSoundTableInsert (entry);

}

int engineSoundTableInsert (struct sound_entry *entry)
{

	int index = engineSoundHash (entry->name);
	struct sound_entry *p = NULL;

	if (sound_table[index] == NULL)
		sound_table[index] = entry;
	else {

		for (p = sound_table[index]; p->next; p = p->next) {

			/* Check if a sound of the same name is already in the table */
			if (!strcasecmp (p->name, entry->name))
				return ENGINE_SOUND_EXISTS;

		}

		p->next = entry;

	}

	return ENGINE_SUCCESS;

}

void *engineSoundTableRetrieve (char *name)
{

	int index = engineSoundHash (name);
	struct sound_entry *p = NULL;

	for (p = sound_table[index]; p; p ->next) {

		if (!strcasecmp (p->name, name))
			return p;

	}

	return NULL;

}

void *engineSoundTableDataRetrieve (char *name)
{

	struct sound_entry *p = engineSoundTableRetrieve (name);

	if (p == NULL)
		return NULL;

	return p->data;

}

void engineSoundTableDestroy (void)
{

	int i = 0, j = 0;
	struct sound_entry *p = NULL, *q = NULL;


	if (sound_table != NULL) {

		for (i = 0; i < HASHES; i++) {

			if (sound_table[i] != NULL) {

				p = sound_table[i];

				while (p) {

					q = p->next;

					/* Free the data if it's an event */
					if (p->type == EVENT_T) {

						for (j = 0; j < ((EVENT_ENTRY *)p->data)->snd_cnt; j++)
							free (((EVENT_ENTRY *)p->data)->snds[j]);

						free (((EVENT_ENTRY *)p->data)->snds);
						free (((EVENT_ENTRY *)p->data)->lens);

					}

					cfree (p->name);
					cfree (p->data);
					cfree (p);
					p = q;

				}

			}

		}

		cfree (sound_table);
		sound_table = NULL;

	}

}

int engineSoundHash (char *name)
{

	int count = 0;
	char *p = NULL;

	for (p = name; *p; p++)
		count += *p;

	return (count % HASHES);

}

int engineSchedulerInit (int index, double start, long prior, double minendt)
{

	threadLock (&tlock);

	if (sched == NULL)
		return ENGINE_NOT_YET_ALLOC;

	sched[index].startt = start;
	sched[index].priorit = prior;
	sched[index].minendt = minendt;

	threadUnlock (&tlock);

	return ENGINE_SUCCESS;

}

int engineGetNoEventSnds (char *sound)
{

	struct sound_entry *entry = engineSoundTableRetrieve (sound);
	EVENT_ENTRY *e = NULL;

	if (entry == NULL || entry->type != EVENT_T)
		return ENGINE_SOUND_NOT_FOUND;

	e = (EVENT_ENTRY *)entry->data;
	return e->snd_cnt;

}

int engineSetNoEventSnds (char *sound, unsigned int value)
{

	struct sound_entry *entry = NULL;
	EVENT_ENTRY *e = NULL;

	if (sound_table == NULL)
		return ENGINE_NOT_YET_ALLOC;

	entry = engineSoundTableRetrieve (sound);

	if (entry == NULL || entry->type != EVENT_T);
		return ENGINE_SOUND_NOT_FOUND;

	e = (EVENT_ENTRY *)entry->data;
	e->snd_cnt = value;
	return ENGINE_SUCCESS;

}

EVENT_ENTRY *engineAllocEventEntry (int no_events)
{

	EVENT_ENTRY *entry = (EVENT_ENTRY *)calloc (sizeof (EVENT_ENTRY), 1);

	if (entry != NULL) {

		entry->snds = (short **)calloc (sizeof (short *), no_events);
		entry->lens = (unsigned int *)calloc (sizeof (unsigned int), no_events);
		entry->snd_cnt = no_events;

	}

	return entry;

}

void engineFreeEventEntry (EVENT_ENTRY *entry)
{

	cfree (entry);

}

int engineEventEntryAssignSnd (EVENT_ENTRY *entry, int event_no,
							   short *sound, unsigned int len)
{

	if (entry == NULL)
		return ENGINE_NOT_YET_ALLOC;

	entry->snds[event_no] = sound;
	entry->lens[event_no] = len;

	return ENGINE_SUCCESS;

}

short *engineGetEventSnd (char *name, int num)
{

	struct sound_entry *entry = engineSoundTableRetrieve (name);
	EVENT_ENTRY *e = NULL;

	if (entry == NULL)
		return NULL;
	else {

		e = (EVENT_ENTRY *)entry->data;
		return e->snds[num];

	}

}

unsigned int engineGetEventSndLen (char *name, int num)
{

	struct sound_entry *entry = engineSoundTableRetrieve (name);
	EVENT_ENTRY *e = NULL;

	if (entry == NULL)
		return 0;
	else {

		e = (EVENT_ENTRY *)entry->data;
		return e->lens[num];

	}

}

STATE_ENTRY *engineAllocStateEntry (int index)
{

	STATE_ENTRY *entry = (STATE_ENTRY *)calloc (sizeof (STATE_ENTRY), 1);

	if (entry != NULL)
		entry->mixer_index = index;

	return entry;

}

void engineFreeStateEntry (STATE_ENTRY *entry)
{

	cfree (entry);

}

ENGINE_EVENT *engineEngineEventCreate (void)
{

	return (ENGINE_EVENT *)calloc (sizeof (ENGINE_EVENT), 1);

}

void engineEngineEventFree (ENGINE_EVENT *event)
{

	cfree (event);

}

void engineIO (EVENT *incoming_event)
{

	static int lastc = 0;  /* keep track of which channel we were looking at last */
	int next_snd;          /* next event to be chosen at random */
	int c = 0, bestc, ind; /* counters for the event algorithm */
	struct timeval tp;     /* for gettimeofday call */
	ENGINE_EVENT *engine_event = NULL; /* Wrapper for holding events for various
										* data structures */


	/* Check if playback is active and whether we should record the event */
	if (playbackModeOn (NULL) && playbackSetMode (NULL) == RECORD_MODE) {

		engine_event = engineEngineEventCreate ();
		engine_event->event = *incoming_event;

		if (! playbackRecordEvent (*engine_event)) {

			log (DBG_GEN, "WARNING: Error recording an event. Event not recorded.\n");
			/* continue anyway */

		}

		engineEngineEventFree (engine_event);

	}

	if (incoming_event->type == EVENT_T) {

		EVENT_ENTRY *entry = NULL;

		/* When an event comes in:
		 *   -try to pick a channel c that's idle
		 *   -otherwise, interrupt lowest priority snd
		 * Note that distance here is:
		 *   TP_IN_FP_SECS(tp)-startt[c]
		 */

		/* if after bestc == -1, we need temporal queuing */
		bestc = -1;

		for (ind = 0; ind < no_ebuffs; ind++) {

			/* Round Robin starting at last c */
			c = (lastc + ind) % no_ebuffs;

			ASSERT (ind >= 0 && ind < no_ebuffs)
			ASSERT (c >= 0 && c < no_ebuffs)

			/* Can we get a channel right away */
			if (sched[c].startt == 0) {

#if DEBUG_LEVEL & DBG_ENG
				log (DBG_ENG, "We found a channel right away: %d\n", c);
#endif

				bestc = c;
				break;

			}

			/* Now choose the sound with the lowest priority */
			gettimeofday (&tp, NULL);

			if (bestc == 0 && (sched[bestc].priorit < sched[c].priorit)) {

				ASSERT (sched[c].priorit >= 0 && sched[bestc].priorit >= 0)

#if DEBUG_LEVEL & DBG_ENG
				log (DBG_ENG, "Event with a higher priority than channel: %d or c = 0\n", c);
#endif

				bestc = c;
				continue;

			}

			if (bestc == 0
				&& (sched[bestc].priorit == sched[c].priorit
				&&  sched[bestc].startt > sched[c].startt)) {

				ASSERT (sched[c].priorit >= 0 && sched[bestc].startt >= 0 && sched[c].startt >= 0)

#if DEBUG_LEVEL & DBG_ENG
				log (DBG_ENG, "Hit a minimal start time for channel: %d\n", c);
#endif

				bestc = c;
				continue;

			}

		}

		/* At this point, bestc is either a blank channel or the lowest priority
		 * one that started earliest. If bestc == -1, then we don't have a channel
		 * yet and should put it into the temporal priority queue.
		 */
		if (bestc == -1) {

			/* If the queue if full, discard the event anyway */
			if (mixerQueueFull ()) {

#if DEBUG_LEVEL & DBG_QUE
				log (DBG_QUE, "Heap was full. Event discarded...\n");
#endif

				return;

			}

			engine_event = engineEngineEventCreate ();

			engine_event->event = *incoming_event;
			gettimeofday (&tp, NULL);
			engine_event->mix_time = tp;

			mixerEnqueue (engine_event);

			return;

		}
		else {

			/* Make sure that lastc gets assigned to the next one to start
			 * search at
			 */
			lastc = (bestc + 1) % no_ebuffs;

		}

		/* Interrupt the channel if playing */
		if (sched[bestc].startt != 0) {

			mixerInterrupt (bestc);

			ASSERT (bestc >= 0)

#if DEBUG_LEVEL & DBG_ENG
			log (DBG_ENG, "Interrupted channel: %d\n", bestc);
#endif

		}

		/* Pick a new random event sound and add it into the mixer */
#if DEBUG_LEVEL & DBG_ENG
		log (DBG_ENG, "Mixing in sound on channel: %d\n", bestc);
#endif

		/* Retrieve the event entry from the sound table */
		entry = engineSoundTableDataRetrieve (incoming_event->sound);

		next_snd = (int)((double)entry->snd_cnt * rand () / (RAND_MAX + 1.0));
		mixerAddEvent (entry->snds[next_snd],
					   entry->lens[next_snd],
					   (double)incoming_event->loc / 255.0,
					   incoming_event->flags,
					   bestc);

		/* Update sound data structures */
		gettimeofday (&tp, NULL);

		threadLock (&tlock);

		ASSERT (bestc >= 0 && bestc < no_ebuffs)

		sched[bestc].startt = TP_IN_FP_SECS (tp);
		sched[bestc].priorit = incoming_event->prior;

#if DEBUG_LEVEL & DBG_ENG
		log (DBG_ENG, "Assigned to startt for bestc: %lf on channel: %d\n",
			 sched[bestc].startt, bestc);
		log (DBG_ENG, "\n");
#endif

		threadUnlock (&tlock);

	}
	else if (incoming_event->type == STATE_T) {

		STATE_ENTRY *entry = engineSoundTableDataRetrieve (incoming_event->sound);

		/* Process a state sound. The mapping number corresponds directly to
		 * the number of event channels. This is checked when loading so we
		 * can do this: (Volumes must also be between 0.0 and 1.0 and double)
		 *
		 * Note that a dither of 255 (which should be default for the sender)
		 * does not change the fade time for the state. This means we can set
		 * at max a parameter of 254, which is never exactly the max fade
		 * time possible. Big deal.
		 */
		double fade = mixerGetFadeTime (entry->mixer_index);

		if (incoming_event->dither != 255) {

			fade = (double)incoming_event->dither / (255.0 / MAX_FADE_TIME);
			mixerSetFadeTime (entry->mixer_index, fade);

#if DEBUG_LEVEL & DBG_ENG
			log (DBG_ENG, "Set fade time for sound [%s] to [%lf].\n", incoming_event->sound, fade);
#endif

		}
		else {

#if DEBUG_LEVEL & DBG_ENG
			log (DBG_ENG, "Fade value for packet was 255. Using old value: [%lf].\n", fade);
#endif

		}

		/* Tell the mixer about the new event info */
		mixerSetStateSnd (entry->mixer_index,
						  (double)incoming_event->vol / 255.0,
						  (double)incoming_event->loc / 255.0,
						  incoming_event->flags);

#if DEBUG_LEVEL & DBG_ENG
		log (DBG_ENG, "Set volume for state [%s] to [%lf].\n", incoming_event->sound, (double)incoming_event->vol / 255.0);
#endif

	}
	else {

#if DEBUG_LEVEL & DBG_ENG
		log (DBG_ENG, "Received event of an unsupported type. Discarding...\n");
#endif

	}

	/* Free the sound string part of the event here.
	 * This needs to be free'd here since we might be queuing the
	 * event and need to keep the sound string around
	 */
	if (incoming_event->sound)
		free (incoming_event->sound);

}

void engineShutdown (void)
{

	int i, j;

	/* Free the engine scheduler data structure */
	cfree (sched);

	/* Free the engine sound table */
	engineSoundTableDestroy ();

	/* Destroy the mixer queue */
	mixerQueueDestroy ();

	/* Destroy the engine queue */
	engineQueueDestroy ();

}
