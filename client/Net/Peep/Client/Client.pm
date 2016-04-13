package Net::Peep::Client;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Data::Dumper;
use Socket;
use Getopt::Long;
use Pod::Usage;
use Net::Peep::BC;
use Net::Peep::Log;
use Net::Peep::Conf;
use Net::Peep::Host;
use Net::Peep::Parser;
use Net::Peep::Notifier;
use Net::Peep::Data::Client;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( INTERVAL MAX_INTERVAL ADJUST_AFTER ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.20 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# These are in seconds and are the parameters for File::Tail

# File Tail uses the idea of intervals and predictions to try to keep
# blocking time at a maximum. These three parameters are the ones that
# people will want to tune for performance vs. load. The smaller the
# interval, the higher the load but faster events are picked up.

# The interval that File::Tail waits before checking the log
use constant INTERVAL => 0.1;
# The maximum interval that File::Tail will wait before checking the
# log
use constant MAX_INTERVAL => 1;
# The time after which File::Tail adjusts its predictions
use constant ADJUST_AFTER => 2;

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub name {

    my $self = shift;
    if (@_) { $self->{'NAME'} = shift; }
    return $self->{'NAME'};

} # end sub name

sub callback {

	my $self = shift;
	my $callback = shift;
	confess "Cannot register callback:  Expecting a code reference.  (Got [$callback].)" 
		unless ref($callback) eq 'CODE';
	$self->{"__CALLBACK"} = $callback;
	return 1;

} # end sub callback

sub getCallback {

	my $self = shift;
	confess "Cannot get callback:  A callback has not been set yet."
		unless exists $self->{"__CALLBACK"};
	return $self->{"__CALLBACK"};

} # end sub getCallback

sub parser {

	my $self = shift;
	my $parser = shift;
	confess "Cannot register parser:  Expecting a code reference.  (Got [$parser].)" 
		unless ref($parser) eq 'CODE';
	$self->{"__PARSER"} = $parser;
	return 1;

} # end sub parser

sub getParser {

	my $self = shift;
	return exists($self->{"__PARSER"}) ? $self->{"__PARSER"} : undef;

} # end sub getParser

sub runParser {

	my $self = shift;
	my @text = @_;

	my $parser = $self->getParser();
	if (defined($parser) && ref($parser) =~ /CODE/) {
		&$parser(@text);
		return 1;
	} else {
		return undef;
	}

} # end sub runParser

sub loop {

	my $self = shift;
	if (@_) { $self->{"__LOOP"} = shift; }
	return $self->{"__LOOP"};

} # end sub loop

sub peck {

	my $self = shift;
	my $conf = $self->conf();

	unless (exists $self->{"__PEEP"}) {
		my $name = $self->name();
		my $found = 0;
		my ($clients) = $conf->clients();
		my @clients = $clients->client();
		$self->logger()->log("[".scalar(@clients)."] clients found in [$clients].");
		for my $client (@clients) {
			$self->logger()->log("Found client named [".$client->name()."]");
			$found++ if $client->name() eq $name;
		}
		if ($found) {
			$self->{"__PEEP"} = Net::Peep::BC->new($conf);
		} else {
			confess "Error:  No configuration could be found for the client [$name].";
		}
	}
	return $self->{"__PEEP"};

} # end sub peck

sub initialize {

	my $self = shift;
	my %options = @_;
	
	my $conf = $self->conf();
	$conf->client($self->name()) unless $conf->client();
	$conf->runner($self);

	my (
	    $config,
	    $theme,
	    $logfile,
	    $debug,
	    $daemon,
	    $output,
	    $pidfile,
	    $autodiscovery,
	    $server,
	    $port,
	    $silent,
	    $transport,
	    $raw,
	    $protocol,
	    $help) = ('/etc/peep.conf','','',0,1,'','',1,'','',0,'tcp',0,'tcp',0);
	
	my %standardOptions = (
			       'config=s' => \$config,
			       'theme=s' => \$theme,
			       'logfile=s' => \$logfile,
			       'debug=s' => \$debug,
			       'daemon!' => \$daemon,
			       'output=s' => \$output,
			       'pidfile=s' => \$pidfile,
			       'autodiscovery!' => \$autodiscovery,
			       'server=s' => \$server,
			       'port=s' => \$port,
			       'raw' => \$raw,
			       'silent' => \$silent,
			       'transport=s' => \$transport,
			       'protocol=s' => \$protocol,
			       'help' => \$help
			       );
	
	for my $option (keys %standardOptions) {
		if (exists $options{$option}) {
			delete $standardOptions{$option};
		}
	}
	
	my %allOptions = (%options,%standardOptions);
	
	GetOptions(%allOptions);
	
	return 0 if $help;

	# set the debug level first so we can start printing debugging
	# messages
	$Net::Peep::Log::logfile = $output if $output;
	$Net::Peep::Log::debug = $debug if $debug;
	
	my $found;
	
	my $searched;
	$searched = "\t${$allOptions{'config=s'}}\n";
	if (-f ${$allOptions{'config=s'}}) {
		$found = ${$allOptions{'config=s'}};
	} else {
		my @dirs = ('.','/usr/local/etc','/etc','/usr','/usr/local','/opt');
		for my $dir (@dirs) {
			$searched .= "\t$dir/peep.conf\n";
			if (-f "$dir/peep.conf") {
				$found = "$dir/peep.conf";
				last;
			}
			$searched .= "\t$dir/peep/peep.conf\n";
			if (-f "$dir/peep/peep.conf") {
				$found = "$dir/peep/peep.conf";
				last;
			}
			$searched .= "\t$dir/peep.conf.xml\n";
			if (-f "$dir/peep.conf.xml") {
				$found = "$dir/peep.conf.xml";
				last;
			}
			$searched .= "\t$dir/peep/peep.conf.xml\n";
			if (-f "$dir/peep/peep.conf.xml") {
				$found = "$dir/peep/peep.conf.xml";
				last;
			}
		}
	}

	if ($found) {
		$self->logger()->debug(1,"The Peep configuration file has been identified as [$found]");
	} else {
		$self->logger()->log(<<"eop");
No Peep configuration file could be found amongst:

$searched
eop
		;
		exit 1;
	}

	$self->logger()->log("Setting config option ...");
	$conf->setCommandLineOption('config',$found);
	$conf->setCommandLineOption('logfile',${$allOptions{'logfile=s'}}) if ${$allOptions{'logfile=s'}} ne '';
	$conf->setCommandLineOption('theme',${$allOptions{'theme=s'}}) if ${$allOptions{'theme=s'}} ne '';
	$conf->setCommandLineOption('debug',${$allOptions{'debug=s'}});
	$conf->setCommandLineOption('daemon',${$allOptions{'daemon!'}});
	$conf->setCommandLineOption('output',${$allOptions{'output=s'}});
	$conf->setCommandLineOption('pidfile',${$allOptions{'pidfile=s'}}) if ${$allOptions{'pidfile=s'}} ne '';
	$conf->setCommandLineOption('autodiscovery',${$allOptions{'autodiscovery!'}});
	$conf->setCommandLineOption('server',${$allOptions{'server=s'}}) if ${$allOptions{'server=s'}} ne '';
	$conf->setCommandLineOption('port',${$allOptions{'port=s'}}) if ${$allOptions{'port=s'}} ne '';
	$conf->setCommandLineOption('silent',${$allOptions{'silent'}});
	$conf->setCommandLineOption('protocol',${$allOptions{'protocol=s'}}) if ${$allOptions{'protocol=s'}} ne '';
	$conf->setCommandLineOption('help',${$allOptions{'help'}});

	return 1;

} # end sub initialize

sub MainLoop {

	my $self = shift;
	my $sleep = shift;

	my $client = $self->name() || confess "Cannot begin main loop:  Client name not specified.";
	my $conf = $self->conf() || confess "Cannot begin main loop:  Configuration object not found.";

	my $fork = $conf->getOption('daemon');

	if ($fork) {

		$self->logger()->debug(7,"Running in daemon mode.  Forking ...");

		if (fork()) {
			# If we're here, then we're the parent
			close (STDIN);
			close (STDOUT);
			close (STDERR);
			exit(0);
		}

		$self->logger()->debug(7,"\tForked.");

		# Else we're the child. Let's write out our pid
		my $pid = 0;
		if ($conf->optionExists('pidfile')) {
			my $pidfile = $conf->getOption('pidfile') || confess "Cannot fork:  Pidfile not found.";
			if (open PIDFILE, ">$pidfile") {
				select (PIDFILE); $| = 1;  # autoflush
				select (STDERR);
				print PIDFILE "$$\n";
				close PIDFILE;
				$pid = 1;
			} else {
				$self->logger()->log("Warning:  Couldn't open pid file:  No pidfile option.");
				$self->logger()->log("\tContinuing anyway ...");
			}
		} else {
			$self->logger()->log("Warning:  Couldn't open pid file: Pidfile option not specified.");
			$self->logger()->log("\tContinuing anyway ...");
		}

	}

	my $sub = $self->getCallback();
	if ($sleep) {
		while (1) {
			$self->logger()->debug(9,"Executing callback from within infinite loop ...");
			&$sub();
			$self->logger()->debug(9,"\tSleeping [$sleep] seconds ...");
			sleep($sleep);
		}
	} else {
		$self->logger()->debug(9,"Executing callback [$sub] ...");
		&$sub();
	}

} # end sub MainLoop

sub configure {

	my $self = shift;
	my $conf = $self->conf() 
	    || confess "Cannot parse configuration object:  Configuration object not found";

	Net::Peep::Parser->new()->load($conf);

	if ($conf->versionOK()) {

# now have the client parse its own configuration
		my $data = $conf->getClient($self->name());
		my @text = split /\n/, $data->configuration();
		$self->logger()->debug(1,"\tParsing configuration text for client [".$self->name()."] ...");
		$self->runParser(@text);
		$self->logger()->debug(1,"\tDone parsing configuration for client [".$self->name()."].");

	} else {

		my $config = $conf->getOption('config');
		print STDERR <<"eop";

[$0] Warning:  The configuration file 

  $config

appears to use an old configuration file syntax.  You may want to
update your configuration to be consistent with the 0.5.0 release.

eop

		;

	}

	return $conf;

} # end sub configure

sub conf {

	my $self = shift;
	$self->{"__CONF"} = Net::Peep::Conf->new() 
	    unless exists $self->{"__CONF"};
	return $self->{"__CONF"};

} # end sub conf

sub pods {

	my $self = shift;
	my $message = shift;

	my $args = { -exitval => 0, -verbose => 2, -output => \*STDOUT };

	$args->{'-message'} = $message if $message;

	pod2usage($args);

} # end sub pods

# returns a logging object
sub logger {

	my $self = shift;
	if ( ! exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
	return $self->{'__LOGGER'};

} # end sub logger

# Remove our pidfile with garbage collection (if it exists) The client
# needs to call this function explicitly upon receipt of a signal with
# the appropriate reference.
sub shutdown {
	my $self = shift;
	print STDERR "Shutting down ...\n";
	my $notifier = new Net::Peep::Notifier;
	print STDERR "\tFlushing notification buffers ...\n";
	my $n = $notifier->force();
	my $string = $n ? 
	    "\t$n notifications were flushed from the buffers.\n" : 
		"\tNo notifications were flushed from the buffers:  The buffers were empty.\n";
	print STDERR $string;
	my $conf = $self->conf();
	my $pidfile = defined $conf && $conf->optionExists('pidfile') && -f $conf->getOption('pidfile')
	    ? $conf->getOption('pidfile') : '';
	if ($pidfile) {
		print STDERR "\tUnlinking pidfile ", $pidfile, " ...\n";
		unlink $pidfile;
	}
	print STDERR "Done.\n";
}    


# This method has been deprecated as of 0.5.0

#sub tempParseDefaults {
#
#    my $self = shift;
#    my @text = @_;
#
#    my $conf = $self->conf();
#
#    for my $line ($self->getConfigSection('default',@text)) {
#
#	    if ($line =~ /^\s*([\w\-]+)\s+(\S+)\s*$/) {
#		my ($option,$value) = ($1,$2);
#		if ($conf->optionExists($option)) {
#		    $self->logger()->debug(6,"\t\tNot setting option [$option]:  It has already been set (possibly from the command-line).");
#		} else {
#		    $self->logger()->debug(6,"\t\tSetting option [$option] to value [$value].");
#		    $conf->setOption($option,$value) unless $conf->optionExists($option);
#		}
#	    }
#
#    }
#
#} # sub tempParseDefaults

sub getGroups {

	my $self = shift;
	my $conf = $self->conf();
	unless (exists $self->{'GROUPS'}) {
		my $groups = $conf->optionExists('groups') ? $conf->getOption('groups') : '';
		my @groups = ref($groups) eq 'ARRAY' ? @$groups : split /,/, $groups;
		$self->{'GROUPS'} = \@groups;
	}
	return wantarray ? @{$self->{'GROUPS'}} : $self->{'GROUPS'};
    
} # end sub getGroups

sub getExcluded {

    my $self = shift;
    my $conf = $self->conf();
    unless (exists $self->{'EXCLUDED'}) {
	my $excluded = $conf->optionExists('exclude') ? $conf->getOption('exclude') : '';
	my @excluded = ref($excluded) eq 'ARRAY' ? @$excluded : split /,/, $excluded;
	$self->{'EXCLUDED'} = \@excluded;
    }
    return wantarray ? @{$self->{'EXCLUDED'}} : $self->{'EXCLUDED'};
    
} # end sub getExcluded

sub filter {

	my $self = shift;
	my $hash = shift || confess "Hash reference not found";
	my $nogrp = shift;

	my $conf = $self->conf();

	my $return = 1;

	my $name = $hash->{'name'};

	unless ($nogrp) {

		$self->logger()->debug(9,"Checking group [$name] against group and excluded group lists ...");

		my $group = $hash->{'group'};

		my @groups = ();
		my @exclude = ();

		@groups = $self->getGroups();
		@exclude = $self->getExcluded();

		if (grep /^all$/, @groups) {
# do nothing
		} else {
			my $found = 0;
			for my $group_option (@groups) {
				$found = 1 if $group eq $group_option;
			}
			$return = 0 unless $found;
		}

		for my $exclude_option (@exclude) {
			$return = 0 if $group eq $exclude_option;
		}

		$self->logger()->debug(8,"[$name] will be ignored:  The group [$group] is either not in the group ".
				"list [@groups] or it is in the excluded list [@exclude].") if $return == 0;
	}

	my $hosts = $hash->{'hosts'};
	if (exists $hash->{'pool'}) {
		my $pool = $hash->{'pool'};
		if ($pool->isInHostPool($Net::Peep::Notifier::HOSTNAME)) {
# do nothing
		} else {
			$return = 0;
			$self->logger()->debug(8,"[$name] will be ignored:  Host [$Net::Peep::Notifier::HOSTNAME] ".
					"is not in the host pool [$hosts].");
		}
	}

	return $return;

} # end sub filter

1;

__END__

=head1 NAME

Net::Peep::Client - Perl extension for client application module
subclasses for Peep: The Network Auralizer.

=head1 SYNOPSIS

See the Net::Peep documentation for information about the usage of the
Net::Peep::Client object.

=head1 DESCRIPTION

Provides support methods for the various Peep clients applications,
can be subclassed to create new client modules, and eases the
creation of generic Peep clients.

See the main Peep client documentation or

  perldoc Net::Peep

for more information on usage of this module.

=head1 OPTIONS

The following options are common to all Peep clients:

  --config=[PATH]       Path to the configuration file to use.
  --theme=[THEME]       Name of the theme to use.
  --debug=[NUMBER]      Enable debugging. (Def:  0)
  --nodaemon            Do not run in daemon mode.  (Def:  daemon)
  --pidfile=[PATH]      The file to write the pid out to.  (Daemon only.)
  --output=[PATH]       The file to log output to. (Def: stderr)
  --noautodiscovery     Disables autodiscovery and enables the server and port options.
                        (Default:  autodiscovery)
  --server=[HOST]       The host (or IP address) to connect to.  
  --port=[PORT NO]      The port to use.
  --protocol=[tcp|udp]  The protocol that will be used for client-server communication. 
                        (Def: tcp)
  --help                Prints this documentation.

=head1 EXPORT

None by default.

=head1 METHODS

    new() - The constructor

    name($name) - Sets/gets the name of the client.  All clients must
    have a name.

    initialize(%options) - Sets the value (using the setOption method
    of the Net::Peep::Conf object) of all command-line options parsed
    by Getopt::Long for the client.  Additional options may be
    specified using %options.  For more information on the format of
    the %options hash, see Getopt::Long.

    configure() - Returns a configuration object.  To be called after
    a call to initialize().

    parser($coderef) - Specifies a callback, which must be in the form
    of a code reference, to be used to parse the config ... end config
    block of the Peep configuration file for the client.

    callback($coderef) - Specifies a callback, which must be in the
    form of a code reference, to be used in the MainLoop method.

    MainLoop($sleep) - Starts the main loop.  If $sleep returns false,
    the callback is only called once; otherwise, the main loop sleeps
    $sleep seconds between each call to the callback.

    logger() - Returns a Net::Peep::Log object

    getConfigSection($section,@lines) - Retrieves a section by the
    name of $section from the lines of text @lines.  This is a utility
    method to assist with parsing sections from the Peep configuration
    file client config sections (e.g., the events section from the
    logparser definition in peep.conf).

    tempParseDefaults(@lines) - Parses a defaults section in a client
    config block in the Peep configuration file.  Note that this code
    duplicates the parseClientDefault method in Net::Peep::Parser.  It
    will be deprecated after backwards-compatibility of peep.conf is
    dropped, probably with the release of 0.5.0.

    getGroups() - Parses the 'groups' option and returns an array of groups.

    getExcluded() - Parses the 'excluded' option and returns a list of
    excluded groups.

=head1 AUTHOR

Michael Gilfix <mgilfix@eecs.tufts.edu> Copyright (C) 2000

Collin Starkweather <collin.starkweather@colorado.edu>

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Client::Logparser,
Net::Peep::Client::Sysmonitor, Net::Peep::BC, Net::Peep::Log.

http://peep.sourceforge.net

=head1 TERMS AND CONDITIONS

You should have received a file COPYING containing license terms
along with this program; if not, write to Michael Gilfix
(mgilfix@eecs.tufts.edu) for a copy.

This version of Peep is open source; you can redistribute it and/or
modify it under the terms listed in the file COPYING.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
