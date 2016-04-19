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

#include "cmdline.h"

void parseCmdlineOpts (int argc, char **argv, struct args_info *args_info)
{

  char *string_ptr = NULL;
  char *args_ptr = NULL;

  /* Clear out the argument structure */
  memset (args_info, 0, sizeof (struct args_info));

  while (argc > 1) {

    /* If we don't have a proper argument leading with '-' */
    if (argv[1][0] != '-') {

      printHelp ();
      exit (1);

    }

    /* Deal with arguments of type '--', else deal with switches of
     * type '-'.
     */
    if (argv[1][1] == '-') {

      string_ptr = &(argv[1][2]);

      /* Find the '=' if it exists, otherwise argv_ptr is '\0' */
      for (args_ptr = string_ptr; *args_ptr != '\0'; args_ptr++) {

        if (*args_ptr == '=') {

          *args_ptr = '\0';
          args_ptr++;
          break;

        }

      }

      if (!strcmp (string_ptr, "help")) {

        args_info->help_given = 1;
        printHelp ();
        exit (0);

      }

      if (!strcmp (string_ptr, "version")) {

        args_info->version_given = 1;
        printVersion ();
        exit (0);

      }

      if (!strcmp (string_ptr, "port")) {

        if (args_info->port_given) {
          optError ("`--port' (`-p') option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --port=INT");
        }

        args_info->port_given = 1;
        GET_INT_FROM_STRING_ARG (args_ptr, args_info->port_arg,
                                 "Must specify argument: --port=INT")

      }

      if (!strcmp (string_ptr, "config")) {


        if (args_info->config_given) {
          optError ("`--config' (`-c') option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --config=STRING");
        }

        args_info->config_given = 1;
        args_info->config_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "voices")) {

        if (args_info->voices_given) {
          optError ("`--voices' (`-v') option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --voices=INT");
        }

        args_info->voices_given = 1;
        GET_INT_FROM_STRING_ARG (args_ptr, args_info->voices_arg,
                                 "Must specify argument: --voices=INT")

      }

      if (!strcmp (string_ptr, "logfile")) {

        if (args_info->logfile_given) {
          optError ("`--logfile' (`-l') option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --logfile=STRING");
        }

        args_info->logfile_given = 1;
        args_info->logfile_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "pidfile")) {

        if (args_info->pidfile_given) {
          optError ("`--pidfile' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --pidfile=STRING");
        }

        args_info->pidfile_given = 1;
        args_info->pidfile_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "record-file")) {

        if (args_info->record_file_given) {
          optError ("`--record-file' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --record-file=STRING");
        }

        args_info->record_file_given = 1;
        args_info->record_file_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "start-time")) {

        if (args_info->start_time_given) {
          optError ("`--start-time' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --start_time=STRING");
        }

        args_info->start_time_given = 1;
        args_info->start_time_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "end-time")) {

        if (args_info->end_time_given) {
          optError ("`--end-time' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --end-time=STRING");
        }

        args_info->end_time_given = 1;
        args_info->end_time_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "snd-device")) {

        if (args_info->snd_device_given) {
          optError ("`--snd-device' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --snd-device=STRING");
        }

        args_info->snd_device_given = 1;
        args_info->snd_device_arg = args_ptr;

      }

      if (!strcmp (string_ptr, "snd-port")) {

        if (args_info->snd_port_given) {
          optError ("`--snd-port' option given more than once");
        }
        if (!*args_ptr) {
          optError ("Must specify argument: --snd-port=INT");
        }

        args_info->snd_port_given = 1;
        GET_INT_FROM_STRING_ARG (args_ptr, args_info->snd_port_arg,
                                 "Must specify argument: --snd-port=INT")

      }

      if (!strcmp (string_ptr, "playback-mode")) {

        if (args_info->playback_mode_given) {
          optError ("`--playback-mode' option given more than once");
        }

        args_info->playback_mode_given = 1;

      }

      if (!strcmp (string_ptr, "record-mode")) {

        if (args_info->record_mode_given) {
          optError ("`--record-mode' option given more than once");
        }

        args_info->record_mode_given = 1;

      }

      if (!strcmp (string_ptr, "nodaemon")) {

        if (args_info->nodaemon_given) {
          optError ("`--nodaemon' option given more than once");
        }

        args_info->nodaemon_given = 1;

      }

    } else {

      switch (argv[1][1]) {

      case 'h':

        args_info->help_given = 1;
        printHelp ();
        exit (0);
        break;

      case 'V':

        args_info->version_given = 1;
        printVersion ();
        exit (0);
        break;

      case 'p':

        if (args_info->port_given) {
          optError ("`--port' (`-p') option given more than once");
        }

        args_info->port_given = 1;
        GET_INT_ARG (args_info->port_arg, "Must specify argument -pINT")
        break;

      case 'c':

        if (args_info->config_given) {
          optError ("`--config' ('c') option given more than once");
        }

        args_info->config_given = 1;
        GET_STRING_ARG (args_info->config_arg)
        break;

      case 'v':

        if (args_info->voices_given) {
          optError ("`--voices' ('v') option given more than once");
        }

        args_info->voices_given = 1;
        GET_INT_ARG (args_info->voices_arg, "Must specify argument -vINT")
        break;

      case 'l':

        if (args_info->logfile_given) {
          optError ("`--logfile' ('l') option given more than once");
        }

        args_info->logfile_given = 1;
        GET_STRING_ARG (args_info->logfile_arg)
        break;

      case 'n':

        if (args_info->nodaemon_given) {
          optError ("`--nodaemon' ('n') option given more than once");
        }

        args_info->nodaemon_given = 1;
        break;

      default:

        optError ("Invalid argument given.");
        break;

      }

    }

    GET_NEXT_ARG

  }

}

void optError (char *string)
{

  fprintf (stderr, "%s: %s\n", PACKAGE_NAME, string);
  printHelp ();
  exit (1);

}

void printHelp (void)
{

  printVersion ();
  printf ("\
Usage: %s [OPTIONS]...\n\
   -h         --help                Print help and exit\n\
   -V         --version             Print version and exit\n\
   -pINT      --port=INT            Server port to use\n\
   -cSTRING   --config=STRING       Path to configuration file\n\
   -vINT      --voices=INT          Number of mixing voices\n\
   -lSTRING   --logfile=STRING      File to store logging info\n\
              --pidfile=STRING      File to store server pid\n\
              --record-file=STRING  Recording file to use\n\
              --start-time=STRING   Starting date/time (playback only)\n\
              --end-time=STRING     Ending date/time (playback only)\n\
              --snd-device=STRING   The sound device to open\n\
              --snd-port=INT        Solaris sound port: 1 = speaker, 2 = jack\n\
              --playback-mode       Go into playback mode (requires recording file)\n\
              --record-mode         Record incoming events (requires recording file)\n\
   -n         --nodaemon            Don't run in daemon mode\n\
", PACKAGE_NAME);

}

void printVersion (void)
{

  printf ("%s - %s\n", PACKAGE_NAME, PACKAGE_VERSION);

}
