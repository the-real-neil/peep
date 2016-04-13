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
#include <signal.h>
#include <errno.h>

#include "main.h"
#include "cmdline.h"
#include "thread.h"
#include "server.h"
#include "engine.h"
#include "engine_queue.h"
#include "mixer.h"
#include "playback.h"
#include "debug.h"

static struct args_info args_info;
static FILE *pid_file = NULL;

/* The engine and mixer threads */
static pthread_t ethread = 0;
static pthread_t mthread = 0;

int main (int argc, char *argv[])
{

	/* Parse arguments */
	parseCmdlineOpts (argc, argv, &args_info);

	/* First initialize the debugging routines. If we weren't
	 * explicitly given the file to log to, use NULL, which
	 * defaults to the console
	 */
	if (args_info.logfile_given)
		logInit (args_info.logfile_arg);
	else
		logInit (NULL);

	/* Perform daemon init unless we're told otherwise */
	if (!args_info.nodaemon_given) {

		int pid = getpid ();
		char *pid_path = NULL;

		/* fork and detach */
		if (fork ()) {

			fclose (stdin);
			fclose (stdout);
			fclose (stderr);
			exit (0);

		}

		/* Create our pid file */
		if (args_info.pidfile_given)
			pid_path = args_info.pidfile_arg;
		else
			pid_path = DEFAULT_PID_PATH;

		if ((pid_file = fopen (pid_path, "w")) == NULL) {

			log (DBG_DEF, "Couldn't write pid to file %s: %s.\n", pid_path, strerror (errno));
			log (DBG_DEF, "Continuing anyway...\n");

		}
		else {

			/* Write our pid out to the file */
			fprintf (pid_file, "%d\n", pid_file);
			fflush (pid_file);
			fclose (pid_file);

		}

	}

	printGreeting ();

	/* Let the world know our debugging level */
	if (DEBUG_LEVEL & ~DBG_LOWEST) {

		char *str = "DEBUG_MODE ON! DEBUG SEVERITY:";

		switch (DEBUG_LEVEL) {

		case DBG_LOWER:
			log (DBG_GEN, "%s %s\n", str, "LOWER");
			break;

		case DBG_MEDIUM:
			log (DBG_GEN, "%s %s\n", str, "MEDIUM");
			break;

		case DBG_HIGHER:
			log (DBG_GEN, "%s %s\n", str, "HIGHER");
			break;

		case DBG_HIGHEST:
			log (DBG_GEN, "%s %s\n", str, "HIGHEST");
			break;

		case DBG_ALL_W_ASSERT:
			log (DBG_GEN, "%s %s\n", str, "HIGHEST WITH ASSERTIONS!");
			break;

		default:
			log (DBG_GEN, "%s %s\n", str, "UNKNOWN. WEIRD.");
			break;

		}

	}

	if (!args_info.voices_given)
		args_info.voices_arg = DEFAULT_MIXER_VOICES;

	log (DBG_DEF, "Mixing voices: %d\n", args_info.voices_arg);
	log (DBG_DEF, "Initializing the sound engine and mixer...\n");

#ifdef STATIC_VOLUME
	log (DBG_DEF, "Using static volume mixing...\n");
#endif
#ifdef DYNAMIC_VOLUME
	log (DBG_DEF, "Using dynamic volume mixing...\n");
#endif

	/* Perform some error checking to set arguments correctly */
	{

		/* Calculate how many state and event buffers to use */
		int no_sbuffs = (int)(DEFAULT_MIXER_VOICES * PERCENT_STATE_SOUNDS);
		int no_ebuffs = DEFAULT_MIXER_VOICES - no_sbuffs;

		if (!args_info.snd_device_given)
			args_info.snd_device_arg = DEFAULT_SND_DEVICE;

		if (!args_info.snd_port_given)
			args_info.snd_port_arg = DEFAULT_SND_JACK;

		/* Call the engine and mixer init routines */
		engineInit (args_info.snd_device_arg, args_info.snd_port_arg, no_ebuffs, no_sbuffs);

	}

	log (DBG_DEF, "Parsing configuration...\n");

	if (!args_info.config_given)
		args_info.config_arg = DEFAULT_CONFIG_PATH;

	{
		int parsed = 0;

		/* Initialize the parser */
		parserInit ();

		parsed = parserParseConfigFile (args_info.config_arg);

		/* Clean up the parser */
		parserDestroy ();


		if (parsed < 0) {

			log (DBG_GEN, "Error parsing peep configuration file...\n");
			shutDown ();

		}

	}

	log (DBG_DEF, "Finished configuration...\n");

	log (DBG_DEF, "Starting mixer thread...\n");

	startThread (doMixing, 0, &mthread);

	log (DBG_DEF, "Starting engine thread...\n");

	startThread (engineLoop, 0, &ethread);

	/* Check if playback mode is on and initialize if so */
	if (args_info.playback_mode_given || args_info.record_mode_given) {

		playback_mode_t mode;
		int x = 1;

		playbackModeOn (&x);

		/* Set our mode accordingly */
		if (args_info.record_mode_given)
			mode = RECORD_MODE;
		else if (args_info.playback_mode_given)
			mode = PLAY_MODE;

		playbackSetMode (&mode);

		/* Check if we should use the default playback file */
		if (!args_info.record_file_given)
			args_info.record_file_arg = DEFAULT_RECORD_FILE;

		log (DBG_DEF, "Initializing playback file...\n");

		if (!playbackFileInit (args_info.record_file_arg)) {

			log (DBG_DEF, "Uh Oh! Couldn't successfully initiliaze playback file! Giving up.\n");
			shutDown ();

		}

	}

	/* Now check if we're in playback mode. If we are, we don't want to start
	 * the server. Otherwise, we're all go with the server.
	 */
	if (playbackModeOn (NULL) && playbackSetMode (NULL) == PLAY_MODE) {

		log (DBG_DEF, "Entering playback mode...\n");

		if (!args_info.start_time_given)
			args_info.start_time_arg = NULL;

		if (!args_info.end_time_given)
			args_info.end_time_arg = NULL;

		playbackGo (args_info.start_time_arg, args_info.end_time_arg);

	}
	else {

		log (DBG_DEF, "Initializing server...\n");

		setSigHandlers ();

		if (playbackModeOn (NULL) && playbackSetMode (NULL) == RECORD_MODE)
			log (DBG_DEF, "Record mode on - Recording events to %s.\n", args_info.record_file_arg);

		/* Check whether the port has been set */
		if (!args_info.port_given)
			args_info.port_arg = DEFAULT_PORT;

		serverSetPort (args_info.port_arg);

		if (serverInit () < 0) {

			log (DBG_GEN, "Uh Oh! Error initializing server!\n");
			shutDown ();

		}

		log (DBG_DEF, "Starting server...\n");

		serverStart ();

	}

}

void printGreeting (void)
{

	log (DBG_DEF, "\n");
	log (DBG_DEF, "========================================================\n");
	log (DBG_DEF, "Welcome to Peep (The Network Auralizer).\n");
	log (DBG_DEF, "Copyright (C) 2000 Michael Gilfix.\n");
	log (DBG_DEF, "v%s\n", PACKAGE_VERSION);
	log (DBG_DEF, "=========================================================\n");
	log (DBG_DEF, "\n");

}

void setSigHandlers (void)
{

	sighandler_t handler;

	if ((handler = signal (SIGINT, handleSignal)) == SIG_ERR) {

		log (DBG_GEN, "Error registering SIGINT handler: %s\n", strerror (errno));
		shutDown ();

	}

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "Registered SIGINT handler.\n");
#endif

	if ((handler = signal (SIGHUP, handleSignal)) == SIG_ERR) {

		log (DBG_GEN, "Error registering SIGHUP handler: %s\n", strerror (errno));
		shutDown ();

	}

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "Registered SIGHUP handler.\n");
#endif

}

void *doMixing (void *data)
{

	threadBlockSignals ();

	while (1) {

		mixer ();

		/* Check if we've been cancelled */
		threadCheckCancelled ();

		/* wait between next mix */
		usleep (MIXER_THREAD_USLEEP);

	}

}

void *engineLoop (void *data)
{

	EVENT client_event;
	struct sound_entry *entry = NULL;

	threadBlockSignals ();

	while (1) {

		/* This call blocks due to the semaphore */
		client_event = engineDequeue ();

#if DEBUG_LEVEL & DBG_SRVR
		log (DBG_SRVR, "\n");
		log (DBG_SRVR, "Received Event:\n");
		log (DBG_SRVR, "\ttype:   %d\n", client_event.type);
		log (DBG_SRVR, "\tlen:    %d\n", client_event.sound_len);
		log (DBG_SRVR, "\tsound:  %s\n", client_event.sound);
		log (DBG_SRVR, "\tloc:    %d\n", client_event.loc);
		log (DBG_SRVR, "\tprior:  %d\n", client_event.prior);
		log (DBG_SRVR, "\tvol:    %d\n", client_event.vol);
		log (DBG_SRVR, "\tdither: %d\n", client_event.dither);
		log (DBG_SRVR, "\tflags:  0x%04x\n", client_event.flags);
		log (DBG_SRVR, "\n");
#endif

		/* Check if we have a valid event */
		entry = engineSoundTableRetrieve (client_event.sound);
		if (entry == NULL) {

#if DEBUG_LEVEL & DBG_SRVR
			log (DBG_SRVR, "Server does not have event [%s] in its sound table!\n", client_event.sound);
			log (DBG_SRVR, "Discarding....\n");
#endif

			continue;

		}
		else if (client_event.type != entry->type) {

#if DEBUG_LEVEL & DBG_SRVR
				log (DBG_SRVR, "Received invalid event type or type does not match sound table.\n");
#endif

			continue;

		}

		/* handle the event */
		engineIO (&client_event);

	}

}

void shutDown (void)
{

	handleSignal (SIGINT);

}

void handleSignal (int sig)
{

	log (DBG_DEF, "Performing shutdown...\n");

	if (ethread)
		threadKill (ethread);

	if (mthread)
		threadKill (mthread);


	/* cleanup */
	log (DBG_DEF, "Cleaning up engine...\n");
	engineShutdown ();

	log (DBG_DEF, "Cleaning up mixer...\n");
	mixerShutdown ();

	log (DBG_DEF, "Cleaning up server...\n");
	serverShutdown ();

	if (playbackModeOn (NULL)) {

		log (DBG_DEF, "Closing playback file...\n");
		playbackFileShutdown ();

	}

	log (DBG_DEF, "Exiting...\n");

	/* Close logging routines */
	logClose ();

	/* Check if we have a pid file to close and if so close and unlink it */
	if (args_info.pidfile_given) {

		if (unlink (args_info.pidfile_arg) < 0)
			perror ("Couldn't unlink pid file");

	}

	/* Check if we should reload or just exit */
	if (sig == SIGHUP) {

		/* reload code will go here */

	}
	else
		exit (0);

}
