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

#ifndef __PEEP_XML_THEME_H__
#define __PEEP_XML_THEME_H__

#define XML_PARSER_SUCCESS 1
#define XML_PARSER_FAILURE 0

#include <expat.h>

#define XML_SOUNDS_TOKEN      "sounds"
#define XML_SOUND_TOKEN       "sound"
#define XML_EVENTS_TOKEN      "events"
#define XML_EVENT_TOKEN       "event"
#define XML_STATES_TOKEN      "states"
#define XML_STATE_TOKEN       "state"
#define XML_THRESHOLD_TOKEN   "threshold"
#define XML_THEME_TOKEN       "theme"
#define XML_NAME_TOKEN        "name"
#define XML_CATEGORY_TOKEN    "category"
#define XML_TYPE_TOKEN        "type"
#define XML_FORMAT_TOKEN      "format"
#define XML_DESCRIPTION_TOKEN "description"
#define XML_PATH_TOKEN        "path"
#define XML_LEVEL_TOKEN       "level"
#define XML_FADE_TOKEN        "fade"

#define NO_CONTEXT           0x0
#define THEME_CONTEXT     (1 << 0)
#define SOUNDS_CONTEXT    (1 << 1)
#define SOUND_CONTEXT     (1 << 2)
#define EVENT_CONTEXT     (1 << 3)
#define STATE_CONTEXT     (1 << 4)
#define THRESHOLD_CONTEXT (1 << 5)

/* For Building a translation table from sound names to paths.
 * This is decided during the first pass. Note we use a list
 * for simplicity since speed is not an issue during
 * initialization. This can be changed to a hash table later.
 */
struct trans_table {
	char *name;               /* name of the sound */
	char *category;           /* sound category */
	char *type;               /* sound type */
	char *format;             /* sound format */
	char *desc;               /* sound description */
	char *path;               /* path in repository */

	struct trans_table *next; /* ptr to next entry */
};

/* Structure for performing counting of tags to determine size
 * of data structures before the actual parse.
 */
typedef struct {
	char *sound_path;         /* Path to repository */

	/* Parsing context */
	int context;              /* context identifier */
	char *current_tag;        /* current tag context */

	/* For counting state thresholds */
	int *thresholds;          /* index of threshold numbers per state */
	int states;               /* count of states in the file */

	/* Translation */
	struct trans_table *cur_ent; /* current entry */
} FIRST_PASS_INFO;

/* Structure for mainting state during parsing */
typedef struct {
	/* Global identifiers */
	int *event_cnt;     /* global count of parsed events */
	int *state_cnt;     /* global count of parsed states */

	/* Parsing context */
	char *current_tag;  /* current tag context */
	int context;        /* context identifier */

	/* For mapping sounds */
	char *name;         /* Name of the sound to be loaded */
	char *path;

	/* For loading state sounds only */
	int *thresholds;    /* index of threshold numbers per state */
	int thresh_cnt;     /* count of thresholds processed for current state */
	int thresh_index;   /* index into thresholds array */
	float l_bound;
	float h_bound;
	float fade;
} SECOND_PASS_INFO;

/* Creates an entry in the translation table from sound name to
 * path (from within the sounds section). Returns a pointer to
 * the newly created entry.
 */
struct trans_table *xmlThemeCreateTransEntry (void);

/* Translates a sound name to its corresponding path in the
 * repository.
 */
char *xmlThemeLookupTransPath (char *name);

/* Frees a translation table entry. */
void xmlThemeFreeTransEntry (struct trans_table *entry);

/* Parses an XML theme file, pointed to by the buffer in xml_string.
 * sound_path is a point to the path of the global repository.
 * event_cnt and state_cnt are points to the global count of events
 * and states loaded within the parser.
 */
int xmlParseTheme (char *xml_string, char *sound_path, int *event_cnt,
				   int *state_cnt);

/* Handler for counting the number of events/states and building
 * the sound name to path translation table.
 */
void xmlParseFirstPassStart (void *data, const XML_Char *tag_name,
								  const XML_Char **attribs);

/* Handles end tags during the first parse. */
void xmlParseFirstPassEnd (void *data, const XML_Char *tag_name);

/* Process character strings between tags during first pass */
void xmlParseFirstPassChar (void *data, const XML_Char *s, int len);

/* Handles start tags during the actual parse and loading of
 * sound files
 */
void xmlParseSecondPassStart (void *data, const XML_Char *tag_name,
							  const XML_Char **attribs);

/* Handles end tags during the actual parse */
void xmlParseSecondPassEnd (void *data, const XML_Char *tag_name);

/* Process character strings between tags second pass */
void xmlParseSecondPassChar (void *data, const XML_Char *s, int len);

#endif
