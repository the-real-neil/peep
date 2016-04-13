package Net::Peep::Host;

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
$VERSION = do { my @r = (q$Revision: 1.3 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = new Net::Peep::Log;

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub name {

	# if the host name has been explicitly set, retrieve the set value
	# ... if not obtain the value by gethostbyaddr

	my $self = shift;
	if (@_) { 
	    $self->{'NAME'} = shift; 
	} else {
	    if (exists $self->{'NAME'}) {
		return $self->{'NAME'};
	    } elsif (exists $self->{'IP'}) {
		my $iaddr = inet_aton($self->{'IP'});
		my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyaddr($iaddr,AF_INET);
		$self->{'NAME'} = $name;
		return $name ? $name : undef;
	    } else {
		confess "Cannot obtain host name:  No host name or IP address has been specified.";
	    }
	}

} # end sub name

sub ip {

	# if the host IP address has been explicitly set, retrieve the set
	# value ... if not obtain the value by gethostbyname

	my $self = shift;
	if (@_) { 
	    $self->{'IP'} = shift; 
	} else {
	    if (exists $self->{'IP'}) {
		return $self->{'IP'};
	    } elsif (exists $self->{'NAME'}) {
		my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyname($self->{'NAME'});
		if (@addrs) {
		    my $ip = inet_ntoa($addrs[0]);
		    return $ip ? $ip : undef;
		} else {
		    confess "Cannot obtain IP address:  Could not get host by name for ".$self->{'NAME'}.".";
		}    
	    } else {
		confess "Cannot obtain IP address:  No host name or IP address has been specified.";
	    }
	}

} # end sub ip

sub isIP {

    my $self = shift;
    my $ip = shift || confess "Hostname or IP address not found.";

    return $ip =~ /^(\d+\.)+\d+$/ ? 1 : 0;

} # end sub isIP

1;

__END__

=head1 NAME

Net::Peep::Host - The Peep host object

=head1 SYNOPSIS

  use Net::Peep::Host;

=head1 DESCRIPTION

The Peep host object.  Used to characterize a host, including
attributes such as hostname and IP address.

=head2 EXPORT

=head2 METHODS

  new() - The constuctor.

  name([$name]) - Sets or gets the hostname of the host object.  If no
  hostname has been previously specified, it tries to retreive the
  hostname through the IP address returned by the ip() method.

  ip([$ip]) - Sets or gets the IP address of the host object.  If no IP
  address has been previously specified, it tries to retreive the IP
  address through the hostname returned by the name() method.

  isIP($ip) - Returns 1 if $ip is an IP address, 0 otherwise.  The
  determination is made by pattern matching..

=head1 AUTHOR

Collin Starkweather (C) 2001.

=head1 SEE ALSO

perl(1), Net::Peep, Net::Peep::HostPool.

=cut
