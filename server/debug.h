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

#ifndef __PEEP_DEBUG_H__
#define __PEEP_DEBUG_H__

/* Logging levels, defined as flags */
enum {
    DBG_DEF   = (1 << 0),    /* Default, standard output */
    DBG_GEN   = (1 << 2),    /* General operational info */
    DBG_SETUP = (1 << 3),    /* General setup info */
    DBG_SRVR  = (1 << 4),    /* Server interactions */
    DBG_HOOK  = (1 << 5),    /* For debugging of code hooks */
    DBG_ENG   = (1 << 6),    /* Engine information */
    DBG_MXR   = (1 << 8),    /* Mixer info */
    DBG_AUTO  = (1 << 10),   /* Autodiscovery debugging */
    DBG_QUE   = (1 << 12),   /* Queuing operations */
    DBG_PLBK  = (1 << 14),   /* Debugging about playback and recording */

    DBG_ASSRT = (1 << 31),   /* Debug with assertions. */
};

/* Debugging level definitions */
enum {
    DBG_LOWEST       = (DBG_DEF     | DBG_GEN),
    DBG_LOWER        = (DBG_LOWEST  | DBG_SETUP | DBG_SRVR),
    DBG_MEDIUM       = (DBG_LOWER   | DBG_PLBK | DBG_ENG ),
    DBG_HIGHER       = (DBG_MEDIUM  | DBG_MXR | DBG_AUTO | DBG_HOOK),
    DBG_HIGHEST      = (DBG_HIGHER  | DBG_QUE),
    DBG_ALL_W_ASSERT = (DBG_HIGHEST | DBG_ASSRT)
};

/* Variable definition to compile in code assertions.
 * Note that compiling this in will greatly reduce the speed
 * of code execution */
#if DEBUG_LEVEL & DBG_ASSRT
#define  ASSERT(X) assert((X),#X,__FILE__,__LINE__);
#undef assert
    int assert (int boolean, char *boolstr, char *file, int line);
#else
#define ASSERT(X)
#endif

/* Initialize the logging routines */
int logInit (const char *log_file);

/* Close the logfile and clean up */
int logClose (void);

#define LOG_BUF 1024

/* Include stdio so we don't have problems with using
 * a FILE * type */
#include <stdio.h>

/* Variable argument logging function */
void logMsg (int level, const char *s, ...);

#endif
