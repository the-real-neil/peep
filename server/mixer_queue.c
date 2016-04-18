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

#include <stdlib.h>
#include "config.h"
#include "mixer_queue.h"
#include "engine.h"
#include "thread.h"
#include "debug.h"

/* Event priority queue datastructure */
static ENGINE_EVENT **heap = NULL; /* queue of incoming_events */
static int top;                    /* top of the heap */
static int queueSize;              /* size of the heap */

/* For modifying the queue from different threads */
static pthread_mutex_t qlock;

void mixerQueueInit (int s)
{

    top = 0;
    queueSize = s;
    heap = calloc (queueSize, sizeof *heap);

    /* Initialize the mutex */
    threadLockInit (&qlock);

}

void mixerQueueDestroy (void)
{

    ENGINE_EVENT *item = NULL;

    if (heap) {

        while (!mixerQueueEmpty() && (item = mixerDequeue ())) {
            if (item->event.sound) {
                free(item->event.sound);
                item->event.sound = NULL;
            }
            free (item);
        }

        free (heap);

    }

}

void swap (int i, int j)
{

    ENGINE_EVENT *temp;

    temp = heap[i];
    heap[i] = heap[j];
    heap[j] = temp;

}

void mixerEnqueue (ENGINE_EVENT *new_event)
{

    int pos = 0;

    ASSERT (new_event != NULL);

    /* Do a mutex lock when modifying the queue */
    threadLock (&qlock);

    pos = top;
    heap[top] = new_event; /* Put the event in the heap */
    bubbleUp (pos);        /* Adjust position of the event  */
    top++;

    threadUnlock (&qlock);

#if DEBUG_LEVEL & DBG_QUE
    logMsg (DBG_QUE, "Event was enqueued. Events in queue now: %d\n", top);
#endif

}

int bubbleUp (int pos)
{

    int done = 0;
    int parent;

    while (!done) {

        /* Correct for offset 0 rather than 1 */
        parent = (pos + 1) / 2;

        if (parent == 0) {
            done = 1;
	}

        if (parent < 0) {

            swap (0, pos);
            done = 1;

        }

        if (heap[parent]->event.prior > heap[pos]->event.prior) {

            swap (parent, pos);
            pos = parent;

        }
        else {
            done = 1;
	}

    }

    return pos;

}

ENGINE_EVENT *mixerDequeue (void)
{

    /* Save the top for the return */
    ENGINE_EVENT *res = NULL;

    /* Do a mutex lock for modifying the queue */
    threadLock (&qlock);

    ASSERT (top > 0);
    res = heap[0];
    ASSERT (res != NULL);

    heap[0] = heap[--top]; /* Copy last element to top & decrease size */
    bubbleDown (0);        /* Adjust element 0 */

    threadUnlock (&qlock);

#if DEBUG_LEVEL & DBG_QUE
    logMsg (DBG_QUE, "Event was Dequeued. Events remaining: %d\n", top);
#endif

    return res;

}

int bubbleDown (int pos)
{

    int done = 0;
    int lchild, rchild;

    while (!done) {

        lchild = (pos + 1) * 2 - 1;
        rchild = (pos + 1) * 2;

        if (lchild < top && rchild < top) {

            if (heap[lchild]->event.prior <= heap[rchild]->event.prior
                && heap[lchild]->event.prior < heap[pos]->event.prior) {

                swap (pos, lchild);
                pos = lchild;

            }
            else if (heap[rchild]->event.prior <= heap[lchild]->event.prior
                     && heap[rchild]->event.prior < heap[pos]->event.prior) {

                swap (pos, rchild);
                pos = rchild;

            }
            else {
                done = 1;
	    }

        }
        else if (lchild < top) {

            done = 1;

            if (heap[lchild]->event.prior < heap[pos]->event.prior) {

                swap (pos, lchild);
                pos = lchild;

            }

        }
        else {
            done = 1;
	}

    }

    return pos;

}

int mixerQueueEmpty (void)
{

    return (top == 0);

}

int mixerQueueFull (void)
{

    return (top == queueSize);

}
