package Net::Peep::Conf;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Socket;
use Data::Dumper;
use Sys::Hostname;
use Net::Peep::Log;
use Net::Peep::Host;
use Net::Peep::Data::Conf;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter Net::Peep::Data::Conf);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.13 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub logger {

    # returns a logging object
    my $self = shift;
    if ( ! exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
    return $self->{'__LOGGER'};

} # end sub logger

sub client {

    my $self = shift;
    if (@_) { $self->{'CLIENT'} = shift; }
    return $self->{'CLIENT'};

} # end sub client

sub runner {

    my $self = shift;
    if (@_) { $self->{'RUNNER'} = shift; }
    return $self->{'RUNNER'};

} # end sub runner

sub setVersion {

	my $self = shift;
	my $version = shift || confess "Cannot set version:  No version information found";
	
	if (not $self->general()) {
		my $general = new Net::Peep::Data::Conf::General;
		$self->general($general);
	}
	$self->general()->version($version);
	$self->logger()->debug(1,"Configuration file version [$version] identified.");
	return 1;

} # end sub setVersion

sub getVersion {

	my $self = shift;

	my ($general) = $self->general();
	if (defined($general) and $general->version()) {
		return $general->version();
	} else {
		confess "Cannot get version:  No version information has been set.";
	}

} # end sub getVersion

sub versionExists {

	my $self = shift;
	my @general = $self->general();
	my $general = pop @general if @general;
	return defined($general) && $general->version()
	    ? 1 : 0;

} # end sub versionExists

sub versionOK {

	my $self = shift;

	my @version = $self->versionExists() 
	    ? split /\./, $self->getVersion()
		: ();
	
	my $return = 0;
	if (@version && $version[0] >= 1) {
		$return = 1;
	} elsif (@version && $version[0] >= 0 && $version[1] >= 6) {
		$return = 1;
	} elsif (@version && $version[0] >= 0 && $version[1] >= 5 && $version[2] >= 0) {
		$return = 1;
	}

	return $return;

} # end sub versionOK

sub setSoundPath {

	my $self = shift;
	my $soundpath = shift || confess "Cannot set sound path:  No sound path information found";
	
	if (not $self->general()) {
		my $general = new Net::Peep::Data::Conf::General;
		$self->general($general);
	}
	$self->general()->soundpath($soundpath);
	$self->logger()->debug(1,"Configuration file soundpath [$soundpath] identified.");
	return 1;

} # end sub setSoundPath

sub getSoundPath {

	my $self = shift;

	my ($general) = $self->general();
	if (defined($general) and $general->version()) {
		return $general->version();
	} else {
		confess "Cannot get version:  No version information has been set.";
	}

} # end sub getSoundPath

sub soundPathExists {

	my $self = shift;
	return defined($self->general()) && $self->general()->soundpath()
	    ? 1 : 0;

} # end sub soundPathExists

sub getClient {

	my $self = shift;
	my $name = shift || confess "Cannot find client:  No client information provided";

	my $return = undef;
	my $theme = $self->getCommandLineOption('theme');
	if ($theme) {
		my ($themes) = $self->themes(); 
		if (not $themes) {
			$themes = new Net::Peep::Data::Themes;
			$self->addToPool('themes',$themes);
		}
		my (@themes) = $themes->theme();
		my $found = undef;
		for my $each (@themes) {
			$found = $each if $each->name() eq $theme->value();
		}
		if ($found) {
			my ($clients) = $found->clients();
			if ($clients) {
				my (@clients) = $clients->client();
				for my $client (@clients) {
					if ($client->name() eq $name) {
						$return = $client;
						last;
					}
				}
			}  
		}
	} else {
		my ($clients) = $self->clients();
		if (not $clients) {
			$clients = new Net::Peep::Data::Clients;
			$self->addToPool('clients',$clients);
		}
		my (@clients) = $clients->client();
		for my $client (@clients) {
			if ($client->name() eq $name) {
				$return = $client;
				last;
			}
		}
	}
	return $return;

} # end sub getClient

sub setClientPort {

	my $self = shift;
	my $name = shift || confess "Cannot set port:  No client information found";
	my $port = shift || confess "Cannot set port:  No port information found";
	my $client = $self->getClient($name);
	$client->port($port);
	return 1;

} # end sub setClientPort

sub getClientPort {

	my $self = shift;
	my $client = shift || confess "Cannot get port:  No client information found";
	my $object = $self->getClient($client);
	if (defined($object) && defined($object->port())) {
		return $object->port();
	} elsif ($self->optionExists($client,'port')) {
		return $self->getOption($client,'port');
	} else {
		confess "Cannot get port:  No port information has been defined for the client [$client].";
	}

} # end sub getClientPort

sub getServer {

	my $self = shift;
	my $class = shift || confess "Cannot get server:  No class identifier found";

	confess "Cannot get information for the server in class [$class]:  No information has been set."
		unless defined($self->class()) && defined($self->class()->server());

	return $self->class()->server();

} # end sub getServer

sub getClassList {

	my $self = shift;

	confess "Cannot get class list:  No class information has been set." 
		unless defined($self->class());

	return $self->class();

} # end sub getClassList

sub getClass {

	my $self = shift;
	my $key = shift || confess "no class identifier found";

	my ($class) = $self->class();
	confess "Cannot get information for the class [$key]:  No information has been set."
	    unless defined($class) && $class->name() eq $key;

	return $self->class();

} # end sub getClass

sub getEvent {

	my $self = shift;
	my $name = shift || confess "Cannot get event:  No event identifier found";

	my ($events) = $self->events();
	my (@events) = $events->event();

	my $return;
	for my $event (@events) {
		if ($event->name() eq $name) {
			$return = $event;
			last;
		}
	}

	confess "Cannot get information for the event [$name]:  No information has been set."
	    unless defined $return;

	return $return;

} # end sub getEvent

sub isEvent {

	my $self = shift;
	my $name = shift || confess "Cannot check event:  No event identifier found";

	my $return = 0;

	my ($events) = $self->events();
	my (@events) = $events->event();

	for my $event (@events) {
		$return++ if $event->name() eq $name;
	}

	return $return ? 1 : 0;

} # end sub isEvent

sub getState {

	my $self = shift;
	my $name = shift || confess "Cannot get state:  No state identifier found";

	my ($states) = $self->states();
	my (@states) = $states->state();

	my $return;
	for my $state (@states) {
		if ($state->name() eq $name) {
			$return = $state;
			last;
		}
	}

	confess "Cannot get information for the state [$name]:  No information has been set."
	    unless defined $return;

	return $return;

} # end sub getState

sub isState {

	my $self = shift;
	my $name = shift || confess "Cannot check state:  No state identifier found";

	my $return = 0;

	my ($states) = $self->states();
	my (@states) = $states->state();

	for my $state (@states) {
		$return++ if $state->name() eq $name;
	}

	return $return ? 1 : 0;

} # end sub isState

sub checkClientEvent {

	# used by sysmonitor and logparser, among others, to include
	# or exclude events or states based on groupings

	my $self = shift;
	my $client = shift || confess "Client not found";
	my $event = shift || confess "Event not found";

	my $return = 0;

	my ($group,$letter) = ('','');

	$group = $event->{'group'} if exists $event->{'group'};
	$letter = $event->{'option-letter'} if exists $event->{'option-letter'};

	my @groups = ();
	my @exclude = ();
	my @events = ();

	@events = split //, $self->getOption($client,'events') if $self->optionExists($client,'events');
	@groups = @{ $self->getOption($client,'groups') } if $self->optionExists($client,'groups');
	@exclude = @{ $self->getOption($client,'exclude') } if $self->optionExists($client,'exclude');

	# first check the events option
	
	for my $letter_option (@events) {
		$return = 1 if $letter eq $letter_option;
	}

	if (grep /^all$/, @groups) {
		$return = 1;
		for my $exclude_option (@exclude) {
			$return = 0 if $group eq $exclude_option;
		}
	} else {
		for my $group_option (@groups) {
			$return = 1 if $group eq $group_option;
		}
	}

	return $return;

} # end sub checkClientEvent

sub checkClientHost {

	my $self = shift;
	my $client = shift || confess "Client not found";
	my $host = shift || confess "Host not found";

	my $return = 0;

	my $event = $host->getEvent();

	return $self->checkClientEvent($client,$event);

} # end sub checkClientHost

sub addClientHost {

	my $self = shift;
	my $client = shift || confess "Cannot add client host:  No client identifier found";
	my $value = shift || confess "Cannot add client host:  No client host information found";

	confess "Cannot set client host for client [$client]:  Expecting a hash ref (instead of [$value])."
		unless ref($value) eq 'HASH';

	my $identifier = $value->{'host'};

	my ($iaddr,$host,$ip);
	if ($identifier =~ /^(\d+\.)+\d+$/) {
	    # we were given an IP address
	    $ip = $identifier;
	    $host = inet_aton($ip);
	    $host = gethostbyaddr($host,AF_INET) if $host;
	    $self->logger()->log("\t\tThe host name for IP [$ip] could not be found.  This host will be ignored.")
		and return 0 unless $host;
	    $self->logger()->debug(9,"\t\tThe host name [$host] was found for host [$identifier].");
	} elsif ($identifier =~ /^([\w-]+\.)+\w+$/) {
	    # we were given a host name
	    $host = $identifier;
	    $ip = gethostbyname($identifier);
	    # funny that the next line and previous line can't be combined ... but Socket complains!
	    $ip = inet_ntoa($ip) if $ip;
	    $self->logger()->log("\t\tThe IP address for host [$identifier] could not be found.  This host will be ignored.")
		and return 0 unless $ip;
	    $self->logger()->debug(9,"\t\tThe IP address [$ip] was found for host [$identifier].");
	} else {
	    $self->logger()->log("The host name or IP [$identifier] does not appear to be valid.  This host will be ignored.");
	    return;
	}
	    
	my $event = {
	    name => $value->{'name'},
	    group => $value->{'group'},
	    'option-letter' => $value->{'option-letter'},
	    location => $value->{'location'},
	    priority => $value->{'priority'},
	    status => $value->{'status'},

	};

	my $clienthost = new Net::Peep::Host;
	$clienthost->setName($host);
	$clienthost->setIP($ip);
	$clienthost->setEvent($event);
	$clienthost->setNotificationLevel($value->{'status'});

	push @ { $self->{"__CLIENTHOST"}->{$client} }, $clienthost;

	return 1;

} # end sub addClientHost

sub getClientHostList {

	my $self = shift;

	confess "Cannot get clienthost list:  No client host information has been set." 
		unless exists $self->{"__CLIENTHOST"};

	my @clienthosts;

	for my $client (keys % { $self->{"__CLIENTHOST"} }) {
		push @clienthosts, @ { $self->{"__CLIENTHOST"}->{$client} };
	}

	return wantarray ? @clienthosts : [@clienthosts];

} # end sub getClientHostList

sub getClientHosts {

	my $self = shift;
	my $client = shift || confess "Cannot get client host:  No client identifier found";

	$self->logger()->log("Cannot get host information for the client [$client]:  No information has been set.")
	    and return
		unless exists $self->{"__CLIENTHOST"} && exists $self->{"__CLIENTHOST"}->{$client};

	return wantarray ? @{$self->{"__CLIENTHOST"}->{$client}} : $self->{"__CLIENTHOST"}->{$client};

} # end sub getClientHosts

sub addClientUptime {

	my $self = shift;
	my $client = shift || confess "Cannot add client uptime:  No client identifier found";
	my $value = shift || confess "Cannot add client uptime:  No client uptime information found";

	confess "Cannot set client uptime setting for client [$client]:  Expecting a hash ref (instead of [$value])."
		unless ref($value) eq 'HASH';

	confess "Cannot set client uptime setting for client [$client]:  The hash ref is missing important keys."
	    unless exists($value->{'name'}) && exists($value->{'value'}) && exists($value->{'status'});

	push @ { $self->{"__CLIENTUPTIME"}->{$client} }, $value;

	return 1;

} # end sub addClientUptime

sub getClientUptimeList {

	my $self = shift;

	confess "Cannot get client uptime settings list:  No client uptime information has been set." 
		unless exists $self->{"__CLIENTUPTIME"};

	my @clientuptimes;

	for my $client (keys % { $self->{"__CLIENTUPTIME"} }) {
		push @clientuptimes, @ { $self->{"__CLIENTUPTIME"}->{$client} };
	}

	return wantarray ? @clientuptimes : [@clientuptimes];

} # end sub getClientUptimeList

sub getClientUptimes {

	my $self = shift;
	my $client = shift || confess "Cannot get client uptime settings:  No client identifier found";

	$self->logger()->log("Cannot get uptime information for the client [$client]:  No information has been set.")
	    and return
		unless exists $self->{"__CLIENTUPTIME"} && exists $self->{"__CLIENTUPTIME"}->{$client};

	return wantarray ? @{$self->{"__CLIENTUPTIME"}->{$client}} : $self->{"__CLIENTUPTIME"}->{$client};

} # end sub getClientUptimes

sub addClientProc {

	my $self = shift;
	my $client = shift || confess "Cannot add client proc:  No client identifier found";
	my $value = shift || confess "Cannot add client proc:  No client proc information found";

	confess "Cannot set client proc setting for client [$client]:  Expecting a hash ref (instead of [$value])."
		unless ref($value) eq 'HASH';

	confess "Cannot set client proc setting for client [$client]:  The hash ref is missing important keys."
	    unless exists($value->{'name'}) && exists($value->{'value'}) && exists($value->{'status'});

	push @ { $self->{"__CLIENTPROC"}->{$client} }, $value;

	return 1;

} # end sub addClientProc

sub getClientProcList {

	my $self = shift;

	confess "Cannot get client proc settings list:  No client proc information has been set." 
		unless exists $self->{"__CLIENTPROC"};

	my @clientprocs;

	for my $client (keys % { $self->{"__CLIENTPROC"} }) {
		push @clientprocs, @ { $self->{"__CLIENTPROC"}->{$client} };
	}

	return wantarray ? @clientprocs : [@clientprocs];

} # end sub getClientProcList

sub getClientProcs {

	my $self = shift;
	my $client = shift || confess "Cannot get client proc settings:  No client identifier found";

	$self->logger()->log("Cannot get proc information for the client [$client]:  No information has been set.")
	    and return
		unless exists $self->{"__CLIENTPROC"} && exists $self->{"__CLIENTPROC"}->{$client};

	return wantarray ? @{$self->{"__CLIENTPROC"}->{$client}} : $self->{"__CLIENTPROC"}->{$client};

} # end sub getClientProcs

sub setGlobalOption {

	my $self = shift;
	my $name = shift || confess "Cannot set client option:  Option name not specified.";
	my $value = shift;

	my ($options) = $self->options();

	# Check the client options first ...
	my $found = undef;
	if (defined $options) {
		for my $option ($options->option()) {
			if ($option->name() eq $name) {
				$found = $option;
			}
		}
	} 
	if ($found) {
		$found->value($value);
		$self->logger()->log("Setting option [$name] to value [$value] in object [$found] ...");
	} else {
		my $option = new Net::Peep::Data::Option;
		$option->name($name);
		$option->value($value);
		$self->logger()->log("Setting option [$name] to value [$value] in object [$options]...");
		$options->addToPool('option',$option);
	}

	return 1;

} # end sub setGlobalOption

sub setClientOption {

	my $self = shift;
	my $name = shift || confess "Cannot set client option:  Option name not specified.";
	my $value = shift;

	# The following bit of logic is a bit of a kludge.  If you're
	# wondering why it was done, please contact the author :-)

	my $who = $self->client() || confess "Cannot set client option:  Client not specified.";

	my $client = $self->getClient($who);

	my ($options) = $client->options();

	# Check the client options first ...
	my $found = undef;
	if (defined $client) {
		for my $option ($options->option()) {
			if ($option->name() eq $name) {
				$found = $option;
			}
		}
	} else {
		confess "Cannot set client option:  No configuration information ".
		    "for the client [$who] was found.";
	}
	if ($found) {
		$found->value($value);
		$self->logger()->log("Setting option [$name] to value [$value] in object [$found] ...");
	} else {
		my $option = new Net::Peep::Data::Option;
		$option->name($name);
		$option->value($value);
		$self->logger()->log("Setting option [$name] to value [$value] in object [$options]...");
		$options->addToPool('option',$option);
	}

	return 1;

} # end sub setClientOption

sub setCommandLineOption {

	my $self = shift;
	my $name = shift || confess "Error setting command-line option:  No option name was provided.";
	my $value = shift;

	my $options = $self->commandLineOptions();
	my @options = $options->option();
	my $found;
	for my $option (@options) {
		if ($option->name() eq $name) {
			$found = $option;
			last;
		}
	}
	if ($found) {
		$found->value($value);
	} else {
		my $option = new Net::Peep::Data::Option;
		$option->name($name);
		$option->value($value);
		$options->addToPool('option',$option);
	}
	return 1;

} # end sub setCommandLineOption

sub getGlobalOption {

	my $self = shift;
	my $name = shift || confess "Cannot get global option:  No option name specified.";

	my $return = undef;
	my $theme = $self->getCommandLineOption('theme');
	if ($theme) {
		my ($themes) = $self->themes(); 
		if (not $themes) {
			$themes = new Net::Peep::Data::Themes;
			$self->addToPool('themes',$themes);
		}
		my (@themes) = $themes->theme();
		my $found = undef;
		for my $each (@themes) {
			$found = $each if $each->name() eq $theme->value();
		}
		if ($found) {
			my ($options) = $found->options();
			return $return unless defined $options;
			for my $option ($options->option()) {
				if ($option->name() eq $name) {
					$return = $option;
					last;
				}
			}
		}
	} else {
		my ($general) = $self->general();
		my ($options) = $general->options();
		return $return unless defined $options;
		for my $option ($options->option()) {
			if ($option->name() eq $name) {
				$return = $option;
				last;
			}
		}
	}
	return $return;

} # end sub getGlobalOption

sub setOption {

	my $self = shift;
	my $name = shift || confess "Cannot set option:  No option name specified.";
	my $value = shift;

	$self->logger()->debug(9,"Setting option [$name] for client [".$self->client()."] ...");

	my $client = $self->getClient($self->client());

	my ($options) = $client->options();
	my @options = $options->option();
	my $found;
	for my $option (@options) {
		$found = $option if $option->name() eq $name;
	}
	if ($found) {
		$found->value($value);
	} else {
		my $option = new Net::Peep::Data::Option;
		$option->name($name);
		$option->value($value);
		$options->addToPool('option',$option);
	}
	
	$self->logger()->debug(9,"\tOption [$name] set to [$value] for client [".$self->client()."].");

} # end sub setOption

sub commandLineOptions {

	my $self = shift;
	$self->{'_COMMAND_LINE_OPTIONS'} = new Net::Peep::Data::Options
	    unless exists $self->{'_COMMAND_LINE_OPTIONS'};
	return $self->{'_COMMAND_LINE_OPTIONS'};

} # end sub commandLineOptions

sub getCommandLineOption {

	my $self = shift;
	my $name = shift || confess "Cannot get command-line option:  No option name specified.";

	my ($options) = $self->commandLineOptions();
	my $found = undef;
	for my $option ($options->option()) {
		if ($option->name() eq $name) {
			$found = $option;
			last;
		}
	}
	return $found;

} # end sub getCommandLineOption

sub getClientOption {

	my $self = shift;
	my $who = shift || confess "Cannot get client option:  No client name specified.";
	my $name = shift || confess "Cannot get client option:  No option name specified.";

	my $found = undef;
	my $client = $self->getClient($who);
	return $found unless defined $client;
	my ($options) = $client->options();
	return $found unless defined $options;
	for my $option ($options->option()) {
		if ($option->name() eq $name) {
			$found = $option;
			last;
		}
	}
	return $found;

} # end sub getClientOption

sub getOption {

	my $self = shift;

	my $name;
	if (@_ == 1) {
	    $name = $_[0] || confess "Cannot get client option:  Option name not specified.";
	} elsif (@_ == 2) {
	    $name = $_[1] || confess "Cannot get client option:  Option name not specified.";
	} else {
	    confess "Cannot get option:  Incorrect number of arguments to the getOption method.";
	}

	my $option = $self->optionExists(@_);
	confess "Cannot get option [$name]:  It has not been set yet."
	    unless defined $option;
	return $option->value();

} # end sub getOption

sub optionExists {

	my $self = shift;
	my $name;
	my $option;
	my $client;
	if (@_ == 1) {
	    $option = shift || confess "Cannot get client option:  Option name not specified.";
	    $name = $self->client() ? $self->client() : undef;
	} elsif (@_ == 2) {
	    $name = shift || confess "Cannot get client option:  Client name not specified.";
	    $option = shift || confess "Cannot get client option:  Option name not specified.";
	} else {
	    confess "Cannot get option [$option]:  Incorrect number of arguments to the optionExists method.";
	}
	$self->logger()->debug(9,"Getting option [$option] ...");
	my $found = undef;
	# We first check command-line options, which have the highest 
	# precedence.  If we don't find the option amongst the
	# command-line options, we check the client options, which are
	# second to command-line options.  Finally, if we can't find
	# the option among the command-line or client options, we
	# check the global options, which have lowest precedence
	$found = $self->getCommandLineOption($option);
	$found = $self->getClientOption($name,$option) if defined($name) && ! $found ;
	$found = $self->getGlobalOption($option) if ! $found;

	if ($found) {
		$self->logger()->debug(9,"\tGot [".$found->value()."] ...");
	} else {
		$self->logger()->debug(9,"\tThe option has not been set yet.");
	}

	return $found;

} # end sub optionExists

sub host {

	my $self = shift;
	if (@_) {
		$self->{'_HOSTNAME'} = shift;
	} elsif (not exists $self->{'_HOSTNAME'}) {
		$self->{'_HOSTNAME'} = shift || 
		    confess "Error:  The host name could not be found.";
	} else {
		# do nothing
	}
	return $self->{'_HOSTNAME'};

} # end sub host

1;

__END__

=head1 NAME

Net::Peep::Conf - Perl extension for providing an object
representation of configuration information for Peep: The Network
Auralizer.

=head1 SYNOPSIS

  use Net::Peep::Conf;
  my $conf = new Net::Peep::Conf;
  $conf->setBroadcast($class0,$value0);
  $conf->setBroadcast($class1,$value1);
  $conf->getBroadcastList();

=head1 DESCRIPTION

Net::Peep::Conf provides an object interface for Peep configuration
information, typically extracted from a Peep configuration file (e.g.,
/etc/peep.conf) by the Net::Peep::Parser module.

=head1 EXPORT

None by default.

=head1 PUBLIC METHODS

  getBroadcastList() - Returns a list of all broadcast names
  associated with all classes.

  getClassList() - Returns a list of all class names that have
  associated server lists.

  getClass($class) - Returns a list of servers associated with the
  class $class.

  setClass($class,$arrayref) - Associates the class $class with the
  list of servers given in $arrayref.

  getEventList() - Returns a list of all event names.

  getEvent($event) - Returns the event information for the event with
  name $event.

  setEvent($event,$hashref) - Associates the event $event with the
  information contained in $hashref.

  getStateList() - Returns a list of all state names.

  getState($state) - Returns the state information associated with the
  state $state.

  setState($event,$hashref) - Associates the state $state with the
  information contained in $hashref.

  setConfigurationText($client,$text) - Sets the configuration text to
  $text for client $client.  For reference and debugging only.  The
  text is not actually used internally for any purpose.

  getNotificationText($client) - Returns the configuration text for
  client $client.

  setNotificationText($client,$text) - Sets the configuration text to
  $text for client $client.  For reference and debugging only.  The
  text is not actually used internally for any purpose.

  getConfigurationText($client) - Returns the configuration text for
  client $client.

  setClientEvent($name,$arrayref) - Sets the events associated with
  the client $name.

  getClientEvents($name) - Returns the events associated with the client $name.

  getClientEventList() - Returns all events associated with all clients.

  checkClientEvent() - The method name is a question: Based on
  command-line or configuration file settings, should this client
  event be considered active in the current client?  For example,
  should the logparser check the regular expression for this event
  against log files?

  setVersion() - Sets the version number.

  getVersion() - Return the version number taken from the Peep configuration
  file (e.g., peep.conf) if it exists.  Confesses if the version has not been
  set yet.  See also versionExists().

  versionExists() - Returns 1 if a version has been set with the setVersion()
  method, 0 otherwise.

  setSoundPath() - Sets the path to the Peep sound respository
  (typically /usr/local/share/peep/sounds).

  getSoundPath() - Returns the sound path.  Confesses if the sound
  path has not been set yet.  See also soundPathExists().

  soundPathExists() - Returns 1 if the sound path has been set with
  the setSoundPath() method, 0 otherwise.

=head1 AUTHOR

Collin Starkweather Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::BC, Net::Peep::Parser, Net::Peep::Log.

http://peep.sourceforge.net

=head1 CHANGE LOG

$Log: Conf.pm,v $
Revision 1.13  2002/10/07 01:22:01  starky
Correctly moved options into the <general>...</general> block of the
configuration file.

Revision 1.12  2002/06/13 07:01:59  starky
Themes are now (mostly) working.  Some work remains on the server side
before they can be fully tested.

Revision 1.11  2002/05/23 07:40:17  starky
First commit of a working 0.5.x pinger.

Revision 1.10  2002/05/23 05:46:32  starky
Checkin of the first working version of sysmonitor for 0.5.x.

Revision 1.9  2002/05/21 03:40:17  starky
Dagnabbit!  Whenever I do a mass commit, I always forget one file.
In this case, it's Net::Peep::Conf.  This is a commit continuing to
make progress towards 0.5.x.

Revision 1.8  2002/03/25 18:59:28  starky
Got the first client working with the 0.5.x server:  logparser.  An
e-mail with futher details will be sent to the Peep develop list.

Revision 1.7  2002/03/13 06:57:04  starky
Finally test script 101.t passes all tests and the server peeps as a
result.

Revision 1.6  2002/03/13 02:11:26  starky
With this commit 100.t, a test script for text-based Peep configuration,
passes all tests.

Revision 1.5  2002/03/09 20:02:31  starky
Adjusted the Net::Peep::BC class to the new data classes.

Revision 1.4  2002/03/07 07:24:57  starky
Deprecated some dross that was no longer being used and continued
to convert the class to the new data format.

Revision 1.3  2002/03/06 17:33:42  starky
Bugfixes too numerous to mention.

Revision 1.2  2002/02/26 06:01:10  starky
Test script 100.t now passes all tests.  Some work with the configuration
and parsing still needs to be done, as well as XML imports.  Progress
continues ....

Revision 1.1  2001/10/18 06:01:33  starky
Initial commit of client libraries for version 0.5.0.

Revision 1.8  2001/09/23 08:53:56  starky
The initial checkin of the 0.4.4 release candidate 1 clients.  The release
includes (but is not limited to):
o A new client:  pinger
o A greatly expanded sysmonitor client
o An API for creating custom clients
o Extensive documentation on creating custom clients
o Improved configuration file format
o E-mail notifications
Contact Collin at collin.starkweather@colorado with any questions.

Revision 1.7  2001/08/08 20:17:57  starky
Check in of code for the 0.4.3 client release.  Includes modifications
to allow for backwards-compatibility to Perl 5.00503 and a critical
bug fix to the 0.4.2 version of Net::Peep::Conf.

Revision 1.6  2001/08/06 04:20:35  starky
Fixed bug #447844.

Revision 1.5  2001/07/23 20:17:45  starky
Fixed a minor bug in setting groups and exclude flags from the command-line
with the logparser.

Revision 1.4  2001/07/23 17:46:29  starky
Added versioning to the configuration file as well as the ability to
specify groups in addition to / as a replacement for event letters.
Also changed the Net::Peep::Parse namespace to Net::Peep::Parser.
(I don't know why I ever named an object by a verb!)

Revision 1.3  2001/07/20 03:19:58  starky
Some trivial changes.  They normally wouldn't be committed at this stage,
but the code is being prepped for the 0.4.2 release.

Revision 1.2  2001/05/07 02:39:19  starky
A variety of bug fixes and enhancements:
o Fixed bug 421729:  Now the --output flag should work as expected and the
--logfile flag should not produce any unexpected behavior.
o Documentation has been updated and improved, though more improvements
and additions are pending.
o Removed print STDERRs I'd accidentally left in the last commit.
o Other miscellaneous and sundry bug fixes in anticipation of a 0.4.2
release.

Revision 1.1  2001/04/23 10:13:19  starky
Commit in preparation for release 0.4.1.

o Altered package namespace of Peep clients to Net::Peep
  at the suggestion of a CPAN administrator.
o Changed Peep::Client::Log to Net::Peep::Client::Logparser
  and Peep::Client::System to Net::Peep::Client::Sysmonitor
  for clarity.
o Made adjustments to documentation.
o Fixed miscellaneous bugs.

Revision 1.7  2001/04/17 06:46:21  starky
Hopefully the last commit before submission of the Peep client library
to the CPAN.  Among the changes:

o The clients have been modified somewhat to more elagantly
  clean up pidfiles in response to sigint and sigterm signals.
o Minor changes have been made to the documentation.
o The Peep::Client module searches through a host of directories in
  order to find peep.conf if it is not immediately found in /etc or
  provided on the command line.
o The make test script conf.t was modified to provide output during
  the testing process.
o Changes files and test.pl files were added to prevent specious
  complaints during the make process.

Revision 1.6  2001/03/31 07:51:35  mgilfix


  Last major commit before the 0.4.0 release. All of the newly rewritten
clients and libraries are now working and are nicely formatted. The server
installation has been changed a bit so now peep.conf is generated from
the template file during a configure - which brings us closer to having
a work-out-of-the-box system.

Revision 1.6  =head1 CHANGE LOG
 
$Log: Conf.pm,v $
Revision 1.13  2002/10/07 01:22:01  starky
Correctly moved options into the <general>...</general> block of the
configuration file.

Revision 1.12  2002/06/13 07:01:59  starky
Themes are now (mostly) working.  Some work remains on the server side
before they can be fully tested.

Revision 1.11  2002/05/23 07:40:17  starky
First commit of a working 0.5.x pinger.

Revision 1.10  2002/05/23 05:46:32  starky
Checkin of the first working version of sysmonitor for 0.5.x.

Revision 1.9  2002/05/21 03:40:17  starky
Dagnabbit!  Whenever I do a mass commit, I always forget one file.
In this case, it's Net::Peep::Conf.  This is a commit continuing to
make progress towards 0.5.x.

Revision 1.8  2002/03/25 18:59:28  starky
Got the first client working with the 0.5.x server:  logparser.  An
e-mail with futher details will be sent to the Peep develop list.

Revision 1.7  2002/03/13 06:57:04  starky
Finally test script 101.t passes all tests and the server peeps as a
result.

Revision 1.6  2002/03/13 02:11:26  starky
With this commit 100.t, a test script for text-based Peep configuration,
passes all tests.

Revision 1.5  2002/03/09 20:02:31  starky
Adjusted the Net::Peep::BC class to the new data classes.

Revision 1.4  2002/03/07 07:24:57  starky
Deprecated some dross that was no longer being used and continued
to convert the class to the new data format.

Revision 1.3  2002/03/06 17:33:42  starky
Bugfixes too numerous to mention.

Revision 1.2  2002/02/26 06:01:10  starky
Test script 100.t now passes all tests.  Some work with the configuration
and parsing still needs to be done, as well as XML imports.  Progress
continues ....

Revision 1.1  2001/10/18 06:01:33  starky
Initial commit of client libraries for version 0.5.0.

Revision 1.8  2001/09/23 08:53:56  starky
The initial checkin of the 0.4.4 release candidate 1 clients.  The release
includes (but is not limited to):
o A new client:  pinger
o A greatly expanded sysmonitor client
o An API for creating custom clients
o Extensive documentation on creating custom clients
o Improved configuration file format
o E-mail notifications
Contact Collin at collin.starkweather@colorado with any questions.

Revision 1.7  2001/08/08 20:17:57  starky
Check in of code for the 0.4.3 client release.  Includes modifications
to allow for backwards-compatibility to Perl 5.00503 and a critical
bug fix to the 0.4.2 version of Net::Peep::Conf.

Revision 1.6  2001/08/06 04:20:35  starky
Fixed bug #447844.

Revision 1.5  2001/07/23 20:17:45  starky
Fixed a minor bug in setting groups and exclude flags from the command-line
with the logparser.

Revision 1.4  2001/07/23 17:46:29  starky
Added versioning to the configuration file as well as the ability to
specify groups in addition to / as a replacement for event letters.
Also changed the Net::Peep::Parse namespace to Net::Peep::Parser.
(I don't know why I ever named an object by a verb!)

Revision 1.3  2001/07/20 03:19:58  starky
Some trivial changes.  They normally wouldn't be committed at this stage,
but the code is being prepped for the 0.4.2 release.

Revision 1.2  2001/05/07 02:39:19  starky
A variety of bug fixes and enhancements:
o Fixed bug 421729:  Now the --output flag should work as expected and the
--logfile flag should not produce any unexpected behavior.
o Documentation has been updated and improved, though more improvements
and additions are pending.
o Removed print STDERRs I'd accidentally left in the last commit.
o Other miscellaneous and sundry bug fixes in anticipation of a 0.4.2
release.

Revision 1.1  2001/04/23 10:13:19  starky
Commit in preparation for release 0.4.1.

o Altered package namespace of Peep clients to Net::Peep
  at the suggestion of a CPAN administrator.
o Changed Peep::Client::Log to Net::Peep::Client::Logparser
  and Peep::Client::System to Net::Peep::Client::Sysmonitor
  for clarity.
o Made adjustments to documentation.
o Fixed miscellaneous bugs.

Revision 1.7  2001/04/17 06:46:21  starky
Hopefully the last commit before submission of the Peep client library
to the CPAN.  Among the changes:

o The clients have been modified somewhat to more elagantly
  clean up pidfiles in response to sigint and sigterm signals.
o Minor changes have been made to the documentation.
o The Peep::Client module searches through a host of directories in
  order to find peep.conf if it is not immediately found in /etc or
  provided on the command line.
o The make test script conf.t was modified to provide output during
  the testing process.
o Changes files and test.pl files were added to prevent specious
  complaints during the make process.

Revision 1.6  2001/03/31 07:51:35  mgilfix


  Last major commit before the 0.4.0 release. All of the newly rewritten
clients and libraries are now working and are nicely formatted. The server
installation has been changed a bit so now peep.conf is generated from
the template file during a configure - which brings us closer to having
a work-out-of-the-box system.

Revision 1.7  2001/03/31 02:17:00  mgilfix
Made the final adjustments to for the 0.4.0 release so everything
now works. Lots of changes here: autodiscovery works in every
situation now (client up, server starts & vice-versa), clients
now shutdown elegantly with a SIGTERM or SIGINT and remove their
pidfiles upon exit, broadcast and server definitions in the class
definitions is now parsed correctly, the client libraries now
parse the events so they can translate from names to internal
numbers. There's probably some other changes in there but many
were made :) Also reformatted all of the code, so it uses
consistent indentation.

Revision 1.5  2001/03/28 02:41:48  starky
Created a new client called 'pinger' which pings a set of hosts to check
whether they are alive.  Made some adjustments to the client modules to
accomodate the new client.

Also fixed some trivial pre-0.4.0-launch bugs.

Revision 1.4  2001/03/27 05:49:04  starky
Modified the getClientPort method to accept the 'port' option as
specified on the command line if no client has been specified in the
conf file.

Revision 1.3  2001/03/27 00:44:19  starky
Completed work on rearchitecting the Peep client API, modified client code
to be consistent with the new API, and added and tested the sysmonitor
client, which replaces the uptime client.

This is the last major commit prior to launching the new client code,
though the API or architecture may undergo some initial changes following
launch in response to comments or suggestions from the user and developer
base.

Revision 1.2  2001/03/18 17:17:46  starky
Finally got LogParser (now called logparser) running smoothly.

Revision 1.1  2001/03/16 18:31:59  starky
Initial commit of some very broken code which will eventually comprise
a rearchitecting of the Peep client libraries; most importantly, the
Perl modules.

A detailed e-mail regarding this commit will be posted to the Peep
develop list (peep-develop@lists.sourceforge.net).

Contact me (Collin Starkweather) at

  collin.starkweather@colorado.edu

or

  collin.starkweather@collinstarkweather.com

with any questions.


=cut
