package Net::Peep::BC;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Data::Dumper;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION $SOCKET $BCSOCKET };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.27 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$SOCKET = {};

use Socket;
use Sys::Hostname;
use Net::Peep::Parser;
use Net::Peep::Conf;
use Net::Peep::Log;
use Net::Peep::Scheduler;

use vars qw{ %Leases %Servers %Defaults $Scheduler };

%Leases = %Servers = ();

%Defaults = (
	type => 0,
	location => 128,
	priority => 0,
	volume => 128,
	dither => 0,
	sound => 0
);

$Scheduler = new Net::Peep::Scheduler;

# Peep protocol constants:  See "Server Data Structures" in the Peep server
# documentation or server.h for more information.
use constant PROT_MAJOR_VER => 2;
use constant PROT_MINOR_VER => 0;
use constant PROT_BC_SERVER => 1 << 0;
use constant PROT_BC_CLIENT => 1 << 1;
use constant PROT_CLIENT_EVENT => 1 << 2;
use constant PROT_SERVER_STILL_ALIVE => 1 << 3;
use constant PROT_CLIENT_STILL_ALIVE => 1 << 4;
use constant PROT_CLASS_DELIM => '!';
use constant PROT_BY_NAME => 'tcp'; # the default protocol
use constant PROT_CONTENT_UNDEFINED => 0;
use constant PROT_CONTENT_XML =>   1 << 0;
use constant PROT_CONTENT_EVENT => 1 << 1;
use constant PROT_CONTENT_MSG =>   1 << 2;
use constant PROT_MAGIC_NUMBER =>   0xDEADBEEF;

use constant INTERVAL =>   90; # every 90 seconds
use constant BC_INTERVAL =>   40; # every 90 seconds x 40 = 1 hour

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

	$this->initialize(@_);

	return $this;

} # end sub new

END {
	print STDERR "Closing all open sockets ...\n";
	if (keys %$SOCKET) {
		for my $key (keys %$SOCKET) {
			$key =~ /(.*):(udp|tcp)/;
			my ($server,$protocol) = ($1,uc($2));
			my ($serverport,$serverip) = unpack_sockaddr_in($server);
			$serverip = inet_ntoa($serverip);
			print STDERR "\tClosing [$protocol] socket connection to [$serverip:$serverport] ...\n";
			close $SOCKET->{$key};
		}
	} else {
		print STDERR "\tThere are no open sockets.\n";
	}
	print STDERR "Done.\n";
} 

sub initialize {

	my $self = shift;
	my $conf = shift || confess "Error:  Configuration not found";
	my $client = $conf->client() || confess "Error:  Client not found";

	# put the configuration object in a place where all the other
	# methods can find it
	$self->conf($conf);

	# Make allowances for the two possible meanings of dither
	# dither is based exclusively on the value of 'type'
	# $conf->optionExists('type') && $conf->getOption('type') ? $conf->setOption('dither',255) : $conf->setOption('dither',0);

	# Now initialize our socket
	$self->logger()->debug(1,"Getting port for client [$client] ...");
	my $port = $conf->getClientPort($client);
	$self->logger()->debug(7,"Initializing socket on port [$port] ...");
	my $addr = INADDR_ANY;
	my $proto = getprotobyname('udp');
	my $paddr = sockaddr_in($port, $addr);
	socket($BCSOCKET, PF_INET, SOCK_DGRAM, $proto) or confess "Socket error: $!";
	bind($BCSOCKET, $paddr) or confess "Bind error: $!";
	$self->logger()->debug(7,"\tSocket initialized.");
	# Set the socket option for the broadcast
	setsockopt $BCSOCKET, SOL_SOCKET, SO_BROADCAST, 1;
	setsockopt $BCSOCKET, SOL_SOCKET, SO_REUSEADDR, 1;

	if ($conf->getOption($client,'autodiscovery')) {
		$self->hello( PROT_BC_CLIENT );
	}


	# If we're using autodiscovery, let everyone know we're alive.  Then
	# start up the alarm. Once this handler gets started, we'll have it
	# work concurrently with the program to handle host lists
	$self->updateserverlist();
	$self->purgeserverlist();
	$Scheduler->schedulerAddEvent(
			$client,
			INTERVAL,
			0.0,
			'client',
			sub { $self->handlealarm( PROT_CLIENT_STILL_ALIVE ) },
			'',
			1 # 1 => repeated event, 0 => single event
			);

	$self->cacheServers() unless $conf->getOption($client,'autodiscovery');

} # end sub initialize

sub hello {

	my $self = shift;
	my $constant = shift;
	my $recipient = shift;
	my $conf = $self->conf() || confess "Error:  Configuration not found";
	my $client = $conf->client();

	if (defined($recipient) && $recipient) {
		my ($serverport,$serverip) = unpack_sockaddr_in($recipient);
		$serverip = inet_ntoa($serverip);
		my $packet = $self->assemble_bc_packet($constant);
		if (defined($constant) && $constant == PROT_CLIENT_STILL_ALIVE) {
			$self->logger()->debug(7,"Letting [$serverip:$serverport] know we're still alive ...");
		} elsif (defined($constant) && $constant == PROT_BC_CLIENT) {
			$self->logger()->debug(7,"Sending [$serverip:$serverport] a broadcast packet ...");
		} else {
			$self->logger()->debug(7,"Saying hello to [$serverip:$serverport] ...");
		}
		if (my $socket = $self->getSocket($recipient,'udp')) {
			print { $socket } $packet;
			$self->logger()->debug(7,"Packet sent.") ;
		} else {
			$self->logger()->debug(7,"Packet not sent:  Could not get socket for [$serverip:$serverport].") ;
		}
	} elsif (defined($constant) && $constant == PROT_CLIENT_STILL_ALIVE) {

		my $protocol = $conf->getOption($client,'protocol');
		if ($protocol eq 'udp') {

			my %servers;
			if ($conf->getOption($client,'autodiscovery')) {

				for my $server (keys %Servers) {
					my ($serverport,$serverip) = unpack_sockaddr_in($server);
					$serverip = inet_ntoa($serverip);
					$servers{"$serverip:$serverport"} = $server;
				}

			} else {

				%servers = %{$self->getCachedServers()} if defined $self->getCachedServers();

			}
			my $packet = $self->assemble_bc_packet($constant);
			for my $key (sort keys %servers) {
				my $server = $servers{$key};
				$self->logger()->debug(7,"Letting [$key] know we're still alive ...");
				if (my $socket = $self->getSocket($server,'udp')) {
					print { $socket } $packet;
					$self->logger()->debug(7,"Packet sent.") ;
				} else {
					$self->logger()->debug(7,"Packet not sent:  Could not get socket for [$key].") ;
				}
			}
		}

	} elsif (defined($constant) && $constant == PROT_BC_CLIENT) {

		# Send out our broadcast to let everybody know we're alive
		# Note - we want to send these broadcasts to the servers within
		# the class definition. So, we use getServer() - Mike
		my ($classes) = $conf->classes();
		if (defined $classes) {
			my @classes = $classes->class();
			for my $class ($classes->class()) {
				my $name = $class->name();
				$self->logger()->debug(7,"Getting broadcast for class [$name]");

				my ($servers) = $class->servers();
				my @servers = $servers->server();

				my %ports;
				for my $server (@servers) { $ports{$server->port()}++ }

				for my $port (sort { $a <=> $b } keys %ports) {

					# Assemble the packet and send it
					my $packet = $self->assemble_bc_packet($constant);

					my $zone = inet_ntoa(INADDR_BROADCAST);
					my $iaddr = inet_aton($zone);
					my $bcaddr = sockaddr_in($port, INADDR_BROADCAST);
					$self->logger()->debug(7,"Socketing to zone [$zone] and port [$port] ...");
					$self->logger()->debug(7,"Sending a friendly hello to address [$zone:$port] ...");

					if (defined(CORE::send($BCSOCKET, $packet, 0, $bcaddr))) {
						$self->logger()->debug(7,"\tPacket of length ".length($packet)." sent.");
					} else {
						$self->logger()->log("Send broadcast error: $!");
					}
				}
			}
		} 

	} else {

		# do nothing

	}

} # end sub hello

sub conf {

    my $self = shift;
    if (@_) { $self->{'CONF'} = shift; }
    return $self->{'CONF'};

} # end sub conf

# Function to assemble a broadcast packet with an appropriate
# identifier string
sub assemble_bc_packet {

	my $self = shift;
	my $constant = shift;
	my $conf = $self->conf();
	my ($classes) = $conf->classes();
	my @classes = $classes->class();
	my $identifier = join '', map { $_->name() . PROT_CLASS_DELIM } @classes;
	$self->logger()->debug(7,"Assembled broadcast packet with header:") ;
	$self->logger()->debug(7,"\tversion: [".PROT_MAJOR_VER."]") ;
	$self->logger()->debug(7,"\ttype: [".$constant."]") ;
	$self->logger()->debug(7,"\tcontent: [".PROT_CONTENT_MSG."]") ;
	$self->logger()->debug(7,"\tmagic: [0x".sprintf('%X',PROT_MAGIC_NUMBER)."]") ;
	$self->logger()->debug(7,"\tlen: [".length($identifier)."]") ;
	return pack("C8N2A128", 
		PROT_MAJOR_VER,      # major version
		$constant,           # the packet type
		PROT_CONTENT_MSG,    # contents format
		0,0,0,0,0,           # reserved
		PROT_MAGIC_NUMBER,   # a wee bit o' magic
		length($identifier),
		$identifier);

} # end sub assemble_bc_packet

# returns a logging object
sub logger {

	my $self = shift;
	if ( not exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
	return $self->{'__LOGGER'};

} # end sub logger

sub cacheServers {

	# cache a reference to a hash of servers for later reference
	my $self = shift;
	my $conf = $self->conf() || confess "Error:  Net::Peep::Conf object expected but not found!";
	my $client = $conf->client();
	my $object = $conf->getClient($client);
	my ($classes) = $conf->classes();
	my %servers;
	if (not $conf->getOption('autodiscovery')) {
		if ($conf->optionExists('server') && $conf->optionExists('port')) {
			my $serverport = $conf->getOption('port') || confess "Error:  Expecting nonzero port!";
			my $serverhost = $conf->getOption('server') || confess "Error:  Expecting hostname!";
			$self->logger()->debug(7,"\tFound client server [$serverhost:$serverport]");
			my $host = inet_aton($serverhost);
			my $server = sockaddr_in($serverport,$host);
			$servers{"$serverhost:$serverport"} = $server;
		}
	}

	if (defined $classes) {
		my @classes = $classes->class();
		for my $class (@classes) {
			$self->logger()->debug(7,"Checking class [".$class->name()."] against client class [".$object->class()."]");
			if ($class->name() eq $object->class()) {
				$self->logger()->debug(7,"\tThe client [$client] has class [".$class->name()."]");
				my ($servers) = $class->servers();
				if (defined($servers)) {
					my @servers = $servers->server();
					for my $server (@servers) {
						my $serverport = $server->port() || confess "Error:  Expecting nonzero port!";
						my $serverhost = $server->name() || confess "Error:  Expecting hostname!";
						$self->logger()->debug(7,"\tFound client server [$serverhost:$serverport]");
						my $host = inet_aton($serverhost);
						my $server = sockaddr_in($serverport,$host);
						$servers{"$serverhost:$serverport"} = $server unless exists $servers{"$serverhost:$serverport"};
					}
				} else {
					$self->logger()->debug(7,"\tNo servers could be found for class [".$class->name()."]");
				}

			}
		}
	}
	$self->{__SERVER_CACHE__} = \%servers;
	return $self->{__SERVER_CACHE__};

} # end sub cacheServers

sub getCachedServers {

	# cache a reference to a hash of servers for later reference
	my $self = shift;
	return exists($self->{__SERVER_CACHE__}) ? $self->{__SERVER_CACHE__} : undef;

} # end sub getCachedServers 

# Send out a packet
sub send {

	my $self = shift;
	my $notice = shift;

	my $conf = $self->conf();
	my $client = $conf->client();

	my $host = $notice->host();
	my $type = $notice->type() eq 'state' ? 1 : 0;
	my $location = $notice->location();
	my $priority = $notice->priority();
	my $volume = $notice->volume();
	my $dither = $notice->dither();
	my $sound = $notice->sound();

	$self->logger()->debug(7,"Sending client [$client] packet to server(s) from host [$host] ...");
	$self->logger()->debug(7,"Notice:");
	$self->logger()->debug(7,"	type: [$type]");
	$self->logger()->debug(7,"	sound: [$sound]");
	$self->logger()->debug(7,"	location: [$location]");
	$self->logger()->debug(7,"	priority: [$priority]");
	$self->logger()->debug(7,"	volume: [$volume]");
	$self->logger()->debug(7,"	dither: [$dither]");

	my %servers;

	if ($conf->getOption($client,'protocol') eq 'tcp') {
		if ($conf->getOption($client,'autodiscovery')) {
			for my $server (keys %Servers) {
				my ($serverport,$serverip) = unpack_sockaddr_in($server);
				$serverip = inet_ntoa($serverip);
				$servers{"$serverip:$serverport"} = $server;
			}
		} else {
			%servers = %{$self->getCachedServers()};
		}
	} else {
		if ($conf->getOption($client,'autodiscovery')) {

			for my $server (keys %Servers) {
				my ($serverport,$serverip) = unpack_sockaddr_in($server);
				$serverip = inet_ntoa($serverip);
				$servers{"$serverip:$serverport"} = $server;
			}

		} else {
			if (exists $self->{__SERVER_CACHE__}) {
				%servers = %{$self->{__SERVER_CACHE__}};
			} else {
				my $serverport = $conf->getOption($client,'port') || confess "Error:  Expecting nonzero port!";
				my $serverhost = $conf->getOption($client,'server') || confess "Error:  Expecting nonzero host!";
				$host = inet_aton($serverhost);
				my $server = sockaddr_in($serverport,$host);
				$servers{"$serverhost:$serverport"} = $server;
				$self->{__SERVER_CACHE__} = \%servers;
			}
		}
	}

	if (keys %servers) {
		$self->logger()->debug(7,"\tThe notice will be sent to the following servers:  [".(join ',', sort keys %servers)."].");
		for my $server (sort keys %servers) {
			$self->sendout($notice,$servers{$server});
		}
	} else {
		$self->logger()->debug(7,"\tUh oh!  There are no known servers.  The notice will not be sent after all.");
	}


} # end sub send

sub sendout {

	my $self = shift;
	my ($notice,$server) 
	    = @_;

	my $conf = $self->conf();

	my $type = $notice->type();
	my $sound = $notice->sound();
	my $location = $notice->location();
	my $priority = $notice->priority();
	my $volume = $notice->volume();
	my $dither = $notice->dither();

	my $mix_in_time = 0;

	my ($serverport,$serverip) = unpack_sockaddr_in($server);
	$serverip = inet_ntoa($serverip);

	my $xml = $notice->serialize();

	my $protocol = $conf->optionExists('protocol') ? $conf->getOption('protocol') : PROT_BY_NAME;

	if ($protocol eq 'tcp') {

		my $eol = "\015\012";
		my $length = length($xml.$eol);

		$self->logger()->debug(7,"Packet header bound for [$serverip:$serverport]:") ;
		$self->logger()->debug(7,"	version: [".PROT_MAJOR_VER."]") ;
		$self->logger()->debug(7,"	type: [".PROT_CLIENT_EVENT."]") ;
		$self->logger()->debug(7,"	content: [".PROT_CONTENT_XML."]") ;
		$self->logger()->debug(7,"	magic: [0x".sprintf('%X',PROT_MAGIC_NUMBER)."]") ;
		$self->logger()->debug(7,"	len: [$length]") ;
		$self->logger()->debug(9,"	XML: [\n$xml]") ;

		my $packet = pack("C8N2A$length", 
				PROT_MAJOR_VER,     # major version
				PROT_CLIENT_EVENT,  # type of packet
				PROT_CONTENT_XML, # contents format
				0,0,0,0,0,          # reserved
				PROT_MAGIC_NUMBER,  # a wee bit o' magic
				$length,
				"$xml$eol");

		if (my $socket = $self->getSocket($server,'tcp')) {
			print { $socket } $packet;
			$self->logger()->debug(7,"Packet sent.") ;
		} else {
			$self->logger()->debug(7,"Packet not sent:  Could not get socket for [$serverip:$serverport].") ;
		}

	} else {

		# the protocol is udp
		my $packed = $notice->getContentEvent();
		my $length = length($packed);

		$self->logger()->debug(7,"Packet header bound for [$serverip:$serverport]:") ;
		$self->logger()->debug(7,"	version: [".PROT_MAJOR_VER."]") ;
		$self->logger()->debug(7,"	type: [".PROT_CLIENT_EVENT."]") ;
		$self->logger()->debug(7,"	content: [".PROT_CONTENT_EVENT."]") ;
		$self->logger()->debug(7,"	magic: [0x".sprintf('%X',PROT_MAGIC_NUMBER)."]") ;
		$self->logger()->debug(7,"	len: [$length]") ;

		my $packet = pack("C8N2A$length", 
				PROT_MAJOR_VER,     # major version
				PROT_CLIENT_EVENT,  # type of packet
				PROT_CONTENT_EVENT, # contents format
				0,0,0,0,0,          # reserved
				PROT_MAGIC_NUMBER,  # a wee bit o' magic
				$length,
				$packed);

		if (my $socket = $self->getSocket($server,'udp')) {
			print { $socket } $packet;
			$self->logger()->debug(7,"Packet sent.") ;
		} else {
			$self->logger()->debug(7,"Packet not sent:  Could not get socket for [$serverip:$serverport].") ;
		}

	}


#	if (not defined(CORE::send(SOCKET, $packet, 0, $server))) {
#		$self->logger()->debug(7,"Error sending TCP packet to [$serverip:$serverport]:  $!");
#		$self->logger()->debug(7,"You may want to check that the server is accepting connections on port [$serverport].");
#	}

	return 1;

} # end sub sendout

sub getLastBCInterval {

	my $self = shift;
	return $self->{__LAST_BC_INTERVAL__};

} # end sub getLastBCInterval

sub incrementLastBCInterval {

	my $self = shift;
	return $self->{__LAST_BC_INTERVAL__}++;

} # end sub incrementLastBCInterval

sub resetLastBCInterval {

	my $self = shift;
	return $self->{__LAST_BC_INTERVAL__} = 0;

} # end sub resetLastBCInterval

sub handlealarm {

	#Every tick, we wait until we have some input to respond to, then update
	#our server list. Finally, we purge the server list of any impurities and
	#carry on with out business
	my $self = shift;
	my $constant = shift;

	if (scalar(keys %Servers)) {
		$self->logger()->debug(9,"Known servers:");
		for my $server (sort keys %Servers) {
			my ($serverport,$serverip) = unpack_sockaddr_in($server);
			$serverip = inet_ntoa($serverip);
			$self->logger()->debug(9,"\t[$serverip:$serverport]");
		}
		$self->hello($constant);
		$self->resetLastBCInterval();

	} else {
		$self->logger()->debug(9,"There are currently no known servers.");
		$self->logger()->debug(9,"\tPerhaps we should send a broadcast to let any running servers know we're alive ...");
		$self->incrementLastBCInterval();
		if ($self->getLastBCInterval() > BC_INTERVAL) {
			$self->logger()->debug(9,"\t\tSending a broadcast packet ...");
			$self->hello( PROT_BC_CLIENT );
			$self->resetLastBCInterval();
		} else {
			my $difference = BC_INTERVAL - $self->getLastBCInterval();
			# for reasons unknown to me I like my log messages to be grammatically correct
			my $intervals = $difference == 1 ? 'interval' : 'intervals';
			$self->logger()->debug(9,"\t\tLet's wait another [$difference] $intervals.");
		}
	}

	$self->updateserverlist();
	$self->purgeserverlist();
	return 1;

} # end sub handlealarm

sub updateserverlist {

	#Poll to see if we've received anything so we can update the server list 
	#before we send. Then, send out the packet.
	my $self = shift;

	$self->logger()->debug(9,"Updating server list ...");

	my $rin = "";
	my $rout;
	vec($rin, fileno($BCSOCKET), 1) = 1;

	while (select($rout = $rin, undef, undef, 0.1)) {
		my $packet;

		$self->logger()->debug(7,"\tReading from socket ...");

		my $server = recv($BCSOCKET, $packet, 256, 0);  # 256 is safe amount to read
		# Adding a defined argument here because recv can produce errors if
		# a broadcast isn't responded to. Plus, we want to continue anyway.
		if (defined($server) and $server ne '') {
			my ($serverport,$serverip) = unpack_sockaddr_in($server);
			$serverip = inet_ntoa($serverip);

			$self->logger()->debug(7,"\tJust received a packet from [$serverip:$serverport] ...");

			#Verify that this is a server bc packet
			my ($majorver, $type, $format, $null0, $null1, $null2, $null3, $null4, $magic, $padding) = unpack("C8N2A128", $packet);
			$self->logger()->debug(7,"\tUnpacked packet:") ;
			$self->logger()->debug(7,"\t\tmajor version: [$majorver]") ;
			$self->logger()->debug(7,"\t\ttype: [$type]") ;
			$self->logger()->debug(7,"\t\tformat: [$format]") ;
			$self->logger()->debug(7,"\t\tmagic: [0x".sprintf('%X',$magic)."]") ;

			if ($magic == PROT_MAGIC_NUMBER) {
				if ($type == PROT_BC_SERVER) {
					$self->logger()->debug(7,"\tTrying to add new server at [$serverip:$serverport]");
					if ($self->addnewserver($server, $packet)) {
						$self->hello(PROT_BC_CLIENT,$server);
					}
				} elsif ($type == PROT_SERVER_STILL_ALIVE) {
					$self->logger()->debug(7,"\tUpdating server at [$serverip:$serverport]");
					$self->updateserver($server, $packet);
				} else {
					$self->logger()->log("Warning:  Packet type [$type] not recognized.");
				}
			} else {
				$self->logger()->debug(7,"\tReceived packet with bad magic number.  Discarding.");
			}
		}
	}

} # end updateserverlist

sub purgeserverlist {

	my $self = shift;

	$self->logger()->debug(9,"Purging server list ...");

	for my $server (keys %Servers) {
		if ($Servers{$server}->{'expires'} <= time()) {
			delete $Servers{$server};
			$self->logger()->debug(7,"\tServer purged. Number of known servers: " . scalar (keys %Servers));

			for my $known (keys %Net::Peep::Servers) {
				my ($serverport,$serverip) = unpack_sockaddr_in($server);
				$serverip = inet_ntoa($serverip);
				$self->logger()->debug(7,"\t\t$serverip:$serverport");
			}
		}
	}

} # end sub purgeserverlist

sub addnewserver {

	my $self = shift;

	my ($server, $packet) = @_;

	my $conf = $self->conf();

	my ($serverport,$serverip) = unpack_sockaddr_in($server);

	$serverip = inet_ntoa($serverip);

	# Check if this server already exists - because then we shouldn't be
	# doing an add... so abort. This can happen because when the client
	# registers with the server, the server always sends a BC response
	# directly back to the client to make sure that the client really
	# has the server in its hostlist
	if (exists $Servers{$server}) {
		$self->logger()->debug(7,"\tServer [$serverip:$serverport] won't be added to the server list:  It is already in the list.");
		return 0;
	}

	my ($majorver, $type, $format, $null0, $null1, $null2, $null3, $null4, $magic, $length, $id) = unpack("C8N2A128", $packet);
	$self->logger()->debug(7,"\tUnpacked packet:") ;
	$self->logger()->debug(7,"\t\tmajor version: [$majorver]") ;
	$self->logger()->debug(7,"\t\ttype: [$type]") ;
	$self->logger()->debug(7,"\t\tformat: [$format]") ;
	$self->logger()->debug(7,"\t\tmagic: [0x".sprintf('%X',$magic)."]") ;
	$self->logger()->debug(7,"\t\tlen: [$length]") ;
	$self->logger()->debug(7,"\t\tid: [$id]") ;
	my $delim = PROT_CLASS_DELIM;

	#Clean up the ID string
	$id =~ /([A-Za-z0-9!\-]*)/;
	my $realid = $1;

	my ($classes) = $conf->classes();
	my @classes = $classes->class();
	foreach my $class (@classes) {
		my $name = $class->name();
		my $str = quotemeta($name.$delim);
		$self->logger()->debug(7,"\tChecking server id [$realid] against class descriptor [$name$delim] ....");

		if ($realid =~ /^$str$/) {
			$self->logger()->debug(7,"\tMatch found:  Adding server [$serverip:$serverport] to the server list.");
			$self->addserver($server,$packet);
		} else {
			$self->logger()->debug(7,"\tNo match found.  Nothing added to server list.");
		}
	}

	return 1;

} # end sub addnewserver

sub addserver {

	my $self = shift;

	# the server doesn't seem to be sending a lease 
	# my ($server,$leasemin,$leasesec) = @_;

	# confess "Error:  No lease duration specified."
	#	unless $leasemin or $leasesec;

	my ($server,$packet) = @_;

	my ($serverport,$serverip) = unpack_sockaddr_in($server);
	$serverip = inet_ntoa($serverip);

	# start the server off with a lease of 5 minutes
	my ($min,$sec) = (5,0);
	$self->logger()->debug(7,"\t\tThe new server will be given an initial lease of $min minutes.");

	$Servers{$server}->{'IP'} = $server;
	$Servers{$server}->{'expires'} = time() + $min*60 + $sec;

	$self->logger()->debug(7,"\t\tServer added. Number of known servers: " . scalar(keys %Servers));
	for my $known (keys %Net::Peep::Servers) {
		my ($serverport,$serverip) = unpack_sockaddr_in($known);
		$serverip = inet_ntoa($serverip);
		$self->logger()->debug(7,"\t\t$serverip:$serverport");
	}

	#Let's send it a "BC" to tell it to add us as well
	#$self->logger()->debug(7,"\tSending client BC packet to [$serverip:$serverport] ...");
	#defined(CORE::send($BCSOCKET, $self->assemble_bc_packet(PROT_BC_CLIENT), 0, $server)) or confess "Send client broadcast error: $!";
	#$self->logger()->debug(7,"\tClient BC packet sent successfully.");

	return 1;

} # end sub addserver

sub updateserver {

	my $self = shift;
	my $server = shift;
	my $packet = shift;
	my ($serverport,$serverip) = unpack_sockaddr_in($server);
	$serverip = inet_ntoa($serverip);
	my ($majorver, $type, $format, $null0, $null1, $null2, $null3, $null4, $magic, $len, $min, $sec) = unpack("C8I2C2", $packet);

	# a creature comfort:  only the friendliest of output for our esteemed users
	my $minutes = $min != 1 ? 'minutes' : 'minute';
	my $seconds = $sec != 1 ? 'seconds' : 'second';
	$self->logger()->debug(7,"\t$min $minutes and $sec $seconds were added to the lease of the server.");
	$self->logger()->debug(7,"\tNumber of known servers: " . scalar(keys %Servers));

	$Servers{$server}->{'expires'} = time() + $min*60 + $sec;

	# New send out a client alive
	#my $net_packet = pack ("C8N2A128",
	#	PROT_MAJOR_VER,          # major version
	#	PROT_CLIENT_STILL_ALIVE, # the packet type
	#	PROT_CONTENT_MSG,        # contents format
	#	0,0,0,0,0,               # reserved
	#	PROT_MAGIC_NUMBER,       # a wee bit o' magic
	#	length(0),
	#	0);

	#$self->logger()->debug(7,"\tAssembled still alive packet with header:") ;
	#$self->logger()->debug(7,"\t\tversion: [".PROT_MAJOR_VER."]") ;
	#$self->logger()->debug(7,"\t\ttype: [".PROT_CLIENT_STILL_ALIVE."]") ;
	#$self->logger()->debug(7,"\t\tcontent: [".PROT_CONTENT_MSG."]") ;
	#$self->logger()->debug(7,"\t\tmagic: [0x".sprintf('%X',PROT_MAGIC_NUMBER)."]") ;
	#$self->logger()->debug(7,"\t\tlen: [".length(0)."]") ;

	#$self->logger()->debug(7,"\tSending client still alive packet ...");

	#if (defined(CORE::send($BCSOCKET, $net_packet, 0, $server))) {
	#	$self->logger()->debug(7,"\t\tClient still alive packet sent successfully.");
	#} else {
	#	$self->logger()->log("Warning:  Send client still alive error: $!"); 
	#}

	return 1;

} # end sub updateserver

sub getSocket {

	my $self = shift;
	my $server = shift || confess "Error:  A server description was not provided to the getSocket() method.";
	my $protocol = shift || confess "Error:  A protocol name was not provided to the getSocket() method.";;

	my ($serverport,$serverip) = unpack_sockaddr_in($server);
	$serverip = inet_ntoa($serverip);

	unless (exists $SOCKET->{"$server:$protocol"}) {
		my $proto = getprotobyname ($protocol);
		my $type = $protocol eq 'tcp' ? SOCK_STREAM : SOCK_DGRAM;
		socket ($SOCKET->{"$server:$protocol"}, PF_INET, $type, $proto) or die "Error creating [$protocol] socket: $!";
		if (connect ($SOCKET->{"$server:$protocol"}, $server)) { 
			setsockopt $SOCKET->{"$server:$protocol"}, SOL_SOCKET, SO_REUSEADDR, 1;
			select ($SOCKET->{"$server:$protocol"}); $| = 1; select (STDOUT);
			$self->logger()->debug(6,"Initiated [".uc($protocol)."] socket for server [$serverip:$serverport] ...");
		} else {
			warn "Error connecting to socket on [$serverip:$serverport]: $!";
			delete $SOCKET->{"$server:$protocol"};
		}
	} else {
		$self->logger()->debug(6,"Found existing [".uc($protocol)."] socket for server [$serverip:$serverport] ...");
	}

	return $SOCKET->{"$server:$protocol"};

} # end sub getSocket 

1;

__END__

=head1 NAME

Net::Peep::BC - Perl extension for Peep: The Network Auralizer

=head1 SYNOPSIS

  use Net::Peep::BC;
  my $bc = new Net::Peep::BC;
  $bc->send($notice,$server);

=head1 DESCRIPTION

Net::Peep::BC is a broadcast library for Peep: The Network Auralizer.
It contains methods that allow Peep clients to communicate events and
other information to the Peep server.

=head2 EXPORT

None by default.

=head2 CONSTANTS

See the "Server Data Structures" of the Peep server documentation for more
information regarding the usage of the constants.

  PROT_MAJOR_VER

  PROT_MINOR_VER

  PROT_BC_SERVER

  PROT_BC_CLIENT

  PROT_SERVER_STILL_ALIVE

  PROT_CLIENT_STILL_ALIVE

  PROT_CLIENT_EVENT

  PROT_CLASS_DELIM

  INTERVAL - The amount of time (in seconds) between when the alarm
  handler (see the handlealarm method) is set and the SIGALRM signal
  is sent.

  BC_INTERVAL - The number of intervals between sending broadcasts.
  A broadcast packet is sent when a client is first initialized
  and then only when no servers have been detected 

=head2 CLASS ATTRIBUTES

  %Leases - Deprecated

  %Servers - A hash the keys of which are the servers found by
  autodiscovery methods (i.e., methods in which clients and servers
  notify each other of their existence) and the values of which are
  anonymous hashes containing information about the server, including
  an expiration time after which if the client has not heard from the
  server, the server is deleted from the %Servers hash.

  %Defaults - Default values for options such as 'priority', 'volume',
  'dither', 'sound'.


=head2 PUBLIC METHODS

Note that this section is somewhat incomplete.  More
documentation will come soon.

    new($conf) - Net::Peep::BC constructor.  $conf is a
    Net::Peep::Conf object.  If an option is not specified in the
    configuration object, the equivalent value in the %Defaults class
    attributes is used.

    send($notice) - Sends a packet including information on
    sound, location, priority, volume etc. to each server specified in
    the %Servers hash.

    assemble_bc_packet() - Assembles the broadcast packet.  Duh.

    logger() - Returns a Net::Peep::Log object used for log messages and
    debugging output.

    sendout($notice,$server) - Used by send() to send the $notice
    packet to the server $server.

    handlealarm() - Refreshes and purges the server list.  Schedules
    the next SIGALRM signal to be issued in another INTERVAL
    seconds.

    updateserverlist() - Polls to see if any of the servers have sent
    alive broadcasts so that the server list can be updated.

    purgeserverlist() - Removes servers from the server list if they
    have not sent an alive broadcast within their given expiration
    time.

    addnewserver($server,$packet) - Adds the server $server based on
    information provided in the packet $packet.  The server is only
    added if it does not exist in the %Servers hash.  The server is
    pysically added by a call to the addserver method.

    addserver($server,$leasemin,$leasesec) - Adds the server $server.
    The server is expired $leasemin minutes and $leasesec seconds
    after being added if it has not sent an alive message in the
    meantime.  Sends the server a client BC packet.

    updateserver($server,$packet) - Updates the expiration time for
    server $server.  Sends the server a client still alive message.

=head2 PRIVATE METHODS

    initialize(%options) - Net::Peep::BC initializer.  Called from the
    constructor.  Performs the following actions:

      o Sets instance attributes via the %options argument
      o Loads configuration information from configuration file
        information passed in through the %options argument
      o Opens a socket and broadcasts an 'alive' message
      o Starts up the alarm.  Every INTERVAL seconds, the 
        alarm handler updates the server list.

=head1 AUTHOR

Michael Gilfix <mgilfix@eecs.tufts.edu> Copyright (C) 2000

Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2000

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Dumb, Net::Peep::Log, Net::Peep::Parser, Net::Peep::Log.

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
