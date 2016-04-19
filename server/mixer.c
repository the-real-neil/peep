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
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "mixer.h"
#include "engine.h"
#include "mixer_queue.h"
#include "sound.h"
#include "thread.h"
#include "debug.h"

/* Event mixing buffers */
static EVENT_BUF *ebuffs;
static unsigned int no_ebuffs = 0;

/* State mixing buffers */
static STATE_BUF *sbuffs;
static unsigned int no_sbuffs = 0;

/* The count of states actually loaded */
static int mixer_loaded_states = 0;

/* Array of dynamic volumes, alloc'd to no_ebuffs and zero active
 * buffer count
 */
static double *dyn_mul;
static unsigned int dyn_buf_cnt = 0;

/* The lenth in signed 16 of a chunk of output of a given time
 * length
 */
static unsigned int chunk_size;

/* A chunk of raw data to be fed to the sound card */
static short *output;

/* A ptr to the sound card handle */
static void *handle;

/* mutex's:
 *   mlock - for modifying mixer datastructures
 */
pthread_mutex_t mlock;

/* Effect data structures */
static FADE_REC *lin_fade = NULL;


void mixerInit (void *device,
                unsigned int snd_port,
                unsigned int ebuf,
                unsigned int sbuf)
{

  /* Open the sound device and set the sound format to CD quality.
   * We use stereo, so use two channels */
  handle = soundInit (device, SOUND_WRONLY);

  soundSetFormat (handle, SIGNED_16_BIT, SAMPLE_RATE, STEREO, snd_port);

  /* Compute chunk size with the following formula for 1/2 sec of sound:
   * chunk_size=no_secs*freq. in kHz*no_bytes(8 or 16)/8*channels*1024
   * The output to the sound card is of length chunk_size.
   */
  chunk_size = 0.5 * (SAMPLE_RATE / 1000) * 2 * STEREO * 1024;
  output = calloc (chunk_size, *output);

  /* Initialize the event and state datastructures */
  no_ebuffs = ebuf;
  no_sbuffs = sbuf;

  ebuffs = calloc (no_ebuffs, sizeof *ebuffs);
  sbuffs = calloc (no_sbuffs, sizeof *sbuffs);

  /* Allocate the dynamic volume datastructures */
  dyn_mul = calloc (no_ebuffs, sizeof *dyn_mul);

  /* Seed random for playing state sounds */
  srand (1);

  /* Init the mutex locks */
  pthread_mutex_init (&mlock, NULL);

  /* Init effects */
  mixerFadeEffectInit ();

}

unsigned int mixerEBuffs (void)
{
  return no_ebuffs;
}

unsigned int mixerSBuffs (void)
{
  return no_sbuffs;
}


int mixerAddEvent (short *snd, unsigned int len,
                   double loc, int flags, unsigned int voice)
{

  ASSERT (voice >= 0 && voice < no_ebuffs)

  /* Is the voicing free? */
  if (ebuffs[voice].snd_buf != NULL) {
    return MIXER_CHAN_BUSY;
  }

#if DEBUG_LEVEL & DBG_MXR
  logMsg (DBG_MXR, "Sound added to channel [%d]:\n", voice);
  logMsg (DBG_MXR, "\tlength:      [%d]\n", len);
  logMsg (DBG_MXR, "\tstereo pos:  [%lf]\n", loc);
  logMsg (DBG_MXR, "\tfilter flag: [0x%03x]\n", flags);
#endif

  /* Lock the mixer datastructure mutex */
  threadLock (&mlock);

  ebuffs[voice].snd_buf = snd;
  ebuffs[voice].len = len;
  ebuffs[voice].stereo_pos = loc;
  ebuffs[voice].filter_flag = flags;

  dyn_buf_cnt++;
  dyn_mul[voice] = mixerDynVol ();

  threadUnlock (&mlock);

#if DEBUG_LEVEL & DBG_MXR
  logMsg (DBG_MXR, "\n");
  logMsg (DBG_MXR,
          "For channel [%d], using dynamic volume multiplier of [%lf].\n",
          voice, DYNAMIC_MULT (voice) );

  {
    int i, j, chans;
    char log_str[128];
    double sum = 0;

    logMsg (DBG_MXR, "Positions of currently playing sounds:\n");

    for (i = 0; i < no_ebuffs; i += 5) {

      memset (&log_str, 0, 128);
      strcpy (log_str, "\t");

      for (j = 0; i + j < no_ebuffs && j < 5; j++) {
        sprintf (log_str, "%s %2d(%6d)", log_str, i + j, ebuffs[i + j].pos);
      }

      logMsg (DBG_MXR, "%s\n", log_str);
    }

    for (i = 0, chans = 0; i < no_ebuffs; i++) {
      if (dyn_mul[i] != 0.0) {
        chans++;
      }
    }

    logMsg (DBG_MXR, "Total dynamic volume for [%d] channels is: %lf\n", chans,
            mixerDynTotVol());

  }
#endif

  return MIXER_SUCCESS;
}

void mixerRemoveEvent (unsigned int j)
{

  /* Lock the mixer datastructure mutex */
  threadLock (&mlock);

  ebuffs[j].snd_buf = NULL;
  ebuffs[j].len = ebuffs[j].pos = ebuffs[j].stereo_pos = 0;

  dyn_mul[j] = 0.0;
  dyn_buf_cnt--;

  threadUnlock (&mlock);

  /* This function will need to be looked at again once
   * the engine code has been rewritten */
  engineSchedulerInit (j, 0, 0, 0);

}

void mixerAddOldEvent (unsigned int j)
{
  struct timeval tp;
  double tp_conv;
  ENGINE_EVENT *old_event = mixerDequeue ();
  EVENT_ENTRY *entry = engineSoundTableDataRetrieve (old_event->event.sound);

  ASSERT (old_event != NULL && entry != NULL)

  gettimeofday (&tp, NULL);
  tp_conv = TP_IN_FP_SECS (tp);

  if (tp_conv - TP_IN_FP_SECS (old_event->mix_time)
      < (double)QUEUE_EXPIRED) {

    int next_snd = (unsigned int)
                   ((double)engineGetNoEventSnds (old_event->event.sound) * rand() /
                    (RAND_MAX + 1.0));

    /* Add the sound into the mixer for play */
    mixerAddEvent (engineGetEventSnd (old_event->event.sound, next_snd),
                   engineGetEventSndLen (old_event->event.sound, next_snd),
                   (double)old_event->event.loc / 255.0, old_event->event.flags,
                   j);

    /* Update mixer/engine timing structures */
    gettimeofday (&tp, NULL);
    tp_conv = TP_IN_FP_SECS (tp);

    ASSERT ((j + 1) >= 0 && (j + 1) < no_ebuffs)

    engineSchedulerInit (j, tp_conv, old_event->event.prior, tp_conv);

  }

  if (old_event->event.sound) {
    free(old_event->event.sound);
  }
  engineEngineEventFree (old_event);

}

int mixerAllocNewState (unsigned int state, int thresh_cnt)
{

  if (sbuffs[state].thresh != NULL) {
    return MIXER_ALREADY_ALLOC;
  }

  /* Lock the mixer datastructure mutex */
  threadLock (&mlock);

  sbuffs[state].thresh = calloc (thresh_cnt, sizeof *(sbuffs[state].thresh));
  sbuffs[state].thresh_cnt = thresh_cnt;
  sbuffs[state].stereo_pos = 0.5;

  threadUnlock (&mlock);

  if (sbuffs[state].thresh == NULL) {
    return MIXER_ALLOC_FAILED;
  }

  mixer_loaded_states++;

  return MIXER_SUCCESS;

}

int mixerAddStateThreshold (unsigned int state, unsigned thresh_index,
                            double l_bound, double h_bound,
                            unsigned int snd_cnt)
{
  THRESHOLD *ptr;

  if (thresh_index > sbuffs[state].thresh_cnt) {
    return MIXER_OUT_OF_BOUNDS;
  } else if (sbuffs[state].thresh == NULL) {
    return MIXER_NOT_YET_ALLOC;
  }

  threadLock (&mlock);

  ptr = &sbuffs[state].thresh[thresh_index];

  ptr->l_bound = l_bound;
  ptr->h_bound = h_bound;
  memset (&(ptr->state_snd), 0, sizeof (STATE_SND));
  ptr->state_snd.snd_buf = calloc (snd_cnt, sizeof *(ptr->state_snd.snd_buf));
  ptr->state_snd.len = calloc (snd_cnt, sizeof *(ptr->state_snd.len));
  ptr->state_snd.snd_cnt = snd_cnt;

  threadUnlock (&mlock);

  if (sbuffs[state].thresh[thresh_index].state_snd.snd_buf == NULL ||
      sbuffs[state].thresh[thresh_index].state_snd.len == NULL) {
    return MIXER_ALLOC_FAILED;
  }

  return MIXER_SUCCESS;

}

int mixerAddState (unsigned int state, unsigned int thresh_index,
                   unsigned int no_snd, short *sound, unsigned int len)
{

  if (thresh_index > sbuffs[state].thresh_cnt) {
    return MIXER_OUT_OF_BOUNDS;
  } else if (no_snd > sbuffs[state].thresh[thresh_index].state_snd.snd_cnt) {
    return MIXER_ALLOC_FAILED;
  } else if (sbuffs[state].thresh[thresh_index].state_snd.snd_buf[no_snd] !=
             NULL) {
    return MIXER_ALREADY_ALLOC;
  }

  /* Lock the mixer datastructure mutex */
  threadLock (&mlock);

  sbuffs[state].thresh[thresh_index].state_snd.snd_buf[no_snd] = sound;
  sbuffs[state].thresh[thresh_index].state_snd.len[no_snd] = len;

  threadUnlock (&mlock);

  return MIXER_SUCCESS;

}

int mixerGetNoLoadedStates (void)
{

  return mixer_loaded_states;

}

int mixerExistsStateSound (int index)
{

  return sbuffs[index].thresh != NULL;

}

int mixerLoadedStateSound (int index)
{

  return sbuffs[index].thresh[0].state_snd.snd_buf != NULL;

}

int mixerGetStateThreshIndex (unsigned int j)
{

  int i;
  double vol = sbuffs[j].vol;

  for (i = 0; i < sbuffs[j].thresh_cnt; i++) {

    if (vol >= sbuffs[j].thresh[i].l_bound &&
        vol <= sbuffs[j].thresh[i].h_bound) {
      return i;
    }

  }

}

void mixerSetStateSnd (unsigned int j, double vol,
                       double stereo, int flags)
{

  sbuffs[j].vol = vol;
  sbuffs[j].stereo_pos = stereo;
  sbuffs[j].filter_flag = flags;

}

STATE_SND *mixerGetStateSndPtr (int j, double vol)
{

  int i;
  int index = 0;

  /* Initial Sanity check */
  if (sbuffs[j].thresh == NULL) {
    return NULL;
  }

  for (i = 0; i < sbuffs[j].thresh_cnt; i++) {

    if (vol >= sbuffs[j].thresh[i].l_bound &&
        vol <= sbuffs[j].thresh[i].h_bound) {
      index = i;
    }

  }

  /* Now verify that we actually have sounds loaded */

  /* Thanks to jar <jar@jtan.com> for pointing out that we need to check if
   * we exceeded the thresh count, meaning no index was found.
   */
  if (sbuffs[j].thresh_cnt <= index ||
      sbuffs[j].thresh[index].state_snd.snd_buf == NULL) {
    return NULL;
  }

  return &sbuffs[j].thresh[index].state_snd;

}

THRESHOLD *mixerGetThresholdEntry (int j, int index)
{

  if (sbuffs == NULL || sbuffs[j].thresh == NULL
      || index >= sbuffs[j].thresh_cnt) {
    return NULL;
  }

  return &sbuffs[j].thresh[index];

}

void mixerInterrupt (unsigned int j)
{
  mixerRemoveEvent (j);
}

void mixer (void)
{

  int i, j;
  STATE_SND *state_snd = NULL;
  short eleft, eright, sleft, sright;

  /* Zero out the output buffer */
  memset (output, 0, sizeof (short) * chunk_size);

  /* Fill up a sound chunk */
  for (i = 0; i < chunk_size; i += STEREO) {

    for (j = 0; j < no_ebuffs; j++) {

      ASSERT (j >= 0 && j < no_ebuffs)

      /* Should we skip this sound? */
      if (ebuffs[j].snd_buf == NULL) {
        continue;
      }

      /* Calculate input based on the followed basic things:
       *   The buffer data, given the current position in the data.
       *   The dynamic volume multiplier, as well as the total event
       *   volume multiplier.
       *   The stereo position of the sound segment
       * Then, after each calculation, check if we need to apply
       * filters.
       */

      eleft = (short)((double)ebuffs[j].snd_buf[ebuffs[j].pos] *
                      DYNAMIC_MULT (j) * EVENT_MULT *
                      ebuffs[j].stereo_pos);

      eright = (short)((double)ebuffs[j].snd_buf[ebuffs[j].pos + 1] *
                       DYNAMIC_MULT (j) * EVENT_MULT *
                       (1.0 - ebuffs[j].stereo_pos));

      if (ebuffs[j].filter_flag) {

        eleft = mixerApplyEventFilters (eleft, ebuffs[j].pos, j);
        eright = mixerApplyEventFilters (eright, ebuffs[j].pos + 1, j);

      }

      /* Assign the processed data to the output */
      output[i] += eleft;
      output[i + 1] += eright;

      ebuffs[j].pos += STEREO;

      /* Check and see if a sound is done. If a sound is done, check and
       * see if there is a sound in the queue. If so, dequeue the sound and
       * check whether the time window has expired. If it's ok, then mix in
       * the sound
       */
      if (ebuffs[j].pos == ebuffs[j].len) {

        /* Clean up after the old sound */
        mixerRemoveEvent (j);

        if (!mixerQueueEmpty()) {
          mixerAddOldEvent (j);
        }

      }

    }

    /* Handle state mixing */
    for (j = 0; j < no_sbuffs; j++) {

      ASSERT (j >= 0 && j < no_sbuffs)

      state_snd = mixerGetStateSndPtr (j, sbuffs[j].vol);

      /* Check whether to bother adding a sound */
      if (sbuffs[j].vol == 0.0 || state_snd == NULL
          || state_snd->snd_buf[state_snd->snd_no] == NULL) {
        continue;
      } else {

        ASSERT (state_snd->snd_no >= 0 && state_snd->snd_no <= state_snd->snd_cnt)
        ASSERT (state_snd->pos >= 0 && (state_snd->len[state_snd->snd_no] == 0 ||
                                        state_snd->pos < state_snd->len[state_snd->snd_no]))
        ASSERT (state_snd->snd_buf != NULL
                && state_snd->snd_buf[state_snd->snd_no] != NULL)

        sleft = (short)(sbuffs[j].vol * sbuffs[j].stereo_pos *
                        STATE_MULT *
                        (double)state_snd->snd_buf[state_snd->snd_no][state_snd->pos]);

        sright = (short)(sbuffs[j].vol * (1.0 - sbuffs[j].stereo_pos) *
                         STATE_MULT *
                         (double)state_snd->snd_buf[state_snd->snd_no][state_snd->pos + 1]);

        /* Check whether to apply filters */
        if (sbuffs[j].filter_flag) {

          sleft = mixerApplyStateFilters (sleft, state_snd->pos, j);
          sright = mixerApplyStateFilters (sright, state_snd->pos + 1, j);

        }

        /* Assigned the processed data to the output */
        output[i] += sleft;
        output[i + 1] += sright;

        state_snd->pos += STEREO;

        /* Check if we've reached the end of the sound. Note that if
         * we have certain effects enabled, we may never execute this
         * code. Linear fading comes to mind. If we have, pick the next
         * sound segment to play at random.
         */
        if (state_snd->pos >= state_snd->len[state_snd->snd_no]) {

          state_snd->snd_no = mixerPickRndStateSnd(j);
          state_snd->pos = 0;

        }

      }

    }

  }

  /* Write out to sound card */
  soundPlayChunk (handle, (char *)output, chunk_size * sizeof(short));

}

void mixerShutdown (void)
{

  int i, j, k;

  /* Lock the mixer datastructures to be sure */
  threadLock (&mlock);

  /* Free up the event datastructures */
  free (ebuffs);

  /* In order to free up the state datastructures, we must
   * first loop through all thresholds and then through all
   * sound segments
   */
  for (i = 0; i < no_sbuffs; i++) {

    for (j = 0; j < sbuffs[i].thresh_cnt; j++) {

      for (k = 0; k < sbuffs[i].thresh[j].state_snd.snd_cnt; k++) {

        free (sbuffs[i].thresh[j].state_snd.snd_buf[k]);

      }

      free (sbuffs[i].thresh[j].state_snd.snd_buf);
      free (sbuffs[i].thresh[j].state_snd.len);

    }

    free (sbuffs[i].thresh);

  }

  free (sbuffs);
  free (dyn_mul);
  free (output);

  /* Free effects */
  mixerFadeEffectShutdown ();

  threadUnlock (&mlock);

  soundClose (handle);

}

unsigned int mixerPickRndStateSnd (int j)
{

  STATE_SND *state_snd = mixerGetStateSndPtr (j, sbuffs[j].vol);

  if (state_snd == NULL) {
    return 0;
  }

  return (unsigned int)((double)state_snd->snd_cnt * rand() /
                        (RAND_MAX + 1.0));

}

double mixerDynGMul (void)
{

  return (1.0 - (0.5 * ((double)(dyn_buf_cnt - 1) / (double)(no_ebuffs - 1))));

}

double mixerDynIMul (void)
{

  return (0.5 + ((double)(dyn_buf_cnt - 1) / (double)(no_ebuffs - 1)) * 0.5);

}

double mixerDynTotVol (void)
{

  double sum = 0.0;
  unsigned int i;

  for (i = 0; i < no_ebuffs; i++) {
    sum += DYNAMIC_MULT (i);
  }

  return sum;

}

double mixerDynVol (void)
{

  double tot_vol = mixerDynTotVol ();
  double im = mixerDynIMul ();
  double gm = mixerDynGMul ();

  return (im * gm * (1.0 - tot_vol));

}

short mixerApplyEventFilters (short data, unsigned int pos, unsigned int j)
{

  int i = 0;
  short result = data;

  for (i = 1; i != MAX_EVENT_FLAG; i = i << 1) {

    if (ebuffs[j].filter_flag & i) {

      switch (i) {

        /* to be added in the future */

      }

    }

  }

  return result;
}

short mixerApplyStateFilters (short data, unsigned int pos, unsigned int j)
{

  int i = 0;
  short result = data;

  for (i = 1; i != MAX_STATE_FLAG; i = i << 1) {

    if (sbuffs[j].filter_flag & i) {

      switch (i) {

      case STATE_LINEAR_FADE_FLAG:
        result = mixerFadeEffect (result, pos, j);
        break;

      }

    }

  }

  return result;

}

void mixerFadeEffectInit (void)
{

  lin_fade = calloc (no_sbuffs, sizeof *lin_fade);

}

int mixerSetFadeTime (unsigned int j, double time)
{

  /* Check that our j is valid */
  if (j <= no_sbuffs) {

    lin_fade[j].fade_time = time;
    return MIXER_SUCCESS;

  }

  return MIXER_ERROR;

}

double mixerGetFadeTime (unsigned int j)
{

  return lin_fade[j].fade_time;

}

short mixerFadeEffect (short data, unsigned int pos, unsigned int j)
{

  /* Check to see if we need to start fading sounds in and out. This is
   * set by the dither parameter, either in the configuration file or as
   * sent over the network.
   * We compute the time remaining to check and see if we've reached the
   * dither with
   *   state_snd->len[state_snd->snd_no]/STEREO/44100 # Seconds in whole sound
   *   - state_snd->pos/STEREO/44100                  # Seconds played so far
   *   < lin_fade[j].fade_time                        # Seconds to start fading
   *
   * We simplify and do the following comparison:
   *
   * state_snd->len[state_snd->snd_no] - state_snd->pos
   *   < lin_fade[j].fade_time * STEREO * SAMPLE_RATE
   *
   * As long as we're above the dither time, this effect does nothing. Else,
   * incorporate the fade.
   *
   * NOTE: the fade_pt is calculated as fade_pt + (fade_pt % 2). This is
   * because we require an EVEN fade point for our comparisons since the
   * "distance" left is always an even number because of stereo
   */

  double mul = 0.0, new = 0.0, old = 0.0, stereo = 0.0;
  STATE_SND *state_snd = mixerGetStateSndPtr (j, sbuffs[j].vol);
  int fade_pt = (int)(lin_fade[j].fade_time * (double)STEREO *
                      (double)SAMPLE_RATE);
  int remainder;

  if (!state_snd) {
    return 0;
  }

  /* Calculate the remaining number of bytes to be played */
  remainder  = state_snd->len[state_snd->snd_no] - pos;
  /* Make sure the fade point is on a stereo boundary */
  fade_pt += fade_pt % 2;

  /* Check if we're within the fade point. If we aren't, then no processing
   * is necessary.
   */
  if (remainder > fade_pt) {
    return data;
  } else {

    /* Check if we should start a new fade. If so, grab the next random sound
     * and begin mixing it in. Note that we need to record the threshold so
     * we can access the data directly.
     */
    if (remainder == fade_pt) {

      lin_fade[j].snd = mixerPickRndStateSnd (j);
      lin_fade[j].pos = state_snd->pos & 1; /* for correct stereo position */
      lin_fade[j].old_thresh = mixerGetStateThreshIndex (j);

      return data;

    } else {

      /* We want to fade linearly. From the first time to the last time
       * we enter this function, we know that:
       * 0 <= (state_snd->len[state_snd->snd_no] - pos) /
       *       (fade_pt + (fade_pt % 2)) < 1
       *
       * At the beginning, this value is 1 and then linearly moves to 0
       * while the new sound linearly moves from 0 to 1.
       *
       * Error handling for the proper dither parameters is done by the
       * engine and the event receiver as they get new events and examine
       * them.
       */
      mul = (double)(remainder) / (double)(fade_pt);
      old = (double)data * mul;

      /* Calculate the stereo position of the sound based on whether we're at an even
       * or odd position. Then process the new data just as the mixer would and multiply
       * it by the remainder from the multiplier.
       */
      stereo = (state_snd->pos % 2) ? (1.0 - sbuffs[j].stereo_pos) :
               sbuffs[j].stereo_pos;
      new = (double)
            sbuffs[j].thresh[lin_fade[j].old_thresh].state_snd.snd_buf[lin_fade[j].snd][lin_fade[j].pos]
            *
            stereo * sbuffs[j].vol * STATE_MULT * (1.0 - mul);

      lin_fade[j].pos++;

      /* Check if we've hit the end of the fade. If so, make the fade sound
       * our current sound
       */
      if (state_snd->pos + STEREO >= state_snd->len[state_snd->snd_no]) {

        state_snd = mixerGetStateSndPtr (j, sbuffs[j].vol);
        state_snd->snd_no = lin_fade[j].snd;
        state_snd->pos = lin_fade[j].pos;

      }

      return (short)(old + new);

    }

  }

}

void mixerFadeEffectShutdown (void)
{

  free (lin_fade);

}
