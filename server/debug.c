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
#include <stdarg.h>
#include "debug.h"

/* For time formatting */
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

static FILE *log_handle = NULL;

#if DEBUG_LEVEL & DBG_ASSRT

/* The following assertion function is thanks to Prof. Alva Couch
 * at Tufts university */
int assert (int boolean, char *boolstr, char *file, int line)
{

    if (!boolean) {
        logMsg (DBG_ASSRT, "Assertion %s failed in line %d of file %s\n", boolstr, line, file);
    }
    /* else log(DBG_ASSRT, "Assertion %s succeeded in line %d of file %s\n",
     * boolstr,line,file);
     */

    return boolean != 0;

}

#endif

int logInit (const char *log_file)
{

    if (log_file) {

        const char *s = "Couldn't open server log file: ";
        char *errMsg = malloc(strlen(s) + strlen(log_file) + 1);
        if (errMsg) {
            strcat (errMsg, s);
            strcat (errMsg, log_file);
        }

        if ((log_handle = fopen (log_file, "a")) == NULL) {

            perror (errMsg);
            free (errMsg);

            return 0;
        }

        free (errMsg);

    }
    else {

        log_handle = stderr;

    }

    return 1;

}

int logClose (void)
{

    if (fclose (log_handle) != 0) {
        perror ("Error closing server log file");
    }

}

void logMsg (int level, const char *s, ...)
{

    va_list ap;
    time_t now;
    char output[LOG_BUF];
    char *time_string = NULL, *log_string = NULL;

    if (level & DEBUG_LEVEL) {

        /* Grab the formatted args into the va_list */
        va_start (ap, s);

        /* Use vsnprintf with a specific buffer length to avoid buffer overflows */
        vsnprintf (output, LOG_BUF, s, ap);
        va_end (ap);

        /* Now beautify the output. The log string is calculated as the length of
         * the current output, the asctime string, and the '[] ' characters, plus
         * the null
         */
        now = time (NULL);
        time_string = asctime (localtime (&now));
        time_string[strlen (time_string) - 1] = '\0';
        log_string = malloc (strlen (output) + strlen (time_string) + 4);
        sprintf (log_string, "[%s] %s", time_string, output);

        /* Output and flush the stream so we don't hang onto logging info */
        fprintf (log_handle, log_string);
        fflush (log_handle);

        free (log_string);

    }

}
