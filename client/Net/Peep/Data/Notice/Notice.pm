package Net::Peep::Data::Notice;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
require Exporter;
use Sys::Hostname;
use Net::Peep::Data;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter Net::Peep::Data);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = $class->SUPER::new();
	bless $this, $class;

} # end sub new

sub Name { return 'notice'; } # end sub Name

sub Attributes {

	my $self = shift;
	my %attributes = ( 
			   host => 1,
			   client => 1,
			   type => 1,
			   sound => 1,
			   flags => 1,
			   location => 1,
			   priority => 1,
			   volume => 1,
			   dither => 1,
			   metric => 1,
			   data => 'CDATA',
			   date => 1, 
			   level => 1
			   );
	return wantarray ? %attributes : \%attributes;

} # end sub Attributes

sub Handlers {

	my $self = shift;
	my %handlers = ( );
	return wantarray ? %handlers : \%handlers;

} # end sub Handlers

sub deserialize {

	my $self = shift;
	my $xml = shift;

	my $return = $self->SUPER::deserialize($xml);

	$self->{'host'} = hostname() unless exists $self->{'host'}; # prepopulate the host field in case someone forgets

	return $return;

} # end sub deserialize

sub getContentEvent {

	my $self = shift;

	my $type = $self->type();
	my $loc = $self->location();
	my $prior = $self->priority();
	my $vol = $self->volume();
	my $dither = $self->dither();
	my $flags = $self->flags();

	my $sound = $self->sound();
	my $len = length($sound);

	my $packed = pack("C8N2A$len", $type, $loc, $prior, $vol, $dither, 0, 0, 0, $flags, $len, $sound);

	return $packed;

} # end sub getContentEvent

1;

__END__

=head1 NAME

Net::Peep::Data::Notice - Perl extension representing a client notice which is
sent from a Peep client to server to indicate a state or event.

=head1 SYNOPSIS

  use Net::Peep::Data::Notice;

=head1 DESCRIPTION

See the C<Net::Peep::Data> class for detailed information regarding Peep data
classes.

=head2 ATTRIBUTES

  host
  client
  type
  sound
  flags
  location
  priority
  volume
  dither
  metric
  data
  date
  level

=head2 HANDLERS

None.

=head2 METHODS

  getContentEvent() - Returns a packed string which represents a 
  CONTENT_EVENT structure to the Peep server.

=head1 AUTHOR

Collin Starkweather Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Data

http://peep.sourceforge.net

=cut
