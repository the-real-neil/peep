/*
PEEP: The Network Auralizer
Copyright (C) 2001 Michael Gilfix

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

#ifdef __USING_ALSA__

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include "sound.h"
#include "main.h"
#include "debug.h"

extern int errno;

static snd_pcm_t *s_handle = NULL;             /* sound handle */
static snd_pcm_hw_params_t *hwparams = NULL;   /* hardware parameters */
static char *audio_buffer = NULL;              /* internal sound buffer */
static ssize_t chunksize = 0;                  /* size of sound in buffer */
static int buffer_pos = 0;                     /* position in audio buffer */

/* A private prototype */
int allocateAudioBuffer (void *handle, unsigned int format_type,
						 unsigned int rate, unsigned int chans);

/* Initializes the sound card. Here, the void snd_device is really
 * a reference number to an alsa sound device. The function
 * returns a handle for the sound card
 */
void *soundInit (void *snd_device, int mode)
{

	int device = 0, err = 0;
	char pcm_name[32];

	/* Sanity check */
	if (snd_device == NULL)
		device = 0;
	else
		device = *(int *)snd_device;

	snprintf (pcm_name, 32, "hw:%d,0", device);

	/* Initialize the sound card */
	if ((err = snd_pcm_open (&s_handle, pcm_name, mode, 0)) < 0) {

		log (DBG_GEN, "Uh Oh! Couldn't open the ALSA audio device: %s\n",
			 snd_strerror (err));
		shutDown ();

	}

	/* Grab the hardware parameters */
	snd_pcm_hw_params_malloc (&hwparams);
	if ((err = snd_pcm_hw_params_any (s_handle, hwparams)) < 0) {

		log (DBG_GEN, "Uh Oh! Error retrieving hardware parameters: %s\n",
			 snd_strerror (err));
		snd_pcm_hw_params_free (hwparams);
		shutDown ();

	}

	return s_handle;

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

	int err;
	/* set the interleaved read/write format */
	int access = SND_PCM_ACCESS_RW_INTERLEAVED;

	if ((err = snd_pcm_hw_params_set_access(handle, hwparams, access)) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting hardware access: %s\n",
		     snd_strerror (err));
		return 0;

	}

	if ((err = snd_pcm_hw_params_set_format (handle, hwparams, format_type)) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting hardware format: %s\n",
		     snd_strerror (err));
		return 0;

	}

	if ((err = snd_pcm_hw_params_set_channels (handle, hwparams, chans)) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting number of hardware channels: %s\n",
			 snd_strerror (err));
		return 0;

	}

	if ((err = snd_pcm_hw_params_set_rate_near (handle, hwparams, rate, 0)) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting playback rate: %s\n",
		     snd_strerror (err));
		return 0;

	}

	if ((err = snd_pcm_hw_params (handle, hwparams)) < 0) {

		log (DBG_GEN, "Uh Oh! Error setting hw params for playback: %s\n",
		     snd_strerror (err));
		return 0;

	}

	/* Allocate the internal audio buffer based on the formatting info */
	if (!allocateAudioBuffer (handle, format_type, rate, chans)) {

		log (DBG_GEN, "Uh Oh! Error allocating internal audio buffer: %s\n",
			 snd_strerror (err));
		return 0;

	}

	/* Set the format with no error */
	return 1;

}

int allocateAudioBuffer (void *handle, unsigned int format_type,
						 unsigned int rate, unsigned int chans)
{

	snd_pcm_sframes_t frames;
	int bits_per_sample = 0, bits_per_frame = 0;

	frames = snd_pcm_hw_params_get_buffer_size (hwparams);
	chunksize = snd_pcm_frames_to_bytes (handle, frames);

	/* calculate the size of a sound buffer chunk according the size
	 * of the hardware sound buffer
	 */
	bits_per_sample = snd_pcm_format_physical_width (format_type);
	bits_per_frame = bits_per_sample * chans;
	chunksize *= bits_per_frame / 8 /* bits in a bytes */;

	/* Allocate audio buffer */
	if ((audio_buffer = (char *)malloc (chunksize)) == NULL) {

		log (DBG_GEN, "Uh Oh! Error allocating audio buffer: %s\n",
		     strerror (errno));
		return 0;

	}

	/* Success */
	return 1;

}

/* Gets information concerning the capabilities of the sound card.
 * Returns a ptr to an info structure if successful, otherwiswe NULL
 */
SNDCARD_INFO *soundGetInfo (void *handle)
{

	/* Currently unimplemented. */
	return NULL;

}

/* Gets current status information about the sound buffer queue on the
 * sound card.
 * Returns a ptr to a status structure if successful, otherwise NULL
 */
SND_STATUS *soundGetStatus (void *handle)
{

	/* Currently unimplemented. */
	return NULL;

}

/* Sends a chunk of data to the sound card buffers to be played. */
ssize_t soundPlayChunk (void *handle, char *data, unsigned int len)
{

	ssize_t written = 0;
	size_t data_size = len;
	int write_size = 0;
	snd_pcm_sframes_t frames, written_frames;

	/* sanity check that we have a handler */
	if (!handle)
		return 0;

	while (data_size > 0) {

		if (data_size <= chunksize - buffer_pos)
			write_size = data_size;
		else
			write_size = chunksize - buffer_pos;

		memcpy (audio_buffer + buffer_pos, data, write_size);

		/* Advance data pointer and reduce the data size
		 * as we make the write
		 */
		data += write_size;
		data_size -= write_size;
		buffer_pos += write_size;

		/* If we're filled out the audio buffer, let's write it
		 * out to the sound card
		 */
		if (buffer_pos == chunksize) {

			frames = snd_pcm_bytes_to_frames (handle, chunksize);
			written_frames = snd_pcm_writei (handle, audio_buffer, frames);
			written = snd_pcm_frames_to_bytes (handle, written_frames);

			if (written != chunksize)
				return written;

			/* Now that we've made the write, reset the buffer position */
			buffer_pos = 0;

		}

	}

	/* If we get here, then we've written everything. So return the
	 * original size
	 */
	return len;

}

/* Closes the sound handler */
void soundClose (void *handle)
{

	/* Free the audio buffer */
	if (audio_buffer)
		free (audio_buffer);

	/* Free up the hardware parameters datastructure */
	snd_pcm_hw_params_free (hwparams);

	/* Close the audio device */
	snd_pcm_close (handle);

}

#endif
