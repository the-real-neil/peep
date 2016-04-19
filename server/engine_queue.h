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

#ifndef __PEEP_ENGINE_ENQUEUE_H__
#define __PEEP_ENGINE_ENQUEUE_H__

/* For event definition */
#include "engine.h"

/* Engine queue element datastructure
 *   Serves as queue interface between the engine thread and the
 *   server thread
 */
typedef struct engine_queue_element {
  EVENT incoming_event;
  struct engine_queue_element *next;
  struct engine_queue_element *prev;
} ENGINE_QUEUE_ELEMENT;

/* Initialize the engine queue */
int engineQueueInit (void);

/* Destroy the engine queue */
void engineQueueDestroy (void);

/* Add an event into the engine queue */
void engineEnqueue (EVENT d);

/* Get the next element from the engine queue and remove it */
EVENT engineDequeue (void);

/* Boolean function to check whether the engine queue is empty */
int engineQueueEmpty (void);

#endif
