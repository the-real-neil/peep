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

#ifndef __PEEP_SOUND_H__
#define __PEEP_SOUND_H__

#include <sys/time.h>

#ifdef __USING_ALSA__
/* Include these headers for ALSA definitions */
#include <alsa/asoundlib.h>
#include <sound/asound.h>

#define AU_SOUND_FORMAT          SNDRV_PCM_FORMAT_MU_LAW
#define SIGNED_16_BIT            SNDRV_PCM_FORMAT_S16
#define SOUND_WRONLY             SNDRV_PCM_STREAM_PLAYBACK
#define SOUND_RDONLY             SNDRV_PCM_STREAM_CAPTURE
#define SOUND_RDWR               SNDRV_PCM_STREAM_DUPLEX
#endif /* __USING_ALSA__ */

#ifdef __USING_OSS__
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

/* Perhaps at some point, we can do some fancier footwork
 * with autoconf to ease the process of masking these assignments
 * as well as loading the appropriate headers. Note to self.
 */
#ifdef __LINUX__
#include <sys/ioctl.h>
#include <sys/soundcard.h>
#define AU_SOUND_FORMAT          AFMT_MU_LAW
#define SIGNED_16_BIT            AFMT_S16_LE
#define SOUND_WRONLY             O_WRONLY
#define SOUND_RDONLY             O_RDONLY
#define SOUND_RDWR               O_RDWR
#endif

#ifdef __BSD__
#include <sys/ioctl.h>
#include <soundcard.h>
#define AU_SOUND_FORMAT          AFMT_MU_LAW
#define SIGNED_16_BIT            AFMT_S16_LE
#define SOUND_WRONLY             O_WRONLY
#define SOUND_RDONLY             O_RDONLY
#define SOUND_RDWR               O_RDWR
#endif

#ifdef __SOLARIS__
#include <sys/audioio.h>
#define AU_SOUND_FORMAT          AUDIO_ENCODING_U_LAW
#define SIGNED_16_BIT            AUDIO_ENCODING_LINEAR
#define SOUND_WRONLY             O_WRONLY
#define SOUND_RDONLY             O_RDONLY
#define SOUND_RDWR               O_RDWR
#endif

#endif /* __USING_OSS__ */

/* Contains information about the capabilities of the sound card */
typedef struct
{
	unsigned int min_rate;  /* Min sampling rate supported */
	unsigned int max_rate;  /* Max rate supported by the card */
	unsigned int max_chans; /* Max number of voices on the soundcard */
	unsigned int buf_size;  /* Size of the playback buffer */
} SNDCARD_INFO;

/* Describes the current status of the sound card */
typedef struct
{
	unsigned int rate_limit;         /* playback rate - Hardware limits */
	int free_byte_count;             /* Count of bytes that could be written
	                                  * without blocking in the queue */
	int bytes_in_queue;              /* The number of bytes waititng to be played
	                                  * By the sound device */
	struct timeval future_play_time; /* Estimated time when the sample will play */
	struct timeval start_time;       /* Time when playing of the sample started */
} SND_STATUS;


/* Initializes the sound card to the specified mode and returns
 * a pointer to the device
 */
void *soundInit (void *snd_device, int mode);

/* Sets the sound format for sound playback */
int soundSetFormat (void *handle, unsigned int format_type,
					unsigned int rate, unsigned int chans,
					unsigned int port);

/* Fills out an info structure if the information is available.
 * This function isn't currently used but may be used in the future
 */
SNDCARD_INFO *soundGetInfo (void *handle);

/* Fills out a status structure if the information is available.
 * This function isn't currently used but may be used in the future
 */
SND_STATUS *soundGetStatus (void *handle);

/* Writes the contents of buf to the sound card */
ssize_t soundPlayChunk (void *handle, char *buf, unsigned int len);

/* Closes the sound device associated with handle */
void soundClose (void *handle);

#endif
