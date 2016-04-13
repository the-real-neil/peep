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

#ifndef __PEEP_MIXER_QUEUE_H__
#define __PEEP_MIXER_QUEUE_H__

/* So we can declare an Event function */
#include "engine.h"

/***************************************************************
 * This header and its associated .c file implement a priority
 * queue that serves as temporary storage for events if all
 * mixer channels are full.
 **************************************************************/

/**************************************************************
 * API for interacting with the queue
 **************************************************************/

/* Initialize the heap */
void mixerQueueInit (int s);

/* Destroy the heap */
void mixerQueueDestroy (void);

/* Interface to enqueue an old event into the priority queue */
void mixerEnqueue (ENGINE_EVENT *new_event);

/* Removes an old event from the priority queue */
ENGINE_EVENT *mixerDequeue (void);

/* Check the status of the queue */
int MixerQueueEmpty (void);
int MixerQueueFull (void);

/***************************************************************
 * Internal function
 ***************************************************************/

/* Swap two elements i and j in the heap */
void swap (int i, int j);

/* Perform a bubble sort from a single position, up through the
 * queue
 */
int bubbleUp (int pos);

/* Perform a bubble sort from a single position downward through
 * the queue
 */
int bubbleDown (int pos);

#endif
