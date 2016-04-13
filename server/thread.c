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
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <errno.h>
#include "thread.h"
#include "debug.h"

int startThread (THREAD_FUNC func, void *data, pthread_t *handle)
{

	int rc;

	pthread_attr_t attr;

	rc = pthread_attr_init (&attr);
	rc = pthread_create (handle, &attr, func, data);
 	pthread_attr_destroy (&attr);

	return rc;

}

void threadLockInit (pthread_mutex_t *lock)
{

	pthread_mutex_init (lock, NULL);

}

void threadLock (pthread_mutex_t *lock)
{

	pthread_mutex_lock (lock);

}

void threadUnlock (pthread_mutex_t *lock)
{

	pthread_mutex_unlock (lock);

}

void threadSleep (unsigned long utime)
{

	usleep (utime);

}

void threadCheckCancelled ()
{

	pthread_testcancel ();

}

void threadKill (pthread_t thread)
{

	pthread_cancel (thread);

}

void threadDetach (pthread_t thread)
{

	pthread_detach (thread);

}

void threadBlockSignals (void)
{

	sigset_t new_mask, old_mask;

	sigemptyset (&new_mask);
	sigaddset (&new_mask, SIGINT);
	sigaddset (&new_mask, SIGHUP);

	pthread_sigmask (SIG_BLOCK, &new_mask, &old_mask);

}

sem_t *semaphoreCreate (int value)
{

	sem_t *sem = NULL;

	if ((sem = (sem_t *)malloc (sizeof (sem_t))) == NULL) {

		log (DBG_GEN, "Error creating a new semaphore: %s\n", strerror (errno));
		return NULL;

	}

	if (sem_init (sem, 0, value) < 0) {

		log (DBG_GEN, "Error initializing a new semaphore: %s\n", strerror (errno));
		free (sem);
		return NULL;

	}

	return sem;

}

int semaphoreAcquire (sem_t *sem, int blocking)
{

	int ret = 0;

	if (blocking) {

		if ((ret = sem_wait (sem)) < 0) {

			log (DBG_GEN, "Error waiting on and decrementing a semaphore: %s\n", strerror (errno));
			return 0;

		}

	}
	else {

		if ((ret = sem_trywait (sem)) < 0) {

			if (ret != EAGAIN)
				log (DBG_GEN, "Error performing non-blocking acquire of a semaphore: %s\n",
					 strerror (errno));

			return 0;

		}

	}

	return 1;

}

int semaphoreRelease (sem_t *sem)
{

	if (sem_post (sem) < 0) {

		log (DBG_GEN, "Error incrementing a semaphore: %s\n", strerror (errno));
		return 0;

	}
	else
		return 1;

}

int semaphoreDestroy (sem_t *sem)
{

	if (sem && sem_destroy (sem) < 0) {

		log (DBG_GEN, "Error destroying a semaphore: %s\n", strerror (errno));
		free (sem);
		return 0;

	}
	else {

		free (sem);
		return 1;

	}

}
