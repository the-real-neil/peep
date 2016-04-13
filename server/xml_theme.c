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
#include <stdlib.h>
#include <string.h>
#include <expat.h>

#include "xml.h"
#include "xml_theme.h"
#include "parser.h"
#include "engine.h"
#include "mixer.h"
#include "debug.h"

/* Translation table from the theme sound entries to the actual event
 * and state paths.
 */
static struct trans_table *trans_table = NULL;

int xmlParseTheme (char *xml_string, char *sound_path, int *event_cnt, int *state_cnt)
{

	XML_Parser parser;
	FIRST_PASS_INFO *first_info;
	SECOND_PASS_INFO *second_info;

	first_info = (FIRST_PASS_INFO *)calloc (sizeof (FIRST_PASS_INFO), 1);
	second_info = (SECOND_PASS_INFO *)calloc (sizeof (SECOND_PASS_INFO), 1);

	/* Set up the first pass to count the number of events and
	 * states in the theme file, as well as build thet translation
	 * table.
	 */
	parser = XML_ParserCreate (NULL);

	if (!parser) {

		log (DBG_GEN, "Couldn't create an XML parsing object: %s\n",
			 (char *)XML_ErrorString (XML_GetErrorCode (parser) ));
		return XML_PARSER_FAILURE;

	}

	/* Set the counting handlers */
	XML_SetElementHandler (parser, xmlParseFirstPassStart, xmlParseFirstPassEnd);
	XML_SetCharacterDataHandler (parser, xmlParseFirstPassChar);

	/* Set up data structure to pass */
	first_info->sound_path = sound_path;
	XML_SetUserData (parser, first_info);

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "Starting first pass of theme file...\n");
#endif

	if (!XML_Parse (parser, xml_string, strlen (xml_string), 1)) {

		log (DBG_GEN, "Uh Oh! There was an xml parsing error while parsing the xml configuration file:\n");
		log (DBG_GEN, "\tLine %d: %s\n", XML_GetCurrentLineNumber(parser), (char *)XML_ErrorString ( XML_GetErrorCode (parser) ));
		return XML_PARSER_FAILURE;

	}

	XML_ParserFree (parser);

	/* Perform the actual parse */
	parser = XML_ParserCreate (NULL);

	if (!parser) {

		log (DBG_GEN, "Couldn't create an XML parsing object: %s\n",
			 (char *)XML_ErrorString (XML_GetErrorCode (parser) ));
		return XML_PARSER_FAILURE;

	}
	/* Set the parsing handlers */
	XML_SetElementHandler (parser, xmlParseSecondPassStart, xmlParseSecondPassEnd);
	XML_SetCharacterDataHandler (parser, xmlParseSecondPassChar);

	/* Set up the data structure for the handlers */
	second_info->event_cnt = event_cnt;
	second_info->state_cnt = state_cnt;
	second_info->thresholds = first_info->thresholds;
	XML_SetUserData (parser, second_info);

#if DEBUG_LEVEL & DBG_SETUP
	log (DBG_SETUP, "Starting second pass of theme file...\n");
#endif

	if (!XML_Parse (parser, xml_string, strlen (xml_string), 1)) {

		log (DBG_GEN, "Uh Oh! There was an xml parsing error while parsing the xml configuration file:\n");
		log (DBG_GEN, "\tLine %d: %s\n", XML_GetCurrentLineNumber(parser), (char *)XML_ErrorString ( XML_GetErrorCode (parser) ));
		return XML_PARSER_FAILURE;

	}

	/* Clean up time */
	XML_ParserFree (parser);
	/* Free the translation table if any entries exist*/
	if (trans_table) {
		struct trans_table *ent, *next;

		for (ent = trans_table, next = ent->next;
		     ent; ent = next, next = ent->next)
			xmlThemeFreeTransEntry (ent);
	}
	if (first_info->current_tag)
		free (first_info->current_tag);
	free (first_info);

	if (second_info->current_tag)
		free (second_info->current_tag);
	if (second_info->thresholds)
		free (second_info->thresholds);
	free (second_info);

	return XML_PARSER_SUCCESS;

}

void xmlParseFirstPassStart (void *data, const XML_Char *tag_name,
							  const XML_Char **attribs)
{

	FIRST_PASS_INFO *info = data;

	info->current_tag = (char *)realloc (info->current_tag, strlen (tag_name) + 1);
	strcpy (info->current_tag, tag_name);

	if (!strcasecmp (tag_name, XML_SOUNDS_TOKEN))
		info->context = SOUNDS_CONTEXT;
	else if (info->context == SOUNDS_CONTEXT && !strcasecmp (tag_name, XML_SOUND_TOKEN)) {

		info->context = SOUND_CONTEXT;
		info->cur_ent = xmlThemeCreateTransEntry ();

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tExtracting sound definition:\n");
#endif

	}
	else if (!strcasecmp (tag_name, XML_STATES_TOKEN))
		info->context = STATE_CONTEXT;
	else if (info->context == STATE_CONTEXT && !strcasecmp (tag_name, XML_STATE_TOKEN)) {

		info->thresholds = (int *)realloc (info->thresholds, sizeof (int) * (info->states + 1));
		info->thresholds[info->states] = 0;

	}
	else if (info->context == STATE_CONTEXT && !strcasecmp (tag_name, XML_THRESHOLD_TOKEN))
		info->thresholds[info->states]++;

}

void xmlParseFirstPassEnd (void *data, const XML_Char *tag_name)
{

	FIRST_PASS_INFO *info = data;

	if (!strcasecmp (tag_name, XML_SOUNDS_TOKEN))
		info->context = NO_CONTEXT;
	else if (info->context == SOUND_CONTEXT && !strcasecmp (tag_name, XML_SOUND_TOKEN))
		info->context = SOUNDS_CONTEXT;
	else if (!strcasecmp (tag_name, XML_STATES_TOKEN))
		info->context = NO_CONTEXT;
	else if (!strcasecmp (tag_name, XML_STATE_TOKEN))
		info->states++;

}

void xmlParseFirstPassChar (void *data, const XML_Char *s, int len)
{

	FIRST_PASS_INFO *info = data;
	char *string = createXmlNormalizedString ((char *)s, len);

	if (string != NULL) {

		if (info->context == SOUND_CONTEXT) {

			if (!strcasecmp (info->current_tag, XML_NAME_TOKEN)) {

				info->cur_ent->name = (char *)malloc (strlen (string) + 1);
				strcpy (info->cur_ent->name, string);

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tName:        [%s]\n", string);
#endif

			}

#if DEBUG_LEVEL & DBG_SETUP
			if (!strcasecmp (info->current_tag, XML_CATEGORY_TOKEN)) {
				log (DBG_SETUP, "\t\tCategory:    [%s]\n", string);
				info->cur_ent->category = (char *)malloc (strlen (string) + 1);
				strcpy (info->cur_ent->category, string);
			}
			else if (!strcasecmp (info->current_tag, XML_TYPE_TOKEN)) {
				log (DBG_SETUP, "\t\tType:        [%s]\n", string);
				info->cur_ent->type = (char *)malloc (strlen (string) + 1);
				strcpy (info->cur_ent->type, string);
			}
			else if (!strcasecmp (info->current_tag, XML_FORMAT_TOKEN)) {
				log (DBG_SETUP, "\t\tFormat:      [%s]\n", string);
				info->cur_ent->format = (char *)malloc (strlen (string) + 1);
				strcpy (info->cur_ent->format, string);
			}
			else if (!strcasecmp (info->current_tag, XML_DESCRIPTION_TOKEN)) {
				log (DBG_SETUP, "\t\tDescription: [%s]\n", string);
				info->cur_ent->desc = (char *)malloc (strlen (string) + 1);
				strcpy (info->cur_ent->desc, string);
			}
#endif

			if (!strcasecmp (info->current_tag, XML_PATH_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tPath:        [%s]...\n", string);
#endif
				info->cur_ent->path = (char *)malloc (strlen (string) + strlen (info->sound_path) + 1);
				strcpy (info->cur_ent->path, info->sound_path);
				strcat (info->cur_ent->path, string);

			}

		}

	}

	freeXmlNormalizedString (string);
}

struct trans_table *xmlThemeCreateTransEntry (void)
{

	struct trans_table *ent = (struct trans_table *)calloc(sizeof (struct trans_table), 1);

	ent->next = trans_table;
	trans_table = ent;
	return ent;

}

char *xmlThemeLookupTransPath (char *name)
{

	char *path = NULL;
	struct trans_table *ent, *prev;

	for (ent = trans_table, prev = NULL; ent; prev = ent, ent = ent->next) {

		if (ent->name && !strcasecmp (ent->name, name)) {

			path = (char *)malloc (strlen (ent->path) + 1);
			strcpy (path, ent->path);

			/* Remove the entry from the list for speed. Also check
			 * if we've emptied the list.
			 */
			if (prev)
				prev->next = ent->next;
			else
				trans_table = NULL;
			xmlThemeFreeTransEntry (ent);
			break;

		}

	}

	return path;

}

void xmlThemeFreeTransEntry (struct trans_table *entry)
{

	/* Free all members of the structure */
	if (entry->name)
		free (entry->name);
	if (entry->category)
		free (entry->category);
	if (entry->type)
		free (entry->type);
	if (entry->format)
		free (entry->format);
	if (entry->desc)
		free (entry->desc);
	if (entry->path)
		free (entry->path);
	free (entry);

}

void xmlParseSecondPassStart (void *data, const XML_Char *tag_name,
							  const XML_Char **attribs)
{

	SECOND_PASS_INFO *info = data;
	int i;

	info->current_tag = (char *)realloc (info->current_tag, strlen (tag_name) + 1);
	strcpy (info->current_tag, tag_name);

	if (!strcasecmp (tag_name, XML_THEME_TOKEN)) {

		for (i = 0;  attribs[i] != NULL; i += 2) {

#if DEBUG_LEVEL & DBG_SETUP
			if (!strcasecmp (attribs[i], XML_NAME_TOKEN))
				log (DBG_SETUP, "\tTheme Name: [%s]\n", attribs[i+1]);
#endif

		}

	}
	else if (!strcasecmp (tag_name, XML_EVENTS_TOKEN)) {

		info->context = EVENT_CONTEXT;

	}
	else if (info->context == EVENT_CONTEXT) {

		if (!strcasecmp (tag_name, XML_EVENT_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tLoading Theme Event Sound:\n");
#endif

		}

	}
	else if (!strcasecmp (tag_name, XML_STATES_TOKEN)) {

		info->context = STATE_CONTEXT;

	}
	else if (info->context == STATE_CONTEXT) {

		if (!strcasecmp (tag_name, XML_STATE_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\tLoad Theme State Sound:\n");
			log (DBG_SETUP, "\t\tState has [%d] thresholds.\n", info->thresholds[info->thresh_index]);
#endif

			/* Allocate the state */
			mixerAllocNewState (*info->state_cnt, info->thresholds[info->thresh_index]);
			info->thresh_cnt = 0;

		}
		else if (!strcasecmp (tag_name, XML_THRESHOLD_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_SETUP, "\t\tAdding threshold...\n");
#endif

			info->context = THRESHOLD_CONTEXT;

		}

	}

}

void xmlParseSecondPassEnd (void *data, const XML_Char *tag_name)
{

	SECOND_PASS_INFO *info = data;

	if (info->context == EVENT_CONTEXT && !strcasecmp (tag_name, XML_EVENTS_TOKEN)) {

		info->context = NO_CONTEXT;

	}
	else if (info->context == EVENT_CONTEXT && !strcasecmp (tag_name, XML_EVENT_TOKEN)) {

		/* Check if we have all the necessary information to create the event entry */
		if (info->path == NULL || info->name == NULL) {

#if DEBUG_LEVEL & DBG_SETUP
			log (DBG_GEN, "\t\tFailed to load event sound:\n");
			log (DBG_GEN, "\t\t\tNo name identifying the event sound provided or unable to translate name to path.\n");
#endif

		}
		else {

			/* Note: this function increments info->event_cnt for us, since
			 * event_cnt is a pointer to the parser's global event count.
			 */
			if (!parserLoadEventSndDir (info->name, info->path)) {

				log (DBG_GEN, "Error loading sounds from: %s\n", info->path);
				return;

			}

		}

		if (info->path)
			free (info->path);
		info->path = NULL;

		if (info->name)
			free (info->name);
		info->name = NULL;

	}
	else if (info->context == STATE_CONTEXT && !strcasecmp (tag_name, XML_STATES_TOKEN)) {

		STATE_ENTRY *entry = NULL;

		/* Check if we grabbed the name during the parse */
		if (info->name == NULL) {

#if DEBUG_LEVEL & DBG_GEN
			log (DBG_GEN, "Failed to load state sound:\n");
			log (DBG_GEN, "\tNo name identifying the state sound provided.\n");
#endif
			return;

		}

		/* Create the state sound entry in the sound table */
		entry = engineAllocStateEntry (*info->state_cnt);
		engineSoundTableInsertState (info->name, entry);

		free (info->name);
		info->name = NULL;

		(*info->state_cnt)++;
		info->context = NO_CONTEXT;

	}
	else if (info->context == STATE_CONTEXT && !strcasecmp (tag_name, XML_STATE_TOKEN)) {

		info->thresh_index++;

	}
	else if (info->context == THRESHOLD_CONTEXT && !strcasecmp (tag_name, XML_THRESHOLD_TOKEN)) {

		parserLoadStateSndDir (info->thresh_cnt, info->l_bound, info->h_bound, info->path, info->fade);

		free (info->path);
		info->path = NULL;

		info->thresh_cnt++;
		info->context = STATE_CONTEXT;

	}
	else if (!strcasecmp (tag_name, XML_THEME_TOKEN)) {

#if DEBUG_LEVEL & DBG_SETUP
		log (DBG_SETUP, "Finished Loading theme. Resuming configuration parsing...\n");
		log (DBG_SETUP, "\n");
#endif

	}

}

void xmlParseSecondPassChar (void *data, const XML_Char *s, int len)
{

	SECOND_PASS_INFO *info = data;
	char *string = createXmlNormalizedString ((char *)s, len);

	if (string != NULL) {

		if (info->context == EVENT_CONTEXT) {

			if (!strcasecmp (info->current_tag, XML_NAME_TOKEN)) {

				info->name = (char *)malloc (strlen (string) + 1);
				strcpy (info->name, string);
#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tName:            [%s]\n", string);
#endif

			}
			else if (!strcasecmp (info->current_tag, XML_SOUND_TOKEN)) {

				info->path = xmlThemeLookupTransPath (string);
#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tSound:           [%s]\n", string);
				if (info->path)
					log (DBG_SETUP, "\t\tTranslated ->    [%s]\n", info->path);
				else
					log (DBG_SETUP, "\t\tTranslated ->    [(null)]\n");
#endif

			}
#if DEBUG_LEVEL & DBG_SETUP
			else if (!strcasecmp (info->current_tag, XML_DESCRIPTION_TOKEN))
				log (DBG_SETUP, "\t\tDescription:     [%s]\n", string);
#endif


		}
		else if (info->context == STATE_CONTEXT) {

			if (!strcasecmp (info->current_tag, XML_NAME_TOKEN)) {

				info->name = (char *)malloc (strlen (string) + 1);
				strcpy (info->name, string);

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\tName:        [%s]\n", string);
#endif

			}
#if DEBUG_LEVEL & DBG_SETUP
			else if (!strcasecmp (info->current_tag, XML_DESCRIPTION_TOKEN))
				log (DBG_SETUP, "\t\tDescription: [%s]\n", string);
#endif

		}
		else if (info->context == THRESHOLD_CONTEXT) {

			if (!strcasecmp (info->current_tag, XML_LEVEL_TOKEN)) {

				/* First figure out lower bound */
				if (info->thresh_cnt > 0) {

					THRESHOLD *thresh = mixerGetThresholdEntry (*info->state_cnt, info->thresh_cnt - 1);
					info->l_bound = thresh->h_bound;

				}
				else
					info->l_bound = 0.0;

				info->h_bound = strtod (string, NULL);

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\t\tLower bound: [%lf]\n", info->l_bound);
				log (DBG_SETUP, "\t\t\tUpper bound: [%lf]\n", info->h_bound);
#endif

			}
			else if (!strcasecmp (info->current_tag, XML_FADE_TOKEN)) {

				info->fade = strtod (string, NULL);

#if DEBUG_LEVEL & DBG_SETUP
				log (DBG_SETUP, "\t\t\tFade: [%lf]\n", info->fade);
#endif

			}
			else if (!strcasecmp (info->current_tag, XML_SOUND_TOKEN)) {

				info->path = xmlThemeLookupTransPath (string);

#if DEBUG_LEVEL & DBG_SETUP
				if (info->path)
					log (DBG_SETUP, "\t\t\tAdding sound from: [%s]\n", info->path);
				else
					log (DBG_SETUP, "\t\t\tLookup on sound [%s] failed.\n", info->path);
#endif

			}

		}

	}

	freeXmlNormalizedString (string);

}
