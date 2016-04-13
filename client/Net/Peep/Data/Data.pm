package Net::Peep::Data;

require 5.005;
use strict;
use Carp;
use Data::Dumper;
use XML::Parser;
use Net::Peep::Log;
use Net::Peep::Data::XML;
use Net::Peep::Data::Pool;
use Net::Peep::Data::Theme;
use Net::Peep::Data::Themes;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION 
	     %Name %Attributes %Handlers 
	     $LOGGER $XML $AUTOLOAD };

@ISA = qw(Exporter Net::Peep::Data::Pool);
%EXPORT_TAGS = ( );
@EXPORT_OK = ( );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.12 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

$LOGGER = new Net::Peep::Log;
$XML = new Net::Peep::Data::XML;

# Preloaded methods go here.

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;
	confess "Cannot instantiate object of type [$class]:  No name has been set."
	    unless $this->Name();
	confess "Cannot instantiate object of type [$class]:  No attributes or handlers have been set."
	    unless keys %{$this->Attributes()} or keys %{$this->Handlers()};
	$this->{'__ONEXIT__'} = undef;
	$this;

} # end sub new

sub AUTOLOAD {

	my $self = shift;
	my $class = ref($self) || confess "[$self] is not an object.";
	
	my $name;

	( $name = $AUTOLOAD ) =~ s/.*://;

	my %attributes = $self->Attributes();

	my %handlers = $self->Handlers();

	if (@_ >= 3) {

		my $what = shift;
		my $expat = shift;
		my $string = shift;
		
		if (exists $attributes{$name} and defined $string) {
			# we've encountered the start tag of element $name
			if ($what eq 'start') {
				# if an attribute is declared more than once,
				# we will convert the return value of the
				# attribute into an array
				if (exists($self->{$name}) and $self->{$name} and not ref($self->{$name})) {
					$LOGGER->log("Turning [$name] into an array.");
					$self->{$name} = [$self->{$name}];
				} 
			} elsif ($what eq 'char') {
				$LOGGER->debug(9,"\t\tAdding [$string] to element [$name] of class [".ref($self)."]");
				if (ref($self->{$name}) eq 'ARRAY') {
					$self->{$name}->[$#{$self->{$name}}] .= $string;
				} else {
					$self->{$name} .= $string;
				}
			} elsif ($what eq 'end') {
				# do nothing
			} else {
				$LOGGER->log("Something is not right:  What is [$what]?");
			}
			
		} else {
			# do nothing
		}
		
	} elsif (@_ == 1) {
		
		my $string = shift;
		
		if (exists $attributes{$name} and defined $string) {
			# we've encountered the start tag of element $name
			$LOGGER->debug(9,"\t\tAdding [$string] to [$name] of class [".ref($self)."]");
			$self->{$name} = $string;
		} else {
			# do nothing
		}
		
	} else {
		if (exists $attributes{$name}) {
			if (ref($self->{$name}) eq 'ARRAY') {
				return wantarray ? @{$self->{$name}} : $self->{$name};
			} else {
				return exists $self->{$name} ? $self->{$name} : undef;
			}
		} elsif (exists $handlers{$name}) {
			return $self->pool($name);
		} else {
			return undef;
		}
	}

} # end sub AUTOLOAD

sub deserialize {

	my $self = shift;
	my $xml = shift || confess "Cannot import XML string:  String not found.";
	$xml = $XML->clean($xml);

	my $parser = XML::Parser->new( Handlers => { Start => sub { $self->_start(@_) },
						     End   => sub { $self->_end(@_) } } );
	
	eval {
	    $parser->parse($xml);
	};

	if ($@) {
	    my $error = $@;
	    $LOGGER->log("Error parsing XML:  $error");
	    $LOGGER->log("The error must be fixed before proceeding.");
	    $LOGGER->log("Exiting ....");
	    confess "Goodbye cruel world ...";
	}

} # end sub deserialize

sub serialize {

	my $self = shift;
	my $level = shift || 0;

	my $class = ref($self) || confess "[$self] is not an object!";

	my $name = $self->Name();

	my $return = "  " x $level . "<$name>\n";

	for my $attribute (sort keys %{$self->Attributes($class)}) {
		if (defined($self->$attribute())) {
			$return .= "  " x $level . "  <" . $attribute .">";
			$return .= $self->Attributes($class)->{$attribute} eq 'CDATA' 
				? '<![CDATA[' . $self->$attribute() . ']]>'
				: $self->$attribute();
			$return .= "</" . $attribute .">\n";
		}
	}

	for my $pool ($self->pools()) {
		for my $object ($self->pool($pool)) {
			$return .= $object->serialize($level+1);
		}
	}

	$return .= "  " x $level . "</$name>\n";

	return $return;

} # end sub serialize

sub Name {

	confess "The Name() method must be overwritten by any class that inherits Net::Peep::Data";

} # end sub Name

sub Attributes {

	confess "The Attributes() method must be overwritten by any class that inherits Net::Peep::Data";

} # end sub Attributes

sub Handlers {

	confess "The Handlers() method must be overwritten by any class that inherits Net::Peep::Data";

} # end sub Handlers

sub _start {

	my $self = shift;
	my $expat = shift;
	my $element = shift;
	
	my $class = ref($self) || confess "[$self] is not an object.";
	
	$LOGGER->debug(9,"\tIn expat start handler the element is [$element] ...");
	
	my $name = $self->Name();
	my %attributes = $self->Attributes();
	my %handlers = $self->Handlers();
	
	if ($element eq $name) {
		if (@_) {
			my %attr = @_;
			for my $name (sort keys %attr) {
				if (exists $attributes{$name}) {
					my $value = $attr{$name};
					$LOGGER->debug(9,"\t\tAdding [$value] to attribute [$name] of class [".ref($self)."]");
					if (ref($self->{$name}) eq 'ARRAY') {
						$self->{$name}->[$#{$self->{$name}}] .= $value;
					} else {
						$self->{$name} .= $value;
					}
				}
			}
		}
	}

	if (exists $handlers{$element}) {
		my $object = $handlers{$element}->new;
		$object->onExit( sub { $self->_endObject($object,$element,@_) } );
		$expat->setHandlers( Start => sub { $object->_start(@_) },
				     End   => sub { $object->_end(@_) } );
		$object->_start($expat,$element,@_);
	} else {
		$self->$element('start',$expat,$element);
		$expat->setHandlers( 
				     Char => sub { $self->$element('char',@_) },
				     Proc => sub { $self->_proc('proc',@_) }
				     )
		    if defined($element) and $element ne $name;
	}
	
} # end sub _start

sub _end {

	my $self = shift;
	my $expat = shift;
	my $element = shift;
	
	my $class = ref($self) || confess "[$self] is not an object.";
	
	my $current = $expat->current_element();

	$LOGGER->debug(9,"\tIn expat end handler the element is [$element] (the current element is [$current]) ...")
	    if defined($element) and defined($current);

	my $name = $self->Name();
	
	$expat->setHandlers( Char => undef );
    
	if ($element eq $name and $self->onExit()) {
		$LOGGER->debug(9,"\t\tAdding [$name] object to pool of class [$class].");
		$self->onExit()->($expat,$element);
	}

} # end sub _end

sub _proc {

	my $self = shift;
	my $what = shift;
	my $expat = shift;

	my $name = shift;

	if ($name eq 'theme') {
		# We are being asked to import a theme
		my $file = shift;
		if ($file && -f $file) {
			open(F,$file) || confess "Error opening [$file]: $!";
			my $xml = join '', <F>;
			close F;
			my $themes = $self->themes();
			if (not defined $themes) {
				$themes = new Net::Peep::Data::Themes;
				$self->themes($themes);
			}
			my $theme = new Net::Peep::Data::Theme;
			$theme->parse($xml);
			$themes->theme($theme);
		} else {
			confess "Error:  Cannot find theme file [$file].";
		}
	}

} # end sub _proc

sub _endObject {

    my $self = shift;
    my $object = shift;
    my $name = shift;
    my $expat = shift;
    my $element = shift;

    my $current = $expat->current_element();

    $expat->setHandlers( Start => sub { $self->_start(@_) },
			 End   => sub { $self->_end(@_) } );

    $self->addToPool($name,$object);

} # end sub _endObject

sub onExit {

    my $self = shift;
    if (@_) { $self->{'__ONEXIT__'} = shift; }
    return $self->{'__ONEXIT__'};

} # end sub onExit

1;

__END__

=head1 NAME

Net::Peep::Data - Base class for Peep data objects.

=head1 SYNOPSIS

  package Net::Peep::Data::Subclass;
  use Net::Peep::Data;
  @ISA = qw(Net::Peep::Data);
  sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $this = $class->SUPER::new();
    bless $this, $class;
  } # end sub new
  sub Name { return 'general'; } # end sub Name
  sub Attributes {
  	my $self = shift;
  	my %attributes = ( version=>1,sound_path=>1 );
  	return wantarray ? %attributes : \%attributes;
  } # end sub Attributes

For more information, read on.

=head1 DESCRIPTION

The C<Net::Peep::Data> class provides both explicitly defined and
autoloaded methods used by Peep data classes.

Included are methods used both to serialize and deserialize XML
objects representing Peep data.

Subclasses of the C<Net::Peep::Data> class are used to describe Peep data
internally, including configuration, theme, and notification information.

=head2 SERIALIZING AND DESERIALIZING XML

The C<Net::Peep::Data> class is intended to be a superclass inherited by a
class or set of classes that represent a data structure that can be
represented with XML.

C<Net::Peep::Data> comes with two important public methods:   C<deserialize()>
and C<serialize()>.

The C<deserialize()> method takes an XML string as its sole argument and
returns an object structure representing the XML data.

=over 4

=item CREATING CLASSES TO REPRESENT XML DATA

The best way to explain is by example.  Let's generate a class that will
provide an object representation of the following XML:

  <user>
    <firstname>Collin</firstname>
    <lastname>Starkweather</lastname>
    <username>starky</username>
    <credit_card>
       <issuer>American Express</issuer>
       <number>xxxx xxxx xxxx xxxx</number>
    </credit_card>
    <credit_card>
       <issuer>Discover</issuer>
       <number>xxxx xxxx xxxx xxxx</number>
    </credit_card>
  </user>

Here we have a structure representing a user who has several credit cards.
The C<Net::Peep::Data> class represents each level of an XML heirarchy with a
separate class while attributes within a level are represented by methods with
corresponding names.   We are therefore going to generate two classes to
represent this data:  A user class and a credit card class.  The user class
will have three attributes:  C<firstname>, C<lastname>, and C<username>.  In
addition, each user may have several credit cards associated with it.  The
credit card class will have two attributes:  C<issuer> and C<number>.

Let's create the user class first.  The user class will define its attributes
(C<firstname>, C<lastname>, and C<username>) in an C<Attributes> method that
will override the C<Net::Peep::Data> C<Attributes> method.  In addition, for
the C<credit_card> class, we'll have a C<Handler> method to define the handler
for the C<credit_card> attribute.

  package User;
  use Net::Peep::Data;
  use CreditCard;
  @ISA = qw(Net::Peep::Data);
  sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $this = $class->SUPER::new();
    bless $this, $class;
  } # end sub new
  sub Name { return 'user'; } # end sub Name
  sub Attributes {
  	my $self = shift;
  	my %attributes = ( firstname=>1,lastname=>1,username=>1 );
  	return wantarray ? %attributes : \%attributes;
  } # end sub Attributes
  sub Handlers {
  	my $self = shift;
  	my %handlers = (credit_card => 'CreditCard');
  	return wantarray ? %handlers : \%handlers;
  } # end sub Handlers

Now we'll define the credit card class:

  package CreditCard;
  use Net::Peep::Data;
  @ISA = qw(Net::Peep::Data);
  sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $this = $class->SUPER::new();
    bless $this, $class;
  } # end sub new
  sub Name { return 'credit_card'; } # end sub Name
  sub Attributes {
  	my $self = shift;
  	my %attributes = ( issuer=>1,number=>1 );
  	return wantarray ? %attributes : \%attributes;
  } # end sub Attributes

That's all there is to it.  Now let's take a look at how to use these classes
to work with the XML data.

First, we'll instantiate a C<User> object.  Next, we'll "deserialize," or
parse and lex, the XML string $xml.  After parsing the XML string, we'll use
the C<User> and C<CreditCard> objects to access and modify the data.  Finally,
we'll write out the modified data by "serializing" it.

=item DESERIALIZING DATA

  my $xml = <<"eop";
  <user>
    <firstname>Collin</firstname>
    <lastname>Starkweather</lastname>
    <username>starky</username>
    <credit_card>
       <issuer>American Express</issuer>
       <number>xxxx xxxx xxxx xxxx</number>
    </credit_card>
    <credit_card>
       <issuer>Discover</issuer>
       <number>xxxx xxxx xxxx xxxx</number>
    </credit_card>
  </user>
  eop
  use User;
  # instantiate a user object
  my $user = new User;
  $user->deserialize($xml);

That's all there is to it.  The C<$user> object is now populated with
attributes and handlers that represent the XML data.

=item ACCESSING DATA

To access data, simply call a method with the same name as the attribute or
handler.

For example, to obtain the user name of the user whose data we just
deserialized, simply

  my $username = $user->username();

Note that whenever an attribute or handler is defined multiple times, the
corresponding method will return an array or reference to an array rather than
a simple scalar.

Thus, if the user had multiple user names

  <user>
    ...
    <username>starky</username>
    <username>cstarkweather</username>
    ...
  </user>

we would have had to obtain the user's user names with something like

  my @usernames = $user->username();

If you don't know whether your data will have multiple occurances of an
attribute, but you only want one, you can use the following idiom (which you
can find throughout the C<Net::Peep::Data::*> classes):

  my ($username) = $user->username();

With that in mind, we will obtain the user's credit card information with a
call to the C<credit_card()> method:

  my @credit_cards = $user->credit_card();

Each element of the C<@credit_cards> array is a C<CreditCard> object.  We can
get the issuer of each credit card by calling that object's C<issuer> method:

  for my $cc (@credit_cards) {
    print "Found issuer:  ", $cc->issuer(), "\n";
  }

This loop will print out 

    Found issuer:  American Express
    Found issuer:  Discover

=item MODIFYING DATA

To change the value of an attribute, simply calling the attribute method with
an argument will set the value of the attribute:

  $user->firstname("Joe");

Our user's first name is now Joe.  We could also add a credit card to Mr.
Starkweather's list of credit cards with the C<addToPool> method, which adds
an object to another object's object pool (I hope that makes sense!):

  my $cc = new CreditCard;
  $cc->issuer("Visa");
  $cc->number("xxxx xxxx xxxx xxxx");
  $user->addToPool('credit_card',$cc);

Now the loop

  for my $cc (@credit_cards) {
    print "Found issuer:  ", $cc->issuer(), "\n";
  }

will print 

    Found issuer:  American Express
    Found issuer:  Discover
    Found issuer:  Visa

=item SERIALIZING DATA

Now suppose you want to send the information regarding the user we have been
working with, including the modified first name and additional credit card, to
another application.  You will need to convert the data back into XML.  To do
so, simply call the C<serialize()> method:

  my $xml = $user->serialize();

=back

=head2 EXPORT

None by default.

=head2 METHODS

  new() - The constructor

  deserialize($xml) - Must be overridden in any subclass.  Will 
  parse the XML string $xml and return the object representation
  of the XML data structure.  See section L<SERIALIZING AND DESERIALIZING XML>
  for more information.

  serialize() - Must be overridden in any subclass.  Will translate
  any object drived from a subclass into its XML representation. 

  Attributes() - Must be overridden in any subclass with a method that
  defines a hash of attributes.

  Handlers() - Must be overridden in any subclass with a method that
  defines a hash of handlers.

  Name() - Must be overridden in any subclass with a method that
  defines the name of the XML element the class should parse.

See also C<Net::Peep::Data::Pool>, from which this class inherits.

=head1 AUTHOR

Collin Starkweather <collin.starkweather@colorado.edu>

Copyright (C) 2001

=head1 SEE ALSO

perl(1), peepd(1), Net::Peep::Conf, Net::Peep::Parser.

http://peep.sourceforge.net

=cut

