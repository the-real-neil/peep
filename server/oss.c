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

#ifdef __USING_OSS__

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include "sound.h"
#include "main.h"
#include "debug.h"

extern int errno;

/* Initializes the sound card. Here, the void snd_device is really
 * a pointer to a file path to the device to open. The function
 * returns a handle for the sound card
 */
void *soundInit (void *snd_device, int mode)
{

  char *dev = (char *)snd_device;
  static int audio_fd = 0;

  /* Sanity check */
  if (snd_device == NULL) {
    return NULL;
  }

  if ((audio_fd = open (dev, mode, O_NONBLOCK)) == -1) {

    /* Tell the world that opening the device failed */
    logMsg (DBG_GEN, "Couldn't open the sound device: %s\n", strerror (errno));
    shutDown ();

  }

  return &audio_fd;

}

/* Sets the paramters on the sound card for sampling rate, as well
 * as what channels (stereo or mono) to use for sound playback. The
 * function must be called everytime a different sound file type/sample
 * rate is used or when the sound must be played through a different
 * channel.
 * Returns true is success, false otherwise
 */
int soundSetFormat (void *handle, unsigned int format_type,
                    unsigned int rate, unsigned int chans,
                    unsigned int port)
{

#if defined (__LINUX__) || defined (__BSD__)

  /* Set sound format */
  if (ioctl (*(int *)handle, SNDCTL_DSP_SETFMT, &format_type) == -1) {

    logMsg (DBG_GEN, "Couldn't set sound format: %s\n", strerror (errno));
    return 0;

  }

  /* Select the number of channels */
  if (ioctl (*(int *)handle, SNDCTL_DSP_CHANNELS, &chans) == -1) {

    logMsg (DBG_GEN, "Couldn't set the number of sound channels: %s\n",
            strerror (errno));
    return 0;

  }

  /* Set the sample rate */
  if (ioctl (*(int *)handle, SNDCTL_DSP_SPEED, &rate) == -1) {

    logMsg (DBG_GEN, "Couldn't set the sample rate: %s\n", strerror (errno));
    return 0;

  }

#endif

#ifdef __SOLARIS__

  audio_info_t info;

  AUDIO_INITINFO (&info);

  info.play.encoding = format_type;
  info.play.channels = chans;
  info.play.sample_rate = rate;
  info.play.port = port; /* 1 = speaker, 2 = jack */

  if (ioctl (*(int *)handle, AUDIO_SETINFO, &info) == -1) {

    logMsg (DBG_GEN, "Couldn't set audio formatting: %s\n", strerror (errno));
    return 0;

  }

#endif

  /* Set the format with no error */
  return 1;

}

/* Gets information concerning the capabilities of the sound card.
 * Returns a ptr to an info structure if successful, otherwiswe NULL
 */
SNDCARD_INFO *soundGetInfo (void *handle)
{

  /* Currently unimplemented. Not sure if this is possible with
   * a device driver
   */
  return NULL;

}

/* Gets current status information about the sound buffer queue on the
 * sound card.
 * Returns a ptr to a status structure if successful, otherwise NULL
 */
SND_STATUS *soundGetStatus (void *handle)
{

  /* Currently unimplemented. Not sure if this is possible with
   * a device driver.
   */
  return NULL;

}

/* Sends a chunk of data to the sound card buffers to be played.
 * Note that soundSetFormat should be called prior to calling this
 * function or else formatting defaults are system dependent.
 */
ssize_t soundPlayChunk (void *handle, char *buf, unsigned int len)
{

  return write (*(int *)handle, buf, len);

}

/* Closes the sound handler */
void soundClose (void *handle)
{

  close (*(int *)handle);

}

#endif
