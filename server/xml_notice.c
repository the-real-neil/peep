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
#include "notice.h"
#include "xml.h"
#include "xml_notice.h"
#include "debug.h"

void xmlParseClientEvent (char *xml_string, int len, NOTICE *notice)
{

  XML_Parser parser;
  CLIENT_PARSE_INFO *parse_info;

  parse_info = calloc (1, sizeof *parse_info);

  parser = XML_ParserCreate (NULL);

  if (!parser) {

    logMsg (DBG_GEN, "Couldn't create an XML parsing object: %s\n",
            (char *)XML_ErrorString (XML_GetErrorCode (parser) ));
    free (parse_info);
    return;

  }

  /* Set handlers */
  XML_SetElementHandler (parser, xmlParseClientStart, xmlParseClientEnd);
  XML_SetCharacterDataHandler (parser, xmlParseClientChar);

  /* Set up data structures to pass */
  if (parse_info) {
    parse_info->notice = notice;
    parse_info->parser = parser;
    parse_info->current_tag = NULL;
  }

  XML_SetUserData (parser, parse_info);

  /* Now parse our xml string buffer. Note that we supply a final arguement
   * of 1 which tells the parser that this is the last bit of xml data that
   * it's going to parse, which is true for this instantation
   */
  if (! XML_Parse (parser, xml_string, len, 1) ) {

    logMsg (DBG_GEN, "Uh Oh! There was an XML parsing error: %s\n",
            (char *)XML_ErrorString ( XML_GetErrorCode (parser) ));
    /* Try to continue */

  }

  XML_ParserFree (parser);

  if (parse_info && parse_info->current_tag) {
    free (parse_info->current_tag);
  }
  free (parse_info);

}

void xmlParseClientStart (void *data, const XML_Char *tag_name,
                          const XML_Char **attribs)
{

  CLIENT_PARSE_INFO *client_info = (CLIENT_PARSE_INFO *)data;

  client_info->current_tag = (char *)realloc (client_info->current_tag,
                             strlen (tag_name) + 1);
  strcpy (client_info->current_tag, tag_name);

}

void xmlParseClientEnd (void *data, const XML_Char *tag_name)
{

  CLIENT_PARSE_INFO *client_info = (CLIENT_PARSE_INFO *)data;

}

void xmlParseClientChar (void *data, const XML_Char *s, int len)
{

  CLIENT_PARSE_INFO *client_info = (CLIENT_PARSE_INFO *)data;
  char *string = createXmlNormalizedString ((char *)s, len);

  /* Return if we couldn't create a normalized string */
  if (string == NULL) {
    return;
  }

  if (!strcasecmp (client_info->current_tag, NOTICE_HOST_TAG)) {

    client_info->notice->host = noticeCreateNoticeString (strlen (string));
    strcpy (client_info->notice->host, string);

  } else if (!strcasecmp (client_info->current_tag, NOTICE_DATA_TAG)) {

    client_info->notice->data = noticeCreateNoticeString (strlen (string));
    strcpy (client_info->notice->data, string);

  } else if (!strcasecmp (client_info->current_tag, NOTICE_CLIENT_TAG)) {

    client_info->notice->client = noticeCreateNoticeString (strlen (string));
    strcpy (client_info->notice->client, string);

  } else if (!strcasecmp (client_info->current_tag, NOTICE_SOUND_TAG)) {

    client_info->notice->sound = noticeCreateNoticeString (strlen (string));
    strcpy (client_info->notice->sound, string);

  } else if (!strcasecmp (client_info->current_tag, NOTICE_TYPE_TAG)) {
    client_info->notice->type = (unsigned char)atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_LOCATION_TAG)) {
    client_info->notice->location = (unsigned char)atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_PRIORITY_TAG)) {
    client_info->notice->priority = (unsigned char)atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_VOLUME_TAG)) {
    client_info->notice->volume = (unsigned char)atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_DITHER_TAG)) {
    client_info->notice->dither = (unsigned char)atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_FLAGS_TAG)) {
    client_info->notice->flags = atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_METRIC_TAG)) {
    client_info->notice->metric = atoi (string);
  } else if (!strcasecmp (client_info->current_tag, NOTICE_DATE_TAG)) {

    memset (&client_info->notice->date, 0, sizeof (struct tm));
    strptime (string, NOTICE_TIME_FORMAT, &client_info->notice->date);

  } else {

    /* We have an unsupported tag */
    logMsg (DBG_HOOK, "WARNING: Encountered unsupported XML tag: [%s]\n",
            client_info->current_tag);
    logMsg (DBG_HOOK, "WARNING: XML text is: [%s]\n", string);

  }

  freeXmlNormalizedString (string);

}
