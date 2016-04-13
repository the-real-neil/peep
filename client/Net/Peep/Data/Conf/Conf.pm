package Net::Peep::Data::Conf;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
require Exporter;
use Net::Peep::Data;
use Net::Peep::Data::Conf::Classes;
use Net::Peep::Data::Conf::General;
use Net::Peep::Data::Sounds;
use Net::Peep::Data::Events;
use Net::Peep::Data::States;
use Net::Peep::Data::Themes;
use Net::Peep::Data::Clients;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter Net::Peep::Data);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub Name { return 'configuration'; } # end sub Name

sub Attributes {

	my $self = shift;
	my %attributes = ( );
	return wantarray ? %attributes : \%attributes;

} # end sub Attributes

sub Handlers {

	my $self = shift;
	my %handlers = ( 
			 general => 'Net::Peep::Data::Conf::General',
			 classes => 'Net::Peep::Data::Conf::Classes',
			 clients => 'Net::Peep::Data::Clients',
			 sounds => 'Net::Peep::Data::Sounds',
			 events => 'Net::Peep::Data::Events',
			 states => 'Net::Peep::Data::States',
			 themes => 'Net::Peep::Data::Themes'
			 );
	return wantarray ? %handlers : \%handlers;

} # end sub Handlers

1;

__END__

=head1 NAME

Net::Peep::Data::Conf - Perl extension for representing configuration
information.

=head1 SYNOPSIS

  use Net::Peep::Data::Conf;

=head1 DESCRIPTION

See the C<Net::Peep::Data> class for detailed information regarding Peep data
classes.

=head2 ATTRIBUTES

None.

=head2 HANDLERS

  Net::Peep::Data::Conf::Classes
  Net::Peep::Data::Conf::General
  Net::Peep::Data::Clients
  Net::Peep::Data::Events
  Net::Peep::Data::Sounds
  Net::Peep::Data::States
  Net::Peep::Data::Themes

=head1 AUTHOR

Collin Starkweather Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Data

http://peep.sourceforge.net

=cut
