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

#include <stdlib.h>
#include "xml.h"

char *createXmlNormalizedString (char *s, int len)
{

	char *str = (char *)malloc (len + 1);
	int i, j;

	for (i = 0, j = 0; i < len; i++) {

		switch (s[i]) {

		case '\n':
		case '\t':

			continue;

		case ' ':

			if (isalnum (s[i + 1])) {

				str[j++] = ' ';
				str[j++] = s[i + 1];
				i += 2;

			}
			else
				continue;

		default:

			str[j++] = s[i];
			break;

		}

	}

	str[j] = '\0';

	/* Check if string is empty */
	if (str[0] == '\0') {

		free (str);
		return NULL;

	}
	else
		return str;

}

void freeXmlNormalizedString (char *s)
{

	free (s);

}

