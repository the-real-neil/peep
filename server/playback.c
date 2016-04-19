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
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "main.h"
#include "playback.h"
#include "debug.h"

static FILE *stream = NULL;         /* Pointer to the file stream */
static struct playback_h header;    /* The file header */
static unsigned long event_cnt = 0; /* Keep track of # of events */
static playback_mode_t mode;        /* Current playback mode */
static int use_playback = 0;        /* Default to not using playback */
static int loopback_flag = 0;       /* Used loopback while recording? */

extern int errno;

int playbackModeOn (int *t)
{

  if (t) {
    use_playback = *t;
  }

  return use_playback;

}

playback_mode_t playbackSetMode (playback_mode_t *m)
{

  if (m) {
    mode = *m;
  }

  return mode;

}

int playbackFileInit (char *file)
{

#if DEBUG_LEVEL & DBG_PLBK
  logMsg (DBG_PLBK, "Playback routines using file: %s, ", file);
#endif

  if (playbackSetMode (NULL) == RECORD_MODE) {
    logMsg (DBG_PLBK, "mode: 'RECORD_MODE'\n");
  } else {
    logMsg (DBG_PLBK, "mode: 'PLAY_MODE'\n");
  }


  switch (playbackSetMode (NULL)) {

  case PLAY_MODE:

    if ((stream = fopen (file, "r")) == NULL) {

      logMsg (DBG_GEN, "Uh Oh! Couldn't open playback file: %s\n", strerror (errno));
      shutDown ();

    }

    /* Lead the header into memory */
    if (fread (&header, sizeof (struct playback_h), 1, stream) == 0) {

      logMsg (DBG_GEN, "Error reading in playback header: %s\n", strerror (errno));
      return 0;

    }

    break;

  case RECORD_MODE:

    if ((stream = fopen (file, "w")) == NULL) {

      logMsg (DBG_GEN, "Uh Oh! Couldn't create recoding file: %s\n",
              strerror (errno));
      shutdown ();

    }

    memset (&header, 0, sizeof (struct playback_h));

    header.major_ver = PLAYBACK_MAJOR_VER;
    header.minor_ver = PLAYBACK_MINOR_VER;
    header.max_events = MAX_PLAYBACK_EVENTS;

    /* Our initial start position can be found right after
     * the header
     */
    header.start_pos = sizeof (struct playback_h);

    gettimeofday (&header.start_t, NULL);

    /* Initialize the file with the header. Note that end_t is initially
     * left at zero
     */
    if (fwrite (&header, sizeof (struct playback_h), 1, stream) == 0) {

      logMsg (DBG_GEN, "Error initializing file with playback header: %s\n",
              strerror (errno));
      return 0;

    }

    /* Flush out the header */
    fflush (stream);
    break;

  default:

    logMsg (DBG_DEF,
            "Uh Oh! peepd asked to use invalid mode for playback. Please specify: {PLAY_MODE, RECORD_MODE}\n");
    shutdown ();

  }

#if DEBUG_LEVEL & DBG_PLBK
  logMsg (DBG_PLBK, "The playback header is:\n");
  logMsg (DBG_PLBK, "\tmajor ver:      [%d]\n", header.major_ver);
  logMsg (DBG_PLBK, "\tminor ver:      [%d]\n", header.minor_ver);
  logMsg (DBG_PLBK, "\tmax events:     [%d]\n", header.max_events);
  logMsg (DBG_PLBK, "\tevents written: [%d]\n", header.written);
  logMsg (DBG_PLBK, "\tstart pos:      [%d]\n", header.start_pos);
  logMsg (DBG_PLBK, "\tstart time:     [%lf]\n", TP_IN_FP_SECS (header.start_t));
  logMsg (DBG_PLBK, "\tend time:       [%lf]\n", TP_IN_FP_SECS (header.end_t));
#endif

  return 1;

}

long playbackFindFirstOffset (void)
{

  playback_t cur, prev;
  long initial_pos = ftell (stream);

  fread (&prev, sizeof (playback_t), 1, stream);

  while (!feof (stream)) {

    fread (&cur, sizeof (playback_t), 1, stream);

    /* Check if the event we're reading in was earlier than the
     * previous event. If so, return the position right before
     * the read
     */
    if (TP_IN_FP_SECS (cur.record.mix_time) <
        TP_IN_FP_SECS (prev.record.mix_time)) {

      return (ftell (stream) - sizeof (playback_t));

    }

  }

  /* If we got here, then we didn't record enough events
   * to round-robin
   */
  return (initial_pos);

}

int playbackRecordEvent (ENGINE_EVENT e)
{

  playback_t rec;               /* The record to write out */

  /* Record the time when the event occurred */
  gettimeofday (&e.mix_time, NULL);

#if DEBUG_LEVEL & DBG_PLBK

  logMsg (DBG_PLBK, "Recording event at time: %lf, file offset: %d\n",
          TP_IN_FP_SECS (e.mix_time), ftell (stream));

#endif

  /* Create a record */
  rec.record = e;

  /* Have we written our maximum events?  */
  if (event_cnt != MAX_PLAYBACK_EVENTS) {

    if (fwrite (&rec, sizeof (playback_t), 1, stream) == 0) {

      logMsg (DBG_GEN, "Error writing to recording file: %s\n", strerror (errno));
      return 0;

    }

  } else {

    loopback_flag = 1;

    /* Else, reset our position, right after the header */
    if (fseek (stream, sizeof (struct playback_h), SEEK_SET) < 0) {

      logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
      return 0;

    }

    if (fwrite (&rec, sizeof (playback_t), 1, stream) == 0) {

      logMsg (DBG_GEN, "Error writing to recording file: %s\n", strerror (errno));
      return 0;

    }

  }

  fflush (stream);

  event_cnt++;
  return 1;

}

void playbackGo (char *start_t, char *end_t)
{

  struct timeval start, end, current, event_offset, time_offset;
  double plbk_offset, cur_time_offset;
  long start_pos, end_pos;
  playback_t rec;
  char *time_format = PLAYBACK_TIME_FORMAT;

  /* Check if we've been given a start time */
  if (start_t != NULL) {

    struct tm tm;

    /* We need to convert the ascii start and end times into
     * seconds since the epoch
     */
    memset (&tm, 0, sizeof (struct tm));
    strptime (start_t, time_format, &tm);
    start.tv_sec = mktime (&tm);
    start.tv_usec = 0;

#if DEBUG_LEVEL & DBG_PLBK
    logMsg (DBG_PLBK, "Converted start time is: %lf\n", TP_IN_FP_SECS (start));
#endif

    /* Now find the starting time */
    header.start_pos = playbackFindFirstOffset ();
    if ((start_pos = playbackFindTime (start, header.start_pos)) == 0) {

      logMsg (DBG_DEF,
              "Couldn't find start time in playback file. Playing from beginning.");
      start_pos = sizeof (struct playback_h);

    }

    /* Now check if we also have an end time */
    if (end_t != NULL) {

      memset (&tm, 0, sizeof (struct tm));
      strptime (end_t, time_format, &tm);
      end.tv_sec = mktime (&tm);
      end.tv_usec = 0;

#if DEBUG_LEVEL & DBG_PLBK
      logMsg (DBG_PLBK, "Converted end time is: %lf\n", TP_IN_FP_SECS (end));
#endif

      /* Check if there's an ending time */
      if ((end_pos = playbackFindTime (end, playbackFindFirstOffset ())) == 0) {

        /* Since we can't find the end time in the playback file, we want to
         * end at the end of the round robin in the file which is either right
         * after the header or the event just prior to the start position
         */
        end_pos = (header.start_pos == sizeof (struct playback_h))
                  ? sizeof (struct playback_h)
                  : start_pos - sizeof (playback_t);

      }
    }

    /* Now set ourselves at the start position to be sure we're there */
    if (fseek (stream, start_pos, SEEK_SET) < 0) {

      logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
      shutdown ();

    }
  } else {

    /* Otherwise, just play from the beginning */
    logMsg (DBG_DEF, "No start and end time given.\n");
    logMsg (DBG_DEF, "Starting playback from the earliest event in file...\n");

    /* Check if we last closed the file correctly */
    if (TP_IN_FP_SECS (header.end_t) != 0.0) {

      if (fseek (stream, header.start_pos, SEEK_SET) < 0) {

        logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
        shutdown ();

      }

    } else {

      /* The file wasn't closed correctly so we need to determine
       * where the starting position is in the round robin */
      if (fseek (stream, playbackFindFirstOffset (), SEEK_SET) < 0) {

        logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
        shutdown ();

      }

    }

    start_pos = ftell (stream);
    end_pos = 0;
  }

  /* Figure out time diff with respect to our current time */
  fread (&rec, sizeof (playback_t), 1, stream);
  event_offset = rec.record.mix_time;
  gettimeofday (&time_offset, NULL);
  fseek (stream, -sizeof (playback_t), SEEK_CUR);

#if DEBUG_LEVEL & DBG_PLBK

  logMsg (DBG_PLBK, "Calculated event offset: %lf and time offset: %lf...\n",
          TP_IN_FP_SECS (event_offset), TP_IN_FP_SECS (time_offset));

  logMsg (DBG_PLBK, "Expected start position: %ld and end position: %ld\n",
          start_pos, end_pos);

#endif

  /* Do the actual playback */
  do {

#if DEBUG_LEVEL & DBG_PLBK
    logMsg (DBG_DEF, "We're currently looking at position: %ld\n",
            ftell (stream));
#endif

    if (fread (&rec, sizeof (playback_t), 1, stream) == 0) {

      switch (errno) {

      case EINTR:

#if DEBUG_LEVEL & DBG_PLBK
        logMsg (DBG_PLBK, "Hit eof. Reseting to end of header...\n");
#endif
        fseek (stream, sizeof (struct playback_h), SEEK_SET);

        continue;

      default:

      {
        logMsg (DBG_GEN,
                "Error reading in event: %s. Attempting to continue...\n",
                strerror (errno));
        /* Attempting to continue */
      }

      }

    }

    gettimeofday (&current, NULL);
    plbk_offset = TP_IN_FP_SECS (rec.record.mix_time) - TP_IN_FP_SECS (
                    event_offset);
    cur_time_offset = TP_IN_FP_SECS (current) - TP_IN_FP_SECS (time_offset);

#if DEBUG_LEVEL & DBG_PLBK
    logMsg (DBG_PLBK, "Playback Event:\n");
    logMsg (DBG_PLBK, "\tmix in time:  [%lf]\n",
            TP_IN_FP_SECS (rec.record.mix_time));
    logMsg (DBG_PLBK, "\tcurrent time: [%lf]\n", TP_IN_FP_SECS (current));
    logMsg (DBG_PLBK, "\tmix offset:   [%lf]\n", plbk_offset);
    logMsg (DBG_PLBK, "\ttime offset:  [%lf]\n", cur_time_offset);
    logMsg (DBG_PLBK, "\tsleeping:     [%lf]\n", plbk_offset - cur_time_offset);
#endif

    /* Sleep our event offset if necessary */
    if (plbk_offset > cur_time_offset) {
      usleep ((unsigned long)((plbk_offset - cur_time_offset) * 1000000.0));
    }

    engineEnqueue (rec.record);

    event_cnt++;

  } while (ftell (stream) != end_pos && ftell (stream) != start_pos);

  /* Now that we're done playback, let's wait a bit for the next sound to play
   * and then shutdown */
  sleep (PLAYBACK_TRAIL_TIME);
  shutdown ();

}

long playbackFindTime (struct timeval t, long start_pos)
{

  playback_t rec;
  struct timeval time;

  if (fseek (stream, start_pos, SEEK_SET) < 0) {

    logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
    return 0;

  }

  do {

    fread (&rec, sizeof (playback_t), 1, stream);
    time = rec.record.mix_time;

    if (TP_IN_FP_SECS (time) >= TP_IN_FP_SECS (t)) {

      return (ftell (stream) - sizeof (playback_t));

    }

    /* Check if we need to round robing in front of the header */
    if (feof (stream)) {

      if (fseek (stream, sizeof (struct playback_h), SEEK_SET) < 0) {

        logMsg (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
        return 0;

      }

    }

  } while (ftell (stream) != start_pos);

  return 0;

}

int playbackFileShutdown (void)
{

  switch (mode) {

  case RECORD_MODE:

    /* Finish filling out the header and rewrite it to disk */
    header.written = event_cnt;
    gettimeofday (&header.end_t, NULL);

    /* At this point, either we're at the end of the file, or
     * we should currently be pointing at it */
    if (loopback_flag) {
      header.start_pos = ftell (stream);
    } else {
      header.start_pos = sizeof (struct playback_h);
    }

#if DEBUG_LEVEL & DBG_PLBK

    logMsg (DBG_PLBK, "On shutdown, the playback header is:\n");
    logMsg (DBG_PLBK, "\tmajor ver:      [%d]\n", header.major_ver);
    logMsg (DBG_PLBK, "\tminor ver:      [%d]\n", header.minor_ver);
    logMsg (DBG_PLBK, "\tmax events:     [%d]\n", header.max_events);
    logMsg (DBG_PLBK, "\tevents written: [%d]\n", header.written);
    logMsg (DBG_PLBK, "\tstart pos:      [%d]\n", header.start_pos);
    logMsg (DBG_PLBK, "\tstart time:     [%lf]\n", TP_IN_FP_SECS (header.start_t));
    logMsg (DBG_PLBK, "\tend time:       [%lf]\n", TP_IN_FP_SECS (header.end_t));

#endif

    /* Now seek to the start of the file and write out the header */
    if (fseek (stream, 0, SEEK_SET) < 0) {

      logMsg (DBG_GEN, "Error seeking in file: %s", strerror (errno));
      return 0;

    }

    fwrite (&header, sizeof (struct playback_h), 1, stream);
    fflush (stream);
    break;

  case PLAY_MODE:

    logMsg (DBG_DEF, "Finished playback. You just heard %d events.\n",
            event_cnt);
    break;

  default:

    logMsg (DBG_DEF, "Warning: peepd was in an invalid playback mode.");
    logMsg (DBG_DEF, "shutdown may not have been successful\n");
  }

}
