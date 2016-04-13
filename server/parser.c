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
#include <string.h>
#include <netdb.h>
#include <errno.h>

#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif

/* Will probably need to autoconf these */
#include <sys/stat.h>
#include <unistd.h>
#include <netinet/in.h>

#include "parser.h"
#include "engine.h"
#include "mixer.h"
#include "debug.h"
#include "main.h"

extern int errno;

static char *sound_path = NULL;
static int event_cnt = 0, state_cnt = 0;

/* For the import search stack */
static char **import_stack = NULL;

void parserInit (void)
{

	/* Always make sure the current directory is in the import stack */
	if (!import_stack)
		parserImportStackAdd ("./");

}

void parserDestroy (void)
{

	int i = 0;

	if (import_stack) {

		for (i = 0; import_stack[i]; i++)
			free (import_stack[i]);

		free (import_stack);

	}

	if (sound_path)
		free (sound_path);

}

int parserParseConfigFile (char *file)
{

	FILE *config_file = NULL;
	char buffer[PARSER_BUFFER_LEN], *p;
	char *import_dir = NULL;
	struct tok tok;
	int success = 0;

	import_dir = parserDirname (file);

	if (import_dir) {

#if DEBUG_LEVEL & DBG_SETUP
		log (DBG_SETUP, "\tAdding directory [%s] to the import stack...\n", import_dir);
#endif

		/* Add the directory to the search location for imports */
		if (parserImportStackAdd (import_dir) == PARSER_FAILURE) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tError adding directory [%s] to import stack.\n", import_dir);
#endif

		}

		config_file = fopen (file, "r");
		free (import_dir);

	}
	else {

		config_file = parserImportConfig (file);

	}

	if (config_file == NULL) {

		log (DBG_GEN, "Couldn't find peep configuration file at: %s\n", file);
		success = PARSER_FAILURE;
		goto parser_failure;

	}

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "\tStarting parse of: [%s].\n", file);
#endif

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		/* Skip over # comments and blank lines */
		if (buffer[0] == PARSER_COMMENT || buffer[0] == '\n')
			continue;

		/* Are we at the end? */
		if (tok.token == NULL)
			break;

		if (!strcasecmp (tok.token, PARSER_GENERAL_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tParsing 'general' section...\n");
#endif

			if (parserParseGeneral (config_file) < 0) {

				log (DBG_GEN, "Error parsing general information...\n");
				success = PARSER_GENERAL_ERROR;
				goto parser_failure;

			}

		}


		if (!strcasecmp (tok.token, PARSER_CLASS_TOKEN)) {

			char *classname;

			parserTokenize (&tok);
			classname = tok.token;

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tParsing 'class' section for [%s]...\n", classname);
#endif

			if (parserParseClass (classname, config_file) < 0) {

				log (DBG_GEN, "Error parsing class: %s...\n", classname);
				success = PARSER_CLASS_ERROR;
				goto parser_failure;

			}

		}

		if (!strcasecmp (tok.token, PARSER_CLIENT_TOKEN)) {

			parserTokenize (&tok);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tSkipping section for client: [%s]...\n", tok.token);
#endif

			/* this is irrelevant to us, so let's skip the closing brace */
			while (fgets (buffer, sizeof (buffer), config_file)) {

				tok.remainder = buffer;
				parserTokenize (&tok);

				/* Make sure we hit an end client token */
				if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

					parserTokenize (&tok);

					if (!strcasecmp (tok.token, PARSER_CLIENT_TOKEN))
						break;

				}

			}

		}

		if (!strcasecmp (tok.token, PARSER_EVENT_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tLoading event:\n");
#endif

			if (parserParseEvent (config_file) < 0) {

				log (DBG_GEN, "Error parsing an event...\n");
				success = PARSER_EVENT_ERROR;
				goto parser_failure;

			}

		}

		if (!strcasecmp (tok.token, PARSER_STATE_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tLoading state:\n");
#endif

			if (parserParseState (config_file) < 0) {

				log (DBG_GEN, "Error parsing a state...\n");
				success = PARSER_STATE_ERROR;
				goto parser_failure;

			}

		}

		if (!strcasecmp (tok.token, PARSER_IMPORT_TOKEN)) {

			parserTokenize (&tok);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tImporting configuration file: [%s]\n", tok.token);
#endif

			if (parserParseConfigFile (tok.token) < 0) {

				log (DBG_GEN, "import failed! Aborting!\n");
				success = PARSER_IMPORT_ERROR;
				goto parser_failure;

			}

		}

		if (!strcasecmp (tok.token, PARSER_THEME_TOKEN)) {

			FILE *infile;
			char buf[PARSER_BUFFER_LEN];
			char *xml_string = NULL;

			parserTokenize (&tok);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\n");
			log (DBG_SETUP, "Loading theme file: [%s]...\n", tok.token);
#endif

			if ((infile = fopen (tok.token, "r")) == NULL) {

				log (DBG_GEN, "Error opening theme file %s: %s\n", tok.token, strerror (errno));
				success = PARSER_THEME_ERROR;
				goto parser_failure;

			}

			xml_string = (char *)malloc (parserGetFileSize (tok.token) + 1);
			fgets (buf, sizeof (buf), infile);
			strcpy (xml_string, buf);

			while (fgets (buf, sizeof (buf), infile))
				strcat (xml_string, buf);

			if (!xmlParseTheme (xml_string, sound_path, &event_cnt, &state_cnt)) {

				log (DBG_GEN, "Error parsing theme file: %s\n", tok.token);
				success = PARSER_THEME_ERROR;
				goto parser_failure;

			}

			fclose (infile);
			free (xml_string);

		}

	}

	/* If we've made it this far, let's succeed! */
	success = PARSER_SUCCESS;

parser_failure:
	if (config_file)
		fclose (config_file);
	return success;

}

FILE *parserImportConfig (char *file)
{

	char **dir_ptr = NULL;
	FILE *config_file = NULL;

	for (dir_ptr = import_stack; *dir_ptr; dir_ptr++) {

		char *import_path = (char *)malloc (strlen (file) + strlen (*dir_ptr) + sizeof (char) + 1);
		sprintf (import_path, "%s%c%s", *dir_ptr, PARSER_PATH_SEP, file);

		if ((config_file = fopen (import_path, "r")) != NULL) {

			free (import_path);
			return config_file;

		}

		free (import_path);

	}

	return NULL;

}

int parserIsMyClass (char *host)
{

	struct hostent *entry = NULL;
	struct in_addr ipaddr, listaddr;
	char localhost[1024];
	int i;

	/* Retreive host info */
	if (gethostname (localhost, 1024) < 0) {

		log (DBG_GEN, "Error retrieving hostname: %s\n", strerror (errno));
		return 0;

	}

	if ((entry = gethostbyname (localhost)) == NULL) {

		log (DBG_GEN, "Error getting host by name for %s: %s\n", localhost, strerror (errno));
		return 0;

	}

	/* Need to check three cases:
	 *   simple hostname
	 *   fqhn
	 *   ip address
	 */
	if (!strcasecmp (entry->h_name, host))
		return 1;

	for (i = 0; entry->h_aliases[i]; i++) {

		if (!strcasecmp (entry->h_aliases[i], host))
			return 1;

	}

	for (i = 0; entry->h_addr_list[i]; i++) {

		if (inet_aton (host, &ipaddr)) {

			if (ipaddr.s_addr == (unsigned long int)entry->h_addr_list[i])
				return 1;

		}

	}

	/* Otherwise, return false */
	return 0;

}

int parserParseGeneral (FILE *config_file)
{

	struct tok tok;
	char buffer[PARSER_BUFFER_LEN];

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		if (!strcasecmp (tok.token, PARSER_VERSION_TOKEN)) {

			int config_major, config_minor, config_release;
			int major, minor, release;
			char version[5];
			char *p = version;

			parserTokenize (&tok);

			/* Grab the file version number */
			config_major = atoi (strtok (tok.token, "."));
			config_minor = atoi (strtok (tok.token, "."));
			config_release = atoi (tok.token);

			/* Extract our own version number. Note we only copy 5 bytes
			 * since we limit ourselves to x.x.x format and can cut off
			 * any trailing '-' for other releases.
			 */
			strncpy (version, PACKAGE_VERSION, 5);
			version[5] = '\0';
			major = atoi (strtok (p, "."));
			minor = atoi (strtok (p, "."));
			release = atoi (p);

			if (major < config_major || minor < config_minor ||
				release < config_release) {

				log (DBG_GEN,
					 "Uh Oh! The config file is incompatible with the current version of peepd: %s\n",
					 VERSION);
				return PARSER_FAILURE;

			}

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tChecked configuration file of appropriate version.\n");
#endif

		}

		if (!strcasecmp (tok.token, PARSER_SND_PATH_TOKEN)) {

			parserTokenize (&tok);
			sound_path = (char *)calloc (sizeof (char), strlen (tok.token) + 2);
			strcpy (sound_path, tok.token);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tSet top-level sound path to: %s.\n", sound_path);
#endif

			/* Check if we need a trailing "/" */
			if (sound_path[strlen (sound_path)] != '/')
				strcat (sound_path, "/");

		}

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_GENERAL_TOKEN))
				return PARSER_SUCCESS;

		}

	}

	return PARSER_FAILURE;

}

int parserParseClass (char *class, FILE *config_file)
{

	char buffer[PARSER_BUFFER_LEN];
	struct tok tok;

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		/* skip comments */
		if (tok.token[0] == PARSER_COMMENT)
			continue;

		if (!strcasecmp (tok.token, PARSER_PORT_TOKEN)) {

			/* Loop through each possible tokens */
			while (1) {

				parserTokenize (&tok);

				if (tok.token[0] == PARSER_COMMENT)
					continue;

				if (tok.remainder == NULL)
					break;

				serverAddBroadcastPort (atoi (tok.token));

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tAdded broadcast port: [%d].\n", atoi (tok.token));
#endif

			}

		}

		if (!strcasecmp (tok.token, PARSER_SERVER_TOKEN)) {

			/* Loop through each possible server entry */
			while (1) {

				parserTokenize (&tok);

				/* Split the port then check the server name to see if we're it */
				{
					char *p = tok.token, *q = tok.token;

					while (*q != '\0') {

						if (*q == ':') {

							*q = '\0';

							if (parserIsMyClass (p)) {

								serverAddIDClass (class);
								serverSetPort (atoi (++q));
#if DEBUG_LEVEL & DBG_SETUP
								log (DBG_SETUP, "\t\tAdded class [%s] to identifier string.\n", class);
#endif
								break;

							}

						}

						q++;

					}

				}

				if (tok.remainder == NULL)
					break;

			}

		}

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_CLASS_TOKEN))
				return PARSER_SUCCESS;

		}

	}

	return PARSER_FAILURE;

}

int parserParseEvent (FILE *config_file)
{

	char buffer[PARSER_BUFFER_LEN];
	struct tok tok;
	char *name = NULL, *snd_path = NULL;

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		/* Skip leading comments */
		if (tok.token[0] == PARSER_COMMENT)
			continue;

		if (!strcasecmp (tok.token, PARSER_EVENT_NAME_TOKEN)) {

			parserTokenize (&tok);

			name = (char *)malloc (strlen (tok.token) + 1);
			strcpy (name, tok.token);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tName: [%s].\n", tok.token);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_EVENT_PATH_TOKEN)) {

			/* Build the path to the sound file */
			parserTokenize (&tok);
			snd_path = (char *)malloc (strlen (tok.token) + strlen (sound_path) + 1);
			strcpy (snd_path, sound_path);
			strcat (snd_path, tok.token);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tAdding sounds from: [%s]...\n", snd_path);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_EVENT_TOKEN)) {

				/* Check if we have sufficient information to load the
				 * event.
				 */
				if (name == NULL || snd_path == NULL) {

#if DEBUG_LEVEL & DBG_GEN
					log (DBG_GEN, "Error loading event:\n");
					log (DBG_GEN, "\tFailed to provide a name identifier or a valid path\n");
#endif

					goto event_failure;

				}

				/* Now load the actual sound */
				if (!parserLoadEventSndDir (name, snd_path)) {

					log (DBG_GEN, "Error loading sounds from: %s\n", snd_path);
					goto event_failure;

				}

				if (name)
					free (name);
				if (snd_path)
					free (snd_path);

				return PARSER_SUCCESS;

			}

		}

	}

event_failure:
	if (name)
		free (name);
	if (snd_path)
		free (snd_path);
	return PARSER_FAILURE;

}

int parserLoadEventSndDir (char *name, char *snd_path)
{

	char *path = NULL;
	short *sound = NULL;
	int snd_cnt = 0, length = 0, index = 0;
	struct dirent **namelist = NULL;
	EVENT_ENTRY *entry = NULL;

	if ((snd_cnt = parserScanDir (snd_path, &namelist, parserScanCompar)) < 0) {

		log (DBG_GEN, "Error scanning directory: %s\n", strerror (errno));
		return 0;

	}
	else {

		/* Set the number of event sounds and load each one. Note that
		 * we substract two from snd_cnt to account for "." and ".."
		 */
		entry = engineAllocEventEntry (snd_cnt - 2);

		while (snd_cnt--) {

			/* Skip the "." and ".." entries */
			if (!strcasecmp (namelist[snd_cnt]->d_name, "..") ||
				!strcasecmp (namelist[snd_cnt]->d_name, ".")) {

				free (namelist[snd_cnt]);
				continue;

			}

			path = (char *)malloc (strlen (snd_path) + strlen (namelist[snd_cnt]->d_name) + 2);
			sprintf (path, "%s/%s", snd_path, namelist[snd_cnt]->d_name);

			if ((sound = parserLoadSoundFile (&length, path)) == NULL) {

				/* Free remaining entries if they exist */
				while (snd_cnt--)
					free (namelist[snd_cnt]);

				free (path);
				return 0;

			}

			engineEventEntryAssignSnd (entry, index++, sound, length);

			free (path);
			free (namelist[snd_cnt]);

		}

		event_cnt++;
		free (namelist);

	}

	engineSoundTableInsertEvent (name, entry);

	return PARSER_SUCCESS;

}

int parserParseState (FILE *config_file)
{

	char buffer[PARSER_BUFFER_LEN];
	struct tok tok;
	long pos = 0;
	int thresh_cnt = 0, t_count = 0;
	char *name = NULL;
	STATE_ENTRY *entry = NULL;

	/* Count the number of thresholds with a quick look ahead */
	pos = ftell (config_file);

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		if (!strcasecmp (tok.token, PARSER_THRESHOLD_TOKEN))
			thresh_cnt++;

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_STATE_TOKEN)) {

				/* Reset our position and break */
				if (fseek (config_file, pos, SEEK_SET) < 0) {

					log (DBG_GEN, "Error seeking in file: %s\n", strerror (errno));
					goto state_failure;

				}

				break;

			}

		}

	}

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "\t\tState has [%d] thresholds.\n", thresh_cnt);
#endif

	/* Allocate the state */
	mixerAllocNewState (state_cnt, thresh_cnt);

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		/* Skip leading comments */
		if (tok.token[0] == PARSER_COMMENT)
			continue;

		if (!strcasecmp (tok.token, PARSER_NAME_TOKEN)) {

			parserTokenize (&tok);

			name = (char *)malloc (strlen (tok.token) + 1);
			strcpy (name, tok.token);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tName: [%s].\n", tok.token);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_THRESHOLD_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tAdding threshold...\n");
#endif

			if (!parserParseThreshold (config_file, t_count++))
				goto state_failure;

		}

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_STATE_TOKEN)) {

				if (name == NULL) {

#if DEBUG_LEVEL && DBG_GEN
					log (DBG_GEN, "Failed to load state sound:\n");
					log (DBG_GEN, "\tNo name identifying the state sound provided.\n");
#endif

					goto state_failure;

				}

				entry = engineAllocStateEntry (state_cnt);

				if (!entry)
					goto state_failure;

				engineSoundTableInsertState (name, entry);

				/* Now that we've successfully added the state snd, let's
				 * increment the entry index. It's crucial to do this at
				 * the end because we use the state_cnt through out the
				 * parse.
				 */
				state_cnt++;

				free (name);
				return PARSER_SUCCESS;

			}

		}

	}

state_failure:

	if (name)
		free (name);

	return PARSER_FAILURE;

}

int parserParseThreshold (FILE *config_file, int thresh_cnt)
{

	char buffer[PARSER_BUFFER_LEN];
	struct tok tok;
	double l_bound = 0.0, h_bound = 0.0, fade = 0.0;
	char *path = NULL;

	while (fgets (buffer, sizeof (buffer), config_file)) {

		tok.remainder = buffer;
		parserTokenize (&tok);

		/* Skip leading comments */
		if (tok.token[0] == PARSER_COMMENT)
			continue;

		if (!strcasecmp (tok.token, PARSER_LEVEL_TOKEN)) {

			parserTokenize (&tok);

			/* First figure out lower bound */
			if (thresh_cnt > 0) {

				THRESHOLD *thresh = mixerGetThresholdEntry (state_cnt, thresh_cnt - 1);
				l_bound = thresh->h_bound;

			}
			else
				l_bound = 0.0;

			h_bound = strtod (tok.token, NULL);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\t\tlower bound: [%lf].\n", l_bound);
			log (DBG_SETUP, "\t\t\tupper bound: [%lf].\n", h_bound);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_PATH_TOKEN)) {

			parserTokenize (&tok);

			path = (char *)malloc (strlen (tok.token) + strlen (sound_path) + 2);
			sprintf (path, "%s%s", sound_path, tok.token);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\t\tAdding sounds from: [%s].\n", path);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_FADE_TOKEN)) {

			parserTokenize (&tok);
			fade = strtod (tok.token, NULL);

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\t\tFade time: [%lf].\n", fade);
#endif

		}

		if (!strcasecmp (tok.token, PARSER_END_TOKEN)) {

			parserTokenize (&tok);

			if (!strcasecmp (tok.token, PARSER_THRESHOLD_TOKEN)) {

				/* Now that we've fully parsed the state, let's
				 * add the state to the mixer
				 */
				if (path != NULL && h_bound != 0.0) {

					int ret = parserLoadStateSndDir (thresh_cnt, l_bound,
													 h_bound, path, fade);

					free (path);

					if (!ret)
						return 0;
					else
						return PARSER_SUCCESS;

				}
				else {

					log (DBG_GEN, "Error attempted to add incorrect threshold entry.\n");
					log (DBG_GEN, "Bailing...\n");
					shutDown ();

				}

			}

		}

	}

	return PARSER_FAILURE;

}

int parserLoadStateSndDir (int thresh_cnt, double l_bound, double h_bound,
						   char *snd_path, double fade)
{

	short *sound = NULL;
	int snd_cnt = 0, length = 0, index = 0;
	struct dirent **namelist = NULL;
	char *path = NULL;

	if (state_cnt >= mixerSBuffs () ) {

		log (DBG_DEF, "Attempted to load one too many state sounds. Skipped: %d\n",
			 (state_cnt++) - mixerSBuffs ());
		return 0;

	}

	if ((snd_cnt = parserScanDir (snd_path, &namelist, parserScanCompar)) < 0) {

		log (DBG_GEN, "Error scanning directory: %s\n", strerror (errno));
		return 0;

	}
	else {

		/* Set the number of state sounds and load each one. Note that
		 * we subtract two from the state count because of ".." and "."
		 */
		mixerAddStateThreshold (state_cnt, thresh_cnt, l_bound, h_bound,
								snd_cnt - 2);

		while (snd_cnt--) {

			/* Skip the "." and ".." entries */
			if (!strcasecmp (namelist[snd_cnt]->d_name, "..") ||
				!strcasecmp (namelist[snd_cnt]->d_name, ".")) {

				free (namelist[snd_cnt]);
				continue;

			}

			path = (char *)malloc (strlen (snd_path) + strlen (namelist[snd_cnt]->d_name) + 2);
			sprintf (path, "%s/%s", snd_path, namelist[snd_cnt]->d_name);

			if ((sound = parserLoadSoundFile (&length, path)) == NULL) {

				/* Free remaining entries if they exist */
				while (snd_cnt--)
					free (namelist[snd_cnt]);

				free (path);
				return 0;

			}

			mixerAddState (state_cnt, thresh_cnt, index++, sound, length);

			free (path);
			free (namelist[snd_cnt]);

		}

		free (namelist);

	}

	/* Record the fade time for this state sound entry before finishing
	 * adding the sound
	 */
	mixerSetFadeTime (state_cnt, fade);

	return PARSER_SUCCESS;

}

char *parserDirname (char *path)
{

	int i = 0;
	char *copy = (char *)malloc (sizeof (char) * (strlen (path) + 1));

	strcpy (copy, path);

	for (i = strlen (copy); i >= 0; i--) {

		if (copy[i] == PARSER_PATH_SEP)
			break;

	}

	if (i < 0) {

		free (copy);
		return NULL;

	}

	copy[i] = '\0';
	return copy;

}

int parserImportStackAdd (char *dir)
{

	char *dir_copy = NULL;
	int i = 0;

	if (!import_stack) {

		import_stack = (char **)malloc (sizeof (char *));
		import_stack[0] = NULL;

	}

	for (i = 0; import_stack[i]; i++) {

		if (!strcasecmp (dir, import_stack[i]))
			return PARSER_ALREADY_ALLOC;

	}

	dir_copy = (char *)malloc ((strlen (dir) + 1) * sizeof (char));
	strcpy (dir_copy, dir);

	import_stack[i] = dir_copy;
	import_stack = (char **)realloc (import_stack, (++i + 1) * sizeof (char *));
	import_stack[i] = NULL;

	return PARSER_SUCCESS;

}

int parserScanDir (char *dir, struct dirent ***namelist,
				   int (*compar)(const void *, const void *))
{

	DIR *dfile = NULL;
	struct dirent *dir_ptr = NULL;
	struct dirent **list_ptr = NULL;
	unsigned int dir_size = 0;
	int items = 0;

	if ((dfile = opendir (dir)) == NULL)
		return -1;

	/* Create the namelist */
	while ((dir_ptr = readdir (dfile)) != NULL) {

		/* Make an internal copy since readdir overwrites future
		 * copies
		 */
		struct dirent *copy = (struct dirent *)malloc (sizeof (struct dirent));
		memcpy (copy, dir_ptr, sizeof (struct dirent));

		/* Yeah we could get fancier with allocation but we have a small number
		 * of files anyway
		 */
		items++;
		list_ptr = (struct dirent **)realloc (list_ptr, items * sizeof (struct dirent *));
		list_ptr[items - 1] = copy;

	}

	closedir (dfile);

	/* Sort the namelist */
	qsort (list_ptr, items, sizeof (struct dirent *), compar);

	*namelist = list_ptr;
	return items;

}

int parserScanCompar (const void *d1, const void *d2)
{

	return strcmp ((*(struct dirent **)d2)->d_name,
				   (*(struct dirent **)d1)->d_name);

}

int parserGetFileSize (char *path)
{

	struct stat file_stat;

	if (stat (path, &file_stat) < 0) {

		log (DBG_GEN, "Error stat-ing file to obtain file size: %s\n", strerror (errno));
		return -1;

	}
	else
		return (file_stat.st_size);

}

short *parserLoadSoundFile (unsigned int *array_size, char *path)
{

	FILE *infile = NULL;
	short *snd;
	int i;

	if ((infile = fopen (path, "r")) == NULL) {

		log (DBG_DEF, "Error opening file at %s: %s\n", path, strerror (errno));
		log (DBG_DEF, "All attempts to play that file will be ignored...\n");
		return NULL;

	}

	/* Length is the number of bytes / 2 for shorts */
	*array_size = parserGetFileSize (path) / 2;

	if ((snd = (short *)calloc (*array_size, sizeof (short))) == NULL) {

		log (DBG_DEF, "Error allocating memory: %s\n", strerror (errno));
		return NULL;

	}

	/* Load sound into memory */
	for (i = 0; i < *array_size; i++) {

		(void)fread (&(snd[i]), 1, sizeof (short), infile);

#ifdef WORDS_BIGENDIAN
		/* Switch the byte order as we load */
		snd[i] = ((snd[i] >> 8) & 0xff) | (snd[i] << 8);
#endif

#ifdef STATIC_VOLUME
		/* Divide the sound by the number of voices we're using
		 * to avoid sound overflow
		 */
		snd[i] / mixerEBuffs ();
#endif

	}

	fclose (infile);

	log (DBG_DEF, "\t\tLoaded [%s]: %d bytes.\n", path, (*array_size * 2));

	return snd;

}

void parserTokenize (struct tok *buf)
{

	char *p, *q;

	/* Skip leading white space */
	for (p = buf->remainder; isspace (*p); p++);

	for (q = p; q; q++) {

		if (isspace (*q) || *q == '\n') {

			*q = '\0';
			q++;

			/* Eat remainder */
			while (isspace (*q))
				q++;

			buf->remainder = q;
			buf->token = p;
			return;

		}

		if (*q == '\0') {

			buf->remainder = NULL;
			buf->token = p;
			return;

		}

	}

}
