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
#include "notice.h"
#include "xml_notice.h"
#include "debug.h"

NOTICE *noticeCreateNotice (void)
{

	NOTICE *notice = (NOTICE *)calloc (sizeof (NOTICE), 1);

	/* Set integers to -1, indicating they haven't been set */
	notice->type = NOTICE_INTEGER_NOT_SET;
	notice->location = NOTICE_INTEGER_NOT_SET;
	notice->priority = NOTICE_INTEGER_NOT_SET;
	notice->volume = NOTICE_INTEGER_NOT_SET;
	notice->dither = NOTICE_INTEGER_NOT_SET;
	notice->metric = NOTICE_INTEGER_NOT_SET;

	return notice;

}

char *noticeCreateNoticeString (int len)
{

	return (char *)malloc (len + 1);

}

void noticeFreeNoticeString (char *string)
{

	free (string);

}

void noticeFreeNotice (NOTICE *notice)
{

	if (!notice)
		return;

	/* Free any of the string attributes if they were set */
	if (notice->host)
		noticeFreeNoticeString (notice->host);
	if (notice->client)
		noticeFreeNoticeString (notice->client);
	if (notice->sound)
		noticeFreeNoticeString (notice->sound);
	if (notice->data)
		noticeFreeNoticeString (notice->data);

	cfree (notice);

}

void processEventNoticeString (char *xml_string, NOTICE *notice)
{

	/* Sanity check */
	if (xml_string == NULL || notice == NULL) {

#if DEBUG_LEVEL & DBG_SRVR
		log (DBG_SRVR, "Attempted to process invalid notice: No XML or notice given.\n");
#endif
		return;

	}

	xmlParseClientEvent (xml_string, strlen (xml_string), notice);

}

void executeEventNoticeHook (MSG_STRING xml, NOTICE *notice)
{

#if DEBUG_LEVEL & DBG_HOOK
	{

		char *date = asctime (&notice->date);

		/* remove newline from date */
		date[strlen (date) - 1] = '\0';

		log (DBG_HOOK, "\n");
		log (DBG_HOOK, "Event notice hook executed!\n");
		log (DBG_HOOK, "XML notice was:\n");
		log (DBG_HOOK, "\tHost:     [%s]\n", notice->host);
		log (DBG_HOOK, "\tClient:   [%s]\n", notice->client);
		log (DBG_HOOK, "\tDate:     [%s]\n", date);
		log (DBG_HOOK, "\tData:     [%s]\n", notice->data);
		log (DBG_HOOK, "\tMetric:   [%d]\n", notice->metric);
		log (DBG_HOOK, "\tType:     [%d]\n", notice->type);
		log (DBG_HOOK, "\tSound:    [%s]\n", notice->sound);
		log (DBG_HOOK, "\tLocation: [%d]\n", notice->location);
		log (DBG_HOOK, "\tPriority: [%d]\n", notice->priority);
		log (DBG_HOOK, "\tVolume:   [%d]\n", notice->volume);
		log (DBG_HOOK, "\tDither:   [%d]\n", notice->dither);
		log (DBG_HOOK, "\tFlags:    [0x%04x]\n", notice->flags);

	}
#endif

}
