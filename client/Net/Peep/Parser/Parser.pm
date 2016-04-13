package Net::Peep::Parser;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Cwd;
use File::Basename;
use File::MMagic;
use Carp;
use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::Client::Notification;
use Net::Peep::Data::Conf;
use Net::Peep::Data::Conf::Class;
use Net::Peep::Data::Conf::Class::Server;
use Net::Peep::Data::Conf::Class::Servers;
use Net::Peep::Data::Conf::Classes;
use Net::Peep::Data::Conf::General;
use Net::Peep::Data::Event;
use Net::Peep::Data::Events;
use Net::Peep::Data::State;
use Net::Peep::Data::State::ThreshHold;
use Net::Peep::Data::States;
use Net::Peep::Notifier;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

# On spawning a new configuration file parser, we expect to get
# a reference to a hash that contains:
#   'config' => Which is a pointer to the configuration file
#   'app'    => The application for which to get the configuration
sub load {
	my $self = shift;
	my $conf = shift || confess "Cannot parse configuration file:  No configuration object found.";
	$self->conf($conf);
	confess "Peep couldn't find the configuration file [", $conf->getOption('config'), "]: $!" 
		unless -e $conf->getOption('config');
	$self->parseConfig();

} # end sub load

sub conf {

    my $self = shift;
    if (@_) { $self->{'CONF'} = shift; }
    return $self->{'CONF'};

} # end sub conf

sub parseConfig {

	my $self = shift;
	my $conf = $self->conf()->getOption('config');

	open FILE, $conf || confess "Could not open [$conf]:  $!";
	my @file = <FILE>;
	my $file = join '', @file;
	close FILE;
	my $magic = new File::MMagic;
	if ($magic->checktype_contents($file) =~ /ml/i) {
		# Parse the file as an XML file
		$self->conf()->deserialize($file);
	} else {
		while (my $line = shift @file) {
			my $msg = $line;
			chomp $msg;
			$msg = substr $msg, 0, 40;
			$self->logger()->debug(9,"Parsing [$conf] line [$msg ...]");
			next if $line =~ /^\s*#/;
			# version 0.4.3 had a standalone version tag
			$self->parseImport(\@file, $1)       if $line =~ /^\s*import (.*)/;
#			$self->parseVersion(\@file, $1)      if $line =~ /^\s*version (.*)/;
			$self->parseTheme($1)      if $line =~ /^\s*theme\s+(\S+)/;
			$self->parseGeneral(\@file, $1)      if $line =~ /^\s*general/;
			$self->parseNotification(\@file, $1) if $line =~ /^\s*notification/;
			$self->parseClass(\@file, $1)        if $line =~ /^\s*class (.*)/;
			$self->parseClient(\@file, $1)       if $line =~ /^\s*client (.*)/;
			$self->parseEvent(\@file, $1)        if $line =~ /^\s*event/;
			$self->parseState(\@file, $1)       if $line =~ /^\s*state/;
#			$self->parseHosts(\@file, $1)        if $line =~ /^\s*hosts/;
		}
	}

	return 1;

} # end sub parseConfig

sub parseImport {

	my $self = shift;
	my $file = shift || confess "file not found";
	my $import = shift;

	my $cwd = cwd();
	my $dir = dirname($self->conf()->getOption('config')) || undef;
	chdir $dir if defined($dir) and -d $dir;

	$import =~ s/^\s*//;
	$import =~ s/\s*$//;

	$self->logger()->debug(1,"Importing [$import] ...");
	if (-f $import) {
		if(open(IMPORT,$import)) {
			my @import = <IMPORT>;
			unshift @$file, @import;
			$self->logger()->debug(1,"\t[".scalar(@import)."] lines imported.");
			$self->logger()->debug(1,"\tDone.");
		} else {
			$self->logger()->debug(1,"\tCannot open [$import]:  $!");
		}
	} else {
		$self->logger()->debug(1,"\tCannot import [$import]:  The file does not exist.");
	}

	chdir $cwd if -d $cwd;

} # end sub parseImport

sub getThemes {

	my $self = shift;
	my $conf = $self->conf() || confess "Configuration object not found";
	my ($themes) = $conf->themes();
	if (not defined $themes) {
		$themes = new Net::Peep::Data::Themes;
		$conf->addToPool('themes',$themes);
	}
	return $themes;

} # end sub getClasses

sub parseTheme {

	my $self = shift;
	my $file = shift || confess "Cannot parse theme file:  No file name given.";
	
	my $cwd = cwd();
	my $dir = dirname($self->conf()->getOption('config')) || undef;
	chdir $dir if defined($dir) and -d $dir;

	$file =~ s/^\s*//;
	$file =~ s/\s*$//;

	confess "Cannot parse theme file [$file]:  The file cannot be found."
	    unless -e $file;

#	my $magic = new File::MMagic;
#       	confess "Cannot parse theme file [$file]:  Themes must be in XML format and [$file] is of type [".$magic->checktype_contents($file)."]."
#	    unless $magic->checktype_contents($file) =~ /ml/i;

	$self->logger()->debug(1,"Parsing theme file [$file] ...");

	my ($themes) = $self->getThemes();

	my $theme = new Net::Peep::Data::Theme;

	open(THEME,$file) || confess "Cannot open theme file [$file]:  $!";
	my $xml = join '', <THEME>;
	close THEME;

	$theme->deserialize($xml);

	$themes->addToPool('theme',$theme);

	$self->logger()->debug(1,"\tParsed theme file [$file]");

	chdir $cwd if -d $cwd;

} # end sub parseTheme

sub parseGeneral {

	my $self = shift;
	my $file = shift || confess "file not found";

	$self->logger()->debug(1,"Parsing general configuration information ...");

	my $general = new Net::Peep::Data::Conf::General;

	my ($version,$sound_path);

	while (my $line = shift @$file) {
		next if $line =~ /^\s*#/;
		if ($line =~ /^\s*end/) {
			my $general = new Net::Peep::Data::Conf::General;
			$general->version($version);
			$general->sound_path($sound_path);
			$self->conf()->addToPool('general',$general);
			return;
		} else {
			$line =~ /^\s*([\w-]+)\s+(.*)$/;
			my ($key, $value) = ($1,$2);
			# Remove any leading or trailing whitespace
			for ($key,$value) { s/^\s+//g; s/\s+$//g; }
			if ($key eq 'version') {
				$version = $value;
			} elsif ($key eq 'sound-path') {
				$sound_path = $value;
			} else {
				$self->logger()->log("Configuration option [$key] not recognized.");
			}
		}

	}

} # end sub parseGeneral

sub parseNotification {

	my $self = shift;
	my $file = shift || confess "file not found";

	$self->logger()->debug(1,"Parsing notification configuration information ...");

	while (my $line = shift @$file) {
		next if $line =~ /^\s*#/;
		if ($line =~ /^\s*end/) {
			return;
		} else {
			$line =~ /^\s*([\w-]+)\s+(.*)$/;
			my ($key, $value) = ($1,$2);
			# Remove any leading or trailing whitespace
			for ($key,$value) { s/^\s+//; s/\s+$//; }
			if ($key eq 'smtp-relays') {
				my (@relays) = split /[\s,]+/, $value;
				$self->logger()->debug(1,"\tFound SMTP relays [@relays]");
				@Net::Peep::Notifier::SMTP_RELAYS = @relays;
			} elsif ($key eq 'notification-interval') {
				confess "The notification interval must be an integer value!"
				    unless $value =~ /^\d+$/;
				$self->logger()->debug(1,"\tFound notification interval [$value]");
				$Net::Peep::Notifier::NOTIFICATION_INTERVAL = $value;
			} else {
				$self->logger()->log("\tNotification option [$key] not recognized.");
			}
		}

	}

	$self->logger()->debug(1,"\tNotification configuration information parsed.");

} # end sub parseNotification

sub getClasses {

	my $self = shift;
	my $conf = $self->conf() || confess "Configuration object not found";
	my ($classes) = $conf->classes();
	if (not defined $classes) {
		$classes = new Net::Peep::Data::Conf::Classes;
		$conf->addToPool('classes',$classes);
	}
	return $classes;

} # end sub getClasses

sub parseClass {
	my $self = shift;
	my $file      = shift || confess "file not found";
	my $classname = shift || confess "classname not found";

	$self->logger()->debug(1,"Parsing class [$classname] ...");

	my $classes = $self->getClasses();

	my $class = new Net::Peep::Data::Conf::Class;
	$class->name($classname);
	my ($port,@servers,@broadcasts);

	while (my $line = shift @$file) {
		if ($line =~ /^\s*end/) {
			if ($port && @servers) {
				$self->logger()->debug(1,"\tPort [$port] added.");
				$class->port($port);
				my $servers = new Net::Peep::Data::Conf::Class::Servers;
				$class->addToPool('servers',$servers);
				foreach my $server (@servers) {
					my ($name, $port) = split /:/, $server;
					my $object = new Net::Peep::Data::Conf::Class::Server;
					$object->name($name);
					$object->port($port);
					$servers->addToPool('server',$object);
					$self->logger()->debug(1,"\tServer [$name:$port] added.");
				}
				$classes->addToPool('class',$class);

			}
			$self->logger()->debug(1,"\tClass [$classname] parsed.");
			return;
		} else {

			$port = $1 if $line =~ /^\s*port (.*)/;
			push (@servers, split (/\s+/, $1) ) if $line =~ /^\s*server (.*)/;

		}


	}

} # end sub parseClass

sub getClients {

	my $self = shift;

	my $conf = $self->conf() || confess "Error:  Configuration object not found.";
	my ($clients) = $conf->clients();
	if (not defined $clients) {
		$clients = new Net::Peep::Data::Clients;
		$conf->addToPool('clients',$clients);
	}
	return $clients;

} # end sub getClients

sub parseClient {

	my $self = shift;

	my $file   = shift || confess "Cannot parse client:  File not found";
	my $name = shift || confess "Cannot parse client:  Client name not found";
	my %classes;

	$self->logger()->debug(1,"Parsing client [$name] ...");

	my $conf = $self->conf();

	my ($clients) = $self->getClients();
	# Let's figure out which classes we're part of and grab the
	# program's configuration
	my $client = new Net::Peep::Data::Client;
	$client->name($name);
	while (my $line = shift @$file) {

		if ($line =~ /^\s*end client $name/) {
			$self->logger()->debug(1,"\tClient [".$client->name()."] parsed.");
			$clients->addToPool('client',$client);
			return;
		}
		next if $line =~ /^\s*#/ or $line =~ /^\s*$/;

		if ($line =~ /^\s*class(.*)/) {
			my $class = $1;
			$class =~ s/^\s+//;
			$class =~ s/\s+$//;
			my @classes = split /\s+/, $class;
			foreach my $one (@classes) {
				$client->class($class);
			}
		}

		if ($line =~ /^\s*port (\d+)/) {
			my $port = $1;
			$port =~ s/\s+//g;
			$client->port($port);
			$self->logger()->debug(1,"\tPort [$port] set for client [".$client->name()."].");
		}

		if ($line =~ /^\s*default/) {
			my @default;

			while (my $line = shift @$file) {
				last if $line =~ /^\s*end default/;
				push @default, $line;
			}

			$self->parseClientDefault($client,@default);
		}

		# Note that config specifically looks for "end config" because
		# it may contain several starts and ends
		if ($line =~ /^\s*config/) {
			my @config;

			while (my $line = shift @$file) {
				last if $line =~ /^\s*end config/;
				push @config, $line;
			}

			$self->parseClientConfig($client,@config);
		}

		# Note that notification specifically looks for "end
		# notification" because it may contain several starts
		# and ends
		if ($line =~ /^\s*notification/) {
			my @notification;

			while (my $line = shift @$file) {
				last if $line =~ /^\s*end notification/;
				push @notification, $line;
			}

			$self->parseClientNotification($client,@notification);
		}

	}


} # end sub parseClient

sub getEvents {

	my $self = shift;
	my $conf = $self->conf() || confess "Configuration object not found";
	my ($events) = $conf->events();
	if (not defined $events) {
		$events = new Net::Peep::Data::Events;
		$conf->addToPool('events',$events);
	}
	return $events;

} # end sub getEvents

sub parseEvent {

	my $self = shift;
	my $file = shift || confess "Cannot parse events:  File not found.";

	$self->logger()->debug(1,"Parsing event ...");

	my $i = 0;
	# Skip right to the end
	my $event = new Net::Peep::Data::Event;
	while (my $line = shift @$file) {
		last if $line =~ /^\s*end/;
		next if $line =~ /^\s*#/;
		if ($line =~ /\s*name\s+(\S+)/) {
			my $name = $1;
			$event->name($name);
		} elsif ($line =~ /\s*path\s+(\S+)/) {
			my $path = $1;
			$event->path($path);
		} elsif ($line =~ /\s*length\s+(\S+)/) {
			my $length = $1;
			$event->length($length);
		} elsif ($line =~ /\s*description\s+(.+)/) {
			my $description = $1;
			$event->description($description);
		} else {
			# do nothing
		}

	}

	my $events = $self->getEvents();

	$events->addToPool('event',$event);

	$self->logger()->debug(1,"\tEvent [".$event->name()."] added.");

} # end sub parseEvent

sub parseClientConfig {

	my $self = shift;
	my $client = shift || confess "Cannot parse client configuration:  Client not identified.";
	my @text = @_;

	my $conf = $self->conf() || confess "Net::Peep::Conf object not found";

	my $configuration = join '', @text;
	$client->configuration($configuration);

} # end sub parseClientConfig

sub parseClientNotification {

	my $self = shift;
	my $client = shift || confess "Cannot parse client notification:  Client not identified.";
	my @text = @_;

	$self->logger()->debug(1,"\tParsing notification for client [".$client->name()."] ...");

	my $notification = new Net::Peep::Data::Client::Notification;
	while (my $line = shift @text) {
		next if $line =~ /^\s*#/;
		next if $line =~ /^\s*$/;

		if ($line =~ /^\s*(notification-hosts)\s+(.*)$/) {
			my ($key,$value) = ($1,$2);
			for ($key,$value) { s/^\s+//g; s/\s+$//g; }
			$notification->hosts($value);
			my (@hosts) = split /[\s,]+/, $value;
			$self->logger()->debug(1,"\t\tFound notification hosts [@hosts].");
			$Net::Peep::Notifier::NOTIFICATION_HOSTS{$client->name()} = [ @hosts ];
		} elsif ($line =~ /^\s*(notification-recipients)\s+(.*)$/) {
			my ($key,$value) = ($1,$2);
			for ($key,$value) { s/^\s+//g; s/\s+$//g; }
			$notification->recipients($value);
			my (@recipients) = split /[\s,]+/, $value;
			$self->logger()->debug(1,"\t\tFound notification recipients [@recipients].");
			$Net::Peep::Notifier::NOTIFICATION_RECIPIENTS{$client->name()} = [ @recipients ];
		} elsif ($line =~ /^\s*(notification-level)\s+(\S+)/) {
			my ($key,$value) = ($1,$2);
			for ($key,$value) { s/^\s+//g; s/\s+$//g; }
			$notification->level($value);
			$self->logger()->debug(1,"\t\tFound notification level [$value].");
			$Net::Peep::Notifier::NOTIFICATION_LEVEL{$client->name()} = $value;
		} else {
			$line =~ /^\s*(\w+)\s+(\S+)/;
			$self->logger()->debug(1,"\t\tClient notification option [$1] not recognized.");
		}
	}
	$client->addToPool('notification',$notification);

} # end sub parseClientNotification

# this method was deprecated with the move of client config parsing
# into the client objects

#sub parseClientEvents {
#
#	my $self = shift;
#	my $client = shift || confess "Cannot parse client events:  Client not identified.";
#	my @text = @_;
#
#	$self->logger()->debug(1,"\t\tParsing events for client [$client] ...");
#
#	my @version = $self->conf()->versionExists() 
#		? split /\./, $self->conf()->getVersion()
#			: ();
#
#	if (@version && $version[0] >= 0 && $version[1] >= 4 && $version[2] > 3) {
#
#		while (my $line = shift @text) {
#			next if $line =~ /^\s*#/;
#			last if $line =~ /^\s*end/;
#
#			my $name;
#			$line =~ /^\s*([\w-]+)\s+([\w-]+)\s+([a-zA-Z])\s+(\d+)\s+(\d+)\s+(\w+)\s+"(.*)"/;
#
#			my $clientEvent = {
#				'name' => $1,
#				'group' => $2,
#				'option-letter' => $3,
#				'location' => $4,
#				'priority' => $5,
#				'status' => $6,
#				'regex' => $7
#			};
#
#			$self->conf()->addClientEvent($client,$clientEvent);
#			$self->logger()->debug(1,"\t\t\tClient event [$1] added.");
#
#		}
#
#	} elsif (@version && $version[0] >= 0 && $version[1] >= 4 && $version[2] > 1) {
#
#		while (my $line = shift @text) {
#			next if $line =~ /^\s*#/;
#			last if $line =~ /^\s*end/;
#
#			my $name;
#			$line =~ /^\s*([\w-]+)\s+([\w-]+)\s+([a-zA-Z])\s+(\d+)\s+(\d+)\s+"(.*)"/;
#
#			my $clientEvent = {
#				'name' => $1,
#				'group' => $2,
#				'option-letter' => $3,
#				'location' => $4,
#				'priority' => $5,
#				'regex' => $6
#			};
#
#			$self->conf()->addClientEvent($client,$clientEvent);
#			$self->logger()->debug(1,"\t\t\tClient event [$1] added.");
#
#		}
#
#	} else {
#
#		while (my $line = shift @text) {
#			next if $line =~ /^\s*#/;
#			last if $line =~ /^\s*end/;
#
#			my $name;
#			$line =~ /([\w-]+)\s+([a-zA-Z])\s+(\d+)\s+(\d+)\s+"(.*)"/;
#
#			my $clientEvent = {
#				'name' => $1,
#				'option-letter' => $2,
#				'location' => $3,
#				'priority' => $4,
#				'regex' => $5
#			};
#
#			$self->conf()->addClientEvent($client,$clientEvent);
#			$self->logger()->debug(1,"\t\t\tClient event [$1] added.");
#
#		}
#
#	}
#
#	return @text;
#
#} # end sub parseClientEvents

# this method was deprecated with the move of client config parsing
# into the client objects

#sub parseClientHosts {
#
#	my $self = shift;
#	my $client = shift || confess "Cannot parse client hosts:  Client not identified.";
#	my @text = @_;
#
#	$self->logger()->debug(1,"\t\tParsing hosts for client [$client] ...");
#
#	while (my $line = shift @text) {
#		next if $line =~ /^\s*$/;
#		next if $line =~ /^\s*#/;
#		last if $line =~ /^\s*end/;
#
#		$line =~ /^\s*([\w\-\.]+)\s+([\w\-]+)\s+([\w\-]+)\s+([a-zA-Z])\s+(\d+)\s+(\d+)\s+(\w+)/;
#
#		my ($host,$name,$group,$letter,$location,$priority,$status) = 
#		    ($1,$2,$3,$4,$5,$6,$7);
#
#		my $clientHost = {
#		    host => $host,
#		    name => $name,
#		    group => $group,
#		    'option-letter' => $letter,
#		    location => $location,
#		    priority => $priority,
#		    status => $status
#		    };
#
#		$self->logger()->debug(1,"\t\t\tClient host [$host] added.") if
#		    $self->conf()->addClientHost($client,$clientHost);
#
#	}
#
#	return @text;
#
#} # end sub parseClientHosts

sub parseClientDefault {

    my $self = shift;
    my $client = shift || confess "Cannot parse client defaults:  Client not identified.";
    my @text = @_;

    $self->logger()->debug(1,"\tParsing defaults for client [".$client->name()."] ...");

    my $options = new Net::Peep::Data::Options;
    $client->addToPool('options',$options);

    while (my $line = shift @text) {
	next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
	if ($line =~ /^\s*([\w\-]+)\s+(\S+)/) {
	    my ($name,$value) = ($1,$2);
	    $self->logger()->debug(6,"Setting option [$name] to value [$value].");
	    my $option = new Net::Peep::Data::Option;
	    $option->name($name);
	    $option->value($value);
	    $options->addToPool('option',$option);
	}
    }

    $self->logger()->debug(1,"\t\tDone.");

    return @text;

} # end sub parseClientDefault

sub getStates {

	my $self = shift;
	my $conf = $self->conf() || confess "Configuration object not found";
	my ($states) = $conf->states();
	if (not defined $states) {
		$states = new Net::Peep::Data::States;
		$conf->addToPool('states',$states);
	}
	return $states;

} # end sub getStates

sub parseState {

	my $self = shift;

	my $file = shift || confess "Cannot parse states:  File not found.";

	$self->logger()->debug(1,"Parsing state ...");

	my $i = 0;
	my ($states) = $self->getStates();
	# Skip right to the end 
	my $state = new Net::Peep::Data::State;
	while (my $line = shift @$file) {
		last if $line =~ /^\s*end/;
		next if $line =~ /^\s*#/;

		if ($line =~ /^\s*name\s+(\S+)/) {
			my $name = $1;
			$state->name($name);
		} elsif ($line =~ /^\s*threshhold\s+(\S+)/) {
			my @threshhold;
			while (my $threshhold = shift @$file) {
				last if $line =~ /^\s*end/;
				push @threshhold, $threshhold;
			}
			$self->parseThreshHold($state,@threshhold);
		} else {
			# do nothing
		}
	}
	$states->addToPool('state',$state);
	$self->logger()->debug(1,"\tState [".$state->name()."] added.");

} # end sub parseState

sub parseThreshHold {

	my $self = shift;
	my $state = shift || confess "Net::Peep::Data::State object not found";
	my @threshhold = @_;

	my ($threshholds) = $self->getThresHolds($state);
	my $threshhold = new Net::Peep::Data::State::ThreshHold;

	while (my $line = shift @threshhold) {
		last if $line =~ /^\s*end/;
		next if $line =~ /^\s*#/;

		if ($line =~ /^\s*level\s+(\S+)/) {
			my $level = $1;
			$threshhold->level($1);
		} elsif ($line =~ /^\s*sound\s+(\S+)/) {
			my $sound = $1;
			$threshhold->sound($1);
		} elsif ($line =~ /^\s*fade\s+(\S+)/) {
			my $fade = $1;
			$threshhold->fade($1);
		} else {
			# do nothing
		}

	}
	$self->logger()->debug(1,"\tThreshhold with level [".$threshhold->level()."] added.");
	$threshholds->addToPool('threshhold',$threshhold);

} # end sub parseThreshHold

# returns a logging object
sub logger {
	my $self = shift;
	if ( ! exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
	return $self->{'__LOGGER'};
} # end sub logger

1;

__END__

=head1 NAME

Net::Peep::Parser - Perl extension for parsing configuration files for
Peep: The Network Auralizer.

=head1 SYNOPSIS

  use Net::Peep::Parser;
  my $parser = new Net::Peep::Parser;

  # load returns a Net::Peep::Conf object.  %options conform to
  # the specifications given in Getopt::Long

  my $conf = $parser->load(%options);

  # all of the configuration information in /etc/peep.conf
  # is now available through the observer methods in the
  # Net::Peep::Conf object

=head1 DESCRIPTION

Net::Peep::Parser parses a Peep configuration file and returns a
Net::Peep::Conf object whose accessors contain all the information
found in the configuration file.

Note that the Net::Peep::Parser class exists solely to allow the 0.5.x
configuration scheme to retain backwards-compatibility with 0.4.x
configuration files.

The 0.4.x style configurations will likely be deprecated as of the
0.6.x series.

As such, there are many kludgy parts of this class.  Apologies in
advance to anyone who has to work with it, but it will likey soon be a
throwaway.

=head2 EXPORT

None by default.

=head2 METHODS

  load(%options) - loads configuration information found in the file
  $options{'config'} .  Returns a Net::Peep::Conf object.

  parseConfig($config) - parses the configuration file $config.

  parseClass($filehandle,$classname) - parses the class definition
  section of a configuration file.

  parseClient($filehandle,$client) - parses the client definition
  section of a configuration file.

  parseEvents($filehandle) - parses the event definition section of a
  configuration file.

  parseState($filehandle) - parses the state definition section of a
  configuration file.

  parseClientEvents($filehandle) - parses the client event definition
  section of a configuration file.

  parseClientDefault($filehandle) - parses the client defaults section
  of a configuration file.

  logger() - returns a Net::Peep::Log object for logging and
  debugging.

  conf() - gets/sets a Net::Peep::Conf object for storing and
  retrieving configuration information.

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::BC, Net::Peep::Log, Net::Peep::Conf.

http://peep.sourceforge.net

=head1 CHANGE LOG

$Log: Parser.pm,v $
Revision 1.11  2002/06/13 07:01:58  starky
Themes are now (mostly) working.  Some work remains on the server side
before they can be fully tested.

Revision 1.10  2002/06/10 04:51:19  starky
Removed dependencies on Net::Peep::Data::Conf::Class::Broadcast and
Net::Peep::Data::Conf::Class::Broadcasts classes, which have been
deprecated due to changes in the configuration file.

Revision 1.9  2002/06/08 03:22:37  starky
With a variety of fixes, autodiscovery is (almost) working normally.

Revision 1.8  2002/05/23 07:40:17  starky
First commit of a working 0.5.x pinger.

Revision 1.7  2002/05/14 05:47:21  starky
An interim checking while getting sysmonitor and pinger in order.
Lots of stuff is still broken.  Hopefully all of the clients will
be converted and working real soon now ....

Revision 1.6  2002/03/13 02:11:26  starky
With this commit 100.t, a test script for text-based Peep configuration,
passes all tests.

Revision 1.5  2002/03/06 17:33:42  starky
Bugfixes too numerous to mention.

Revision 1.4  2002/02/26 06:01:10  starky
Test script 100.t now passes all tests.  Some work with the configuration
and parsing still needs to be done, as well as XML imports.  Progress
continues ....

Revision 1.3  2002/02/25 05:43:47  starky
First commit that builds the full client base for 0.5.x and passes
regression tests < 100.t.

Revision 1.2  2002/01/14 16:21:04  starky
Checking in (currently broken) code for the 0.5.x release for others
(e.g., Michael) to take a gander at.

Revision 1.1  2001/10/18 06:01:34  starky
Initial commit of client libraries for version 0.5.0.

Revision 1.6  2001/10/01 05:20:05  starky
Hopefully the final commit before release 0.4.4.  Tied up some minor
issues, did some beautification of the log messages, added some comments,
and made other minor changes.

Revision 1.5  2001/09/23 08:53:57  starky
The initial checkin of the 0.4.4 release candidate 1 clients.  The release
includes (but is not limited to):
o A new client:  pinger
o A greatly expanded sysmonitor client
o An API for creating custom clients
o Extensive documentation on creating custom clients
o Improved configuration file format
o E-mail notifications
Contact Collin at collin.starkweather@colorado with any questions.

Revision 1.4  2001/08/08 20:17:57  starky
Check in of code for the 0.4.3 client release.  Includes modifications
to allow for backwards-compatibility to Perl 5.00503 and a critical
bug fix to the 0.4.2 version of Net::Peep::Conf.

Revision 1.3  2001/08/06 04:20:36  starky
Fixed bug #447844.

Revision 1.2  2001/07/23 17:46:29  starky
Added versioning to the configuration file as well as the ability to
specify groups in addition to / as a replacement for event letters.
Also changed the Net::Peep::Parse namespace to Net::Peep::Parser.
(I don't know why I ever named an object by a verb!)

Revision 1.1  2001/07/23 16:18:35  starky
Changed the namespace of Net::Peep::Parse to Net::Peep::Parser.  (Why did
I ever create an object whose namespace was a verb anyway?!?)  This file
was consequently moved from peep/client/Net/Peep/Parse to its current
location.


=cut

