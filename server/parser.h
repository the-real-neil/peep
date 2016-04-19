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

#ifndef __PEEP_CONFIG_H__
#define __PEEP_CONFIG_H__

/* Parser error values */
#define PARSER_SUCCESS 1
#define PARSER_FAILURE -1
#define PARSER_GENERAL_ERROR -2
#define PARSER_CLASS_ERROR -3
#define PARSER_EVENT_ERROR -4
#define PARSER_STATE_ERROR -5
#define PARSER_IMPORT_ERROR -6
#define PARSER_THEME_ERROR -7
#define PARSER_ALREADY_ALLOC -8

/* Token function for separating input lines into tokens.
 * Meant to be fed to the parserTokenize () function as
 * a pointer. The remainder always points to the rest of
 * the input to parse and the token points to the token
 * just parsed
 */
struct tok {
  char *token;
  char *remainder;
};

#define PARSER_BUFFER_LEN 1024
#define PARSER_COMMENT '#'
static const char PARSER_PATH_SEP = '/';

/* Parser tokens */
#define PARSER_END_TOKEN "end"
#define PARSER_GENERAL_TOKEN "general"
#define PARSER_CLASS_TOKEN "class"
#define PARSER_CLIENT_TOKEN "client"
#define PARSER_EVENT_TOKEN "event"
#define PARSER_STATE_TOKEN "state"
#define PARSER_VERSION_TOKEN "version"
#define PARSER_SND_PATH_TOKEN "sound-path"
#define PARSER_PORT_TOKEN "port"
#define PARSER_SERVER_TOKEN "server"
#define PARSER_EVENT_NAME_TOKEN "name"
#define PARSER_EVENT_PATH_TOKEN "path"
#define PARSER_NAME_TOKEN "name"
#define PARSER_THRESHOLD_TOKEN "threshold"
#define PARSER_LEVEL_TOKEN "level"
#define PARSER_PATH_TOKEN "path"
#define PARSER_FADE_TOKEN "fade"
#define PARSER_IMPORT_TOKEN "import"
#define PARSER_THEME_TOKEN "theme"

/* For function definitions that have file arguments */
#include <stdio.h>

/* Initialize the parser */
void parserInit (void);

/* Destroy the parser and clean up */
void parserDestroy (void);

/* Parses a configuration file that follows the peep.conf format found at
 * the given file path. Returns the previously defined parser values.
 */
int parserParseConfigFile (char *file);

/* Searches the import stack for directories and tries to open files by
 * using the paths in the import stack. Return a valid file pointer
 * if the file was successfully opened, and NULL otherwise.
 */
FILE *parserImportConfig (char *file);

/* Determines whether we are the host that is gleaned from the configuration
 * file. We have three forms to check for: our ip address, our host name, and
 * our fqhn. Returns true if we are indeed that host, and false otherwise.
 */
int parserIsMyClass (char *host);

/* Parses the general section of the configuration file. Returns true if the
 * parsing was successful and false otherwise.
 */
int parserParseGeneral (FILE *config_file);

/* Parses the class section of a configuration file with the name pointed to
 * by "class". Returns true if parsing was successful and false otherwise.
 */
int parserParseClass (char *class, FILE *config_file);

/* Parses an event entry from the configuration file. Returns true if
 * successful or false otherwise.
 */
int parserParseEvent (FILE *config_file);

/* Loads all the events found within the sound directory pointed at by
 * "snd_path". Associates the sound loaded with "name". Returns true
 * if the sounds were successfully loaded and false otherwise.
 */
int parserLoadEventSndDir (char *name, char *snd_path);

/* Parses a state entry from the configuration file. Returns true if
 * succesful or false otherwise.
 */
int parserParseState (FILE *config_file);

/* Parses a threshold entry within a state entry, denominated by "thresh_cnt".
 * Returns true if the threshold entry was successfully parsed and false
 * otherwise.
 */
int parserParseThreshold (FILE *config_file, int thresh_cnt);

/* Loads all the state sounds found in the directory pointed at by "snd_path"
 * and sets the appropriate threshold information in the sbuffs. Also sets
 * the fade values initially. Returns true if the sounds were successfully
 * loaded and false otherwise.
 */
int parserLoadStateSndDir (int thresh_cnt, double l_bound, double h_bound,
                           char *snd_path, double fade);

/* Returns the name of the directory as part of a given path.
 * NULL is returned if there is no base directory name.
 * The return string should be dealloc'd with free () after usage.
 */
char *parserDirname (char *path);

/* Routines for managing the import stack */

/* Add a directory to the import stack */
int parserImportStackAdd (char *dir);

/* Need these definitions for the scandir function */
#include <sys/types.h>
#include <dirent.h>

/* Internal implementation of linux's scandir since scandir is BSD specific
 * but very useful. Interface is exactly the same except the select function
 * has been omitted.
 */
int parserScanDir (char *dir, struct dirent ***namelist,
                   int (*compar)(const void *, const void *));

/* Comparator function for the internal scandir */
int parserScanCompar (const void *v1, const void *v2);

/* Returns the size of the file found at path in bytes. Returns 0 if the size
 * cannot be determined.
 */
int parserGetFileSize (char *path);

/* Loads the sound file found at "path" into memory and sets the array_size
 * pointer. Returns a pointer to an array of the short sound data array.
 */
short *parserLoadSoundFile (size_t *array_size, char *path);

/* Parses the buffer pointed at by "remainder" and places the parsed
 * token into the "token" field. "Remainder" then points at the remaining
 * unparsed section of the original buffer. Sets the token structure passed
 * in by the *tok pointer. When there is no more buffer left to parse, the
 * "remainder" buffer is NULL.
 */
void parserTokenize (struct tok *buf);

#endif
