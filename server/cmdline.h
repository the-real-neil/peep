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

#ifndef __PEEP_CMDLINE_H__
#define __PEEP_CMDLINE_H__

/* In case we don't compile with autoconf */
#ifndef PACKAGE_NAME
#define PACKAGE_NAME ""
#endif
#ifndef PACKAGE_VERSION
#define PACKAGE_VERSION ""
#endif

struct args_info {
	int port_arg;             /* Server port to use */
	int voices_arg;           /* Number of mixing voices */
	int snd_port_arg;         /* Solaris sound port: 1 = speaker, 2 = jack */
	char *config_arg;         /* Path to configuration file */
	char *logfile_arg;        /* File to store logging info */
	char *pidfile_arg;        /* File to store server pid */
	char *record_file_arg;    /* Recording file to use */
	char *start_time_arg;     /* Starting date/time (playback only) */
	char *end_time_arg;       /* Ending date/time (playback only) */
	char *snd_device_arg;     /* The sound device to open */

	int help_given;           /* Whether help was given */
	int version_given;        /* Whether version was given */
	int port_given;           /* Whether port was given */
	int config_given;         /* Whether config was given */
	int voices_given;         /* Whether voices was given */
	int logfile_given;        /* Whether logfile was given */
	int pidfile_given;        /* Whether pidfile was given */
	int record_file_given;    /* Whether record-file was given */
	int start_time_given;     /* Whether start-time was given */
	int end_time_given;       /* Whether end-time was given */
	int snd_device_given;     /* Whether snd-device was given */
	int snd_port_given;       /* Whether snd-port was given */
	int playback_mode_given;  /* Whether playback-mode was given */
	int record_mode_given;    /* Whether record-mode was given */
	int nodaemon_given;       /* Whether nodaemon was given */
};

#define GET_INT_FROM_STRING_ARG(x, y, z) \
	if (!sscanf (x, "%d", &y)) \
		optError (z);

#define GET_STRING_ARG(x) \
	{ if (argv[1][2] != '\0') \
			x = (char *)&(argv[1][2]); \
		else { \
			argc--; argv++; \
			x = argv[1]; \
		} \
	}

#define GET_INT_ARG(x, y) \
	{ if (argv[1][2] != '\0') \
		if (!sscanf ((char *)&(argv[1][2]), "%d", &x)) \
			optError (y); \
	else { \
		argc--; argv++; \
		if (!sscanf (argv[1], "%d", &x)) \
			optError (y); \
		} \
	}

#define GET_NEXT_ARG \
	argc--; argv++;

void parseCmdlineOpts (int argc, char **argv, struct args_info *args_info);
void optError (char *string);
void printHelp (void);
void printVersion (void);

#endif
