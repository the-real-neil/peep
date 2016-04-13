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

#ifndef __PEEP_THREAD_H__
#define __PEEP_THREAD_H__

#include <pthread.h>
#include <semaphore.h>

typedef void *(*THREAD_FUNC) (void *data);

/* Begin a new Thread */
int startThread (THREAD_FUNC func, void *data, pthread_t *handle);

/* Functions to lock and unlock threads */
void threadLockInit (pthread_mutex_t *lock);
void threadLock (pthread_mutex_t *lock);
void threadUnlock (pthread_mutex_t *lock);

/* Make a thread sleep */
void threadSleep (unsigned long utime);

/* Checks if the thread has received a cancellation request */
void threadCheckCancelled (void);

/* Kill a thread */
void threadKill (pthread_t thread);

/* Detach a thread from its parent */
void threadDetach (pthread_t thread);

/* Keeps the calling thread from receiving SIGINT and SIGHUP
 * signals.
 */
void threadBlockSignals (void);

/* Creates a semaphore object initialized to the value argument and
 * returns a pointer to the object. Returns NULL on error.
 */
sem_t *semaphoreCreate (int value);

/* Decrements the semaphore object pointed at by sem. If blocking is
 * 1, then the thread will block if the semaphore is at a zero count.
 * If blocking is 0, a 0 is returned if the semaphore count is zero.
 * A 1 is returned if the semaphore was successfully decremented.
 */
int semaphoreAcquire (sem_t *sem, int blocking);

/* Asynchronously increments a semaphore count. Returns 1 upon
 * success and zero otherwise.
 */
int semaphoreRelease (sem_t *sem);

/* Destroys the object pointed at by sem. */
int semaphoreDestroy (sem_t *sem);

#endif
