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
#include "engine_queue.h"
#include "thread.h"
#include "debug.h"

static ENGINE_QUEUE_ELEMENT *head = NULL;
static ENGINE_QUEUE_ELEMENT *tail = NULL;
static sem_t *semaphore = NULL;

int engineQueueInit (void)
{

	/* Initialize the queue's semaphore to blocking mode */
	if ((semaphore = semaphoreCreate (0)) == NULL)
		return 0;
	else
		return 1;

}

void engineQueueDestroy (void)
{

	if (semaphore)
		semaphoreDestroy (semaphore);

}

void engineEnqueue (EVENT d)
{

	ENGINE_QUEUE_ELEMENT *cur_pos = head;

	if (head == NULL) {

		head = (ENGINE_QUEUE_ELEMENT *)malloc ( sizeof (ENGINE_QUEUE_ELEMENT) );
		head->incoming_event = d;
		head->next = head->prev = NULL;
		tail = head;

	}
	else {

		/* Loop 'till we hit the end of the queue */
		while (cur_pos->next != NULL)
			cur_pos = cur_pos->next;

		cur_pos->next = (ENGINE_QUEUE_ELEMENT *)malloc ( sizeof (ENGINE_QUEUE_ELEMENT) );
		cur_pos->next->incoming_event = d;
		cur_pos->next->next = NULL;
		cur_pos->next->prev = cur_pos;
		tail = cur_pos->next;

	}

	/* Increment the semaphore */
	semaphoreRelease (semaphore);


}

EVENT engineDequeue (void)
{

	EVENT temp;

	/* Acquire the semaphore, which means there's something in the queue */
	semaphoreAcquire (semaphore, 1);

	temp = tail->incoming_event;

	if (tail->prev != NULL) {

		tail = tail->prev;
		free (tail->next);
		tail->next = NULL;

	}
	else {

		free (tail);
		tail = head = NULL;

	}

	return temp;

}

int engineQueueEmpty (void)
{

	return (head == NULL);

}
