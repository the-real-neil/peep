package Net::Peep::Data::Client;

use 5.006;
use strict;
use warnings;

require Exporter;
use Net::Peep::Data;
use Net::Peep::Data::Options;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter Net::Peep::Data);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub Name { return 'client'; } # end sub Name

sub Attributes {

	my $self = shift;
	my %attributes = ( 
			   name => 1, 
			   class => 1, 
			   port => 1,
			   configuration => 1
			   );
	return wantarray ? %attributes : \%attributes;

} # end sub Attributes

sub Handlers {

	my $self = shift;
	my %handlers = ( 'options' => 'Net::Peep::Data::Options' );
	return wantarray ? %handlers : \%handlers;

} # end sub Handlers


1;

__END__

=head1 NAME

Net::Peep::Data::Client - Perl extension for representing client configuration
information.

=head1 SYNOPSIS

  use Net::Peep::Data::Client;

=head1 DESCRIPTION

See the C<Net::Peep::Data> class for detailed information regarding Peep data
classes.

=head2 ATTRIBUTES

  name
  class
  port
  configuration

=head2 HANDLERS

  Net::Peep::Data::Options

=head1 AUTHOR

Collin Starkweather Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::BC, Net::Peep::Parser, Net::Peep::Log.

http://peep.sourceforge.net

=cut
