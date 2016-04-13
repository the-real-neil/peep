package Net::Peep::Data::Pool;

require 5.005;
use strict;
use Carp;
use Data::Dumper;
use XML::Parser;
use Net::Peep::Log;
use Net::Peep::Data::XML;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION $LOGGER $XML };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( );
@EXPORT_OK = ( );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = new Net::Peep::Log;
$XML = new Net::Peep::Data::XML;

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;
	$this->{'__POOL__'} = {};
	$this;

} # end sub new

sub deserialize {

    my $self = shift;

    my $xml = shift || confess "Cannot deserialize pool:  No XML found.";
    my $package = shift || confess "Cannot deserialize pool:  No package found.";
    my $name = shift || confess "Cannot deserialize pool:  No name found.";

    $xml = $XML->clean($xml);

    my $parser = XML::Parser->new( Handlers => { Start => sub { $self->_start($package,$name,@_) },
						 End   => sub { $self->_end(@_) } } );

    $parser->parse($xml);

} # end sub deserialize

sub _start {

    my $self = shift;
    my $package = shift;
    my $name = shift;
    my $expat = shift;
    my $element = shift;
    
    $LOGGER->debug(9,"In expat start handler element is [$element] ...") if defined $element;

    if (defined($element) and $element eq $name) {

	my $object = $package->new;

	$object->onExit( sub { $self->_endObject($object,$package,$name,@_) } );

	$expat->setHandlers( Start => sub { $object->_start(@_) },
			     End   => sub { $object->_end(@_) } );

	$object->_start($expat,$element);

    } 

} # end sub _start

sub _end {

    my $self = shift;
    my $expat = shift;
    my $element = shift;

    $LOGGER->debug(9,"In expat end handler with element [$element] ...");

    $expat->setHandlers( Start => sub { $self->_start(@_) } );

} # end sub _end

sub _endObject {

    my $self = shift;
    my $object = shift;
    my $package = shift;
    my $name = shift;
    my $expat = shift;
    my $element = shift;

    my $current = $expat->current_element();

    $expat->setHandlers( Start => sub { $self->_start($package,$name,@_) },
			 End   => sub { $self->_end(@_) } );

    $self->addToPool($object);

} # end sub _endObject

sub addToPool {

    my $self = shift;
    my $name = shift || confess "Cannot add object to pool:  Name not found";
    my $object = shift || confess "Cannot add object to pool:  Object not found";

    push @{$self->{'__POOL__'}->{$name}}, $object;

} # end sub addToPool

sub pool {

    my $self = shift;
    my $name = shift || confess "Cannot retrieve object pool:  Name not found";

    if (exists $self->{'__POOL__'}->{$name}) {
	return wantarray ? @{$self->{'__POOL__'}->{$name}} : $self->{'__POOL__'}->{$name};
    } else {
	return wantarray ? () : [];
    }

} # end sub pool

sub pools {

	# returns the name of any pools the object possesses

	my $self = shift;
	my @pools = sort keys %{ $self->{'__POOL__'} };
	return wantarray ? @pools : \@pools;

} # end sub pools

1;

__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

Net::Peep::Data::Pool - Perl extension to provide a strong aggregate
of Peep data classes.

=head1 SYNOPSIS

  use Net::Peep::Data::Pool;

=head1 DESCRIPTION

This class is subclassed by the C<Net::Peep::Data> and provides any subclass of
it a strong aggregate of Peep data classes.

See the C<Net::Peep::Data> class for detailed information regarding Peep data
classes.

=head2 EXPORT

None by default.

=head1 AUTHOR

Collin Starkweather Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Data

http://peep.sourceforge.net

=cut
