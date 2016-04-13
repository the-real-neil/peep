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

#ifndef __PEEP_XML_NOTICE_H__
#define __PEEP_XML_NOTICE_H__

/* This function filters out all the garbage that can be produced while
 * expat processes a document. This function can easily be extended by
 * adding new characters to the switch statement below.
 * If after normalization, the string is empty, the function returns null.
 * IMPORTANT: This function returns a pointer to a malloc'd string. You MUST
 * call freeXmlNormlizedString () afterwards. Thus good programming practice
 * might mean that you use it during a declaration so you don't forget :)
 */
char *createXmlNormalizedString (char *s, int len);

/* Destroyed a string created with the normalizing function */
void freeXmlNormalizedString (char *s);

/* For definitions */
#include <expat.h>
#include "notice.h"

typedef struct {
	NOTICE *notice;
	XML_Parser parser;
	char *current_tag;
} CLIENT_PARSE_INFO;

/* Tags */
#define NOTICE_HOST_TAG         "host"
#define NOTICE_DATA_TAG         "data"
#define NOTICE_CLIENT_TAG       "client"
#define NOTICE_SOUND_TAG        "sound"
#define NOTICE_TYPE_TAG         "type"
#define NOTICE_LOCATION_TAG     "location"
#define NOTICE_PRIORITY_TAG     "priority"
#define NOTICE_VOLUME_TAG       "volume"
#define NOTICE_DITHER_TAG       "dither"
#define NOTICE_FLAGS_TAG        "flags"
#define NOTICE_DATE_TAG         "date"
#define NOTICE_METRIC_TAG       "metric"

/* Handler for parsing XML notice strings that are sent along with
 * regular Peep events
 */
void xmlParseClientEvent (char *xml_string, int len, NOTICE *notice);

/* The start tag handler used when parsing client notice events */
void xmlParseClientStart (void *data, const XML_Char *tag_name,
						  const XML_Char **attribs);

/* The end tag handler used when parsing client notice events */
void xmlParseClientEnd (void *data, const XML_Char *tag_name);

/* The handler that process character text between the XML tags
 * in xml events
 */
void xmlParseClientChar (void *data, const XML_Char *s, int len);

#endif
