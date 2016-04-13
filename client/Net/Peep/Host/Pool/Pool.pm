package Net::Peep::Host::Pool;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Socket;
require Exporter;
use Net::Peep::Log;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION $AUTOLOAD @Attributes $LOGGER };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = new Net::Peep::Log;

sub new {

    my $self = shift;
    my $class = ref($self) || $self;
    my $this = {};
    bless $this, $class;
    $this->{'HOSTS'} = [];
    $this;

} # end sub new

sub addHost {

    my $self = shift;
    my $host = shift || confess "Cannot add host to host pool:  Host not found.";
    push @{$self->{'HOSTS'}}, $host;
    return 1;

} # end sub addHost

sub hosts {

    my $self = shift;

    return wantarray ? @{$self->{'HOSTS'}} : $self->{'HOSTS'};

} # end sub hosts

sub getHostByName {

    my $self = shift;
    my $name = shift || confess "Cannot get host by name:  No name found.";

    my $return = undef;
    for my $host ($self->hosts()) {
	$return = $host if $host->name() eq $name or $host->name() eq 'localhost';
    }
    return $return;

} # end sub getHostByName

sub getHostByAddr {

    my $self = shift;
    my $addr = shift || confess "Cannot get host by IP address:  No address found.";

    my $return = undef;
    for my $host ($self->hosts()) {
	$return = $host if $host->ip() eq $addr or $host->ip() eq '127.0.0.1';
    }
    return $return;

} # end sub getHostByName

sub addHosts {

    my $self = shift;
    my $hosts = shift || confess "Cannot add hosts:  No hosts found.";

    my @hosts = split /\s*,\s*/, $hosts;
    for my $id (@hosts) {
	my $host = new Net::Peep::Host;
	if ($host->isIP($id)) {
	    $host->ip($id);
	} else {
	    $host->name($id);
	}
	$self->addHost($host);
    }
    return 1;

} # end sub addHosts    

sub isInHostPool {

    my $self = shift;
    my $nameOrIp = shift || confess "Cannot check whether host is in pool:  No host found.";

    my @hosts = $self->hosts();

    my $host = new Net::Peep::Host;

    my $got;
    if ($host->isIP($nameOrIp)) {
	$got = $self->getHostByAddr($nameOrIp);
    } else {
	$got = $self->getHostByName($nameOrIp);
    }

    return $got ? 1 : 0;

} # end sub isInHostPool

sub areInHostPool {

    my $self = shift;
    my @hosts = @_;

    my $host = new Net::Peep::Host;

    my $return = 0;
    for my $nameOrIp (@hosts) {
	my $got;
	if ($self->isIP($nameOrIp)) {
	    $got = $self->getHostByAddr($nameOrIp);
	} else {
	    $got = $self->getHostByName($nameOrIp);
	}
	$return++ if $got;
    }

    return $return;

} # end areInHostPool

1;

__END__

=head1 NAME

Net::Peep::Host::Pool - A pool, or group, of Net::Peep::Host objects

=head1 SYNOPSIS

  use Net::Peep::Host;

=head1 DESCRIPTION

A pool, or group, of Net::Peep::Host objects and associated methods
for thier usage and manipulation.

=head2 EXPORT

=head2 METHODS

  new() - The constructor.

  addHost($host) - Adds the host $host (a Net::Peep::Host object) to
  the host pool.

  hosts($host) - Returns the array of hosts in the host pool.

  getHostByName($name) - Returns the host with name $name from the
  host pool.  If no host is found with that name, it returns undef.

  getHostByAddr($ip) - Returns the host with IP address $ip.  If no
  host is found with that address, it returns undef.

  addHosts($string) - Takes a comma-delimited string of IP addresses
  or host names, parses them, and adds them to the host pool.

  isInHostPool($string) - Takes a host name or IP address and checks
  whether it is in the host pool.

  areInHostPool(@strings) - Takes a list of host names and/or IP
  addresses and checks whether any of them are in the host pool.

=head1 AUTHOR

Collin Starkweather (C) 2001.

=head1 SEE ALSO

perl(1), Net::Peep, Net::Peep::Host.

=cut
