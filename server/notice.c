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

#include <string.h>
#include "config.h"
#include "notice.h"
#include "xml_notice.h"
#include "debug.h"

NOTICE *noticeCreateNotice (void)
{

    NOTICE *notice = calloc (1, sizeof *notice);

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

    return malloc (len + 1);

}

void noticeFreeNoticeString (char *string)
{

    free (string);

}

void noticeFreeNotice (NOTICE *notice)
{

    if (!notice) {
        return;
    }

    /* Free any of the string attributes if they were set */
    if (notice->host) {
        noticeFreeNoticeString (notice->host);
    }
    if (notice->client) {
        noticeFreeNoticeString (notice->client);
    }
    if (notice->sound) {
        noticeFreeNoticeString (notice->sound);
    }
    if (notice->data) {
        noticeFreeNoticeString (notice->data);
    }

    free (notice);

}

void processEventNoticeString (char *xml_string, NOTICE *notice)
{

    /* Sanity check */
    if (xml_string == NULL || notice == NULL) {

#if DEBUG_LEVEL & DBG_SRVR
        logMsg (DBG_SRVR, "Attempted to process invalid notice: No XML or notice given.\n");
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

        logMsg (DBG_HOOK, "\n");
        logMsg (DBG_HOOK, "Event notice hook executed!\n");
        logMsg (DBG_HOOK, "XML notice was:\n");
        logMsg (DBG_HOOK, "\tHost:     [%s]\n", notice->host);
        logMsg (DBG_HOOK, "\tClient:   [%s]\n", notice->client);
        logMsg (DBG_HOOK, "\tDate:     [%s]\n", date);
        logMsg (DBG_HOOK, "\tData:     [%s]\n", notice->data);
        logMsg (DBG_HOOK, "\tMetric:   [%d]\n", notice->metric);
        logMsg (DBG_HOOK, "\tType:     [%d]\n", notice->type);
        logMsg (DBG_HOOK, "\tSound:    [%s]\n", notice->sound);
        logMsg (DBG_HOOK, "\tLocation: [%d]\n", notice->location);
        logMsg (DBG_HOOK, "\tPriority: [%d]\n", notice->priority);
        logMsg (DBG_HOOK, "\tVolume:   [%d]\n", notice->volume);
        logMsg (DBG_HOOK, "\tDither:   [%d]\n", notice->dither);
        logMsg (DBG_HOOK, "\tFlags:    [0x%04x]\n", notice->flags);

    }
#endif

}
