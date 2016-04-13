package Net::Peep::Data::XML;

require 5.005;
use strict;
use Carp;
use Data::Dumper;
use Net::Peep::Log;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( );
@EXPORT_OK = ( );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;

} # end sub new

sub clean {

    # clean up any problems that would vex XML::Parser in parsing a
    # string
    my $self = shift;
    my $string = shift;
    return undef unless defined $string; # throws a warning otherwise
    # extract wierd characters such as umlauts
    my $match = '\w\s' . quotemeta('!@#$%^&*()-_=+\|{}[];:",<.>/?`~' . qq{\'});
    $string =~ s/[^$match]//gs;
    # extract what would otherwise appear to be 'undefined entities'
    # to XML::Parser
    my @entities = $string =~ /(\&\w+\;)/g;
    my %entities;
    $entities{$_}++ foreach @entities;
    for my $entity (grep !/&(lt|gt);/, keys %entities) {
	my $match = quotemeta($entity);
	$string =~ s/$match/ /gs;
    }
    return $string;

} # end sub clean

sub unmark {

    my $self = shift;
    my $string = shift;
    return undef unless defined $string; # throws a warning otherwise
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    return $string;

} # end sub unmark

1;
__END__

=head1 NAME

Net::Peep::Data::XML - Utility for managing XML strings

=head1 SYNOPSIS

  use Net::Peep::Data::XML;
  my $vaccuum = new Net::Peep::Data::XML;
  $vaccuum->clean($xml);

=head1 DESCRIPTION

Peep utility for managing XML strings.

=head2 EXPORT

None by default.

=head1 METHODS

  clean($string) - Uses a regex to identify and remove any problems
  that would vex XML::Parser in parsing a string.  Returns a cleaned
  string.

  unmark($string) - Substitutes &lt; and &gt; for < and >, which would
  otherwise be erroneously perceived as XML markup.  Returns the
  modified string.

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu>

Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Data.

http://peep.sourceforge.net

=cut
