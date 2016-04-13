package Net::Peep::Peck;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility
use Carp;
use Getopt::Long;
use Socket;
use Net::Peep::Client;
use Net::Peep::BC;
use Net::Peep::Data::Notice;

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use constant PROT_MAJORVER => 1;
use constant PROT_MINORVER => 0;
use constant PROT_CLIENTEVENT => 4;
use constant PORT => '1999';

sub new {

	my $self = shift;
	my $class = ref($self) || $self;
	my $this = {};
	bless $this, $class;
	$this;

} # end sub new

sub peck {

	my $self = shift;

	my $client = new Net::Peep::Client;
	$client->name('peck');

	my ($type,$sound,$location,$volume,$priority,$dither,$autodiscovery)
		= (0,'',0,255,128,255,0);

	my %options = ( 
		'type=s' => \$type,
		'sound=s' => \$sound,
		'location=s' => \$location,
		'volume=s' => \$volume,
		'priority=s' => \$priority,
		'dither=s' => \$dither,
		'autodiscovery!' => \$autodiscovery, # override Net::Peep::Client's default
		);

	$client->initialize(%options) || $client->pods();

	$client->parser( sub { } );

	my $conf = $client->configure();

	if ($conf->getOption('autodiscovery')) {
		die "Error:  Autodiscovery is not supported by the peck client.";
	} else {
		unless ($conf->optionExists('server') && $conf->getOption('server') && 
		        $conf->optionExists('port') && $conf->getOption('port') &&
		        $conf->optionExists('config') && $conf->getOption('config') &&
		        $sound) {
			print "\nError:  You must provide config, sound, server and port options\n".
			      "  (e.g., --config=./peep.conf --sound=rooster --server=localhost --port=2001).\n\n";
			exit(0);
		}
	}
	my $broadcast = new Net::Peep::BC ($conf);

	my $notice = new Net::Peep::Data::Notice;
	$notice->type(0);
	$notice->sound($sound);
	$notice->location($location);
	$notice->priority($priority);
	$notice->volume($volume);
	$notice->date(time());
	$notice->data('Peck:  Playing [$sound]');
	$broadcast->send($notice);

	return 1;

} # end sub peck

# returns a logging object
sub logger {

	my $self = shift;
	if ( ! exists $self->{'__LOGGER'} ) { $self->{'__LOGGER'} = new Net::Peep::Log }
	return $self->{'__LOGGER'};

} # end sub logger

sub pecker {

    # tee hee
    my $self = shift;
    $self->{"__PECKER"} = Net::Peep::BC->new() unless exists $self->{"__PECKER"};
    return $self->{"__PECKER"};

} # end sub pecker

1;

__END__

=head1 NAME

Net::Peep::Peck - Perl extension for generating ad-hoc sounds using the
Peep sound engine.

=head1 SYNOPSIS

  use Net::Peep::Peck;
  my $peck = new Net::Peep::Peck;

=head1 DESCRIPTION

Net::Peep::Peck provides utility methods for the peck utility, which
allows users to generate ad-hoc sounds.

=head1 EXPORT

None by default.

=head1 METHODS

  new() - The constructor

  peck() - Sends an event to the server and port specified by the
  command-line flags (you guessed it!) --server and --port.  For other
  related command-line flags, see the COMMAND-LINE ARGUMENTS section.

=head1 COMMAND-LINE ARGUMENTS

Command-line arguments processed by Net::Peep::Peck include:

    --type      The type of sound to produce (event=0, state=1)
    --sound     The name or number of the sound to produce
    --location  The location (left or right speaker) of the sound
    --volume    The volume of the sound
    --priority  A priority for producing the sound
    --dither    The dither
    --port      The port to which the event will be directed
    --server    The server to which the event will be directed
    --debug     The debugging level (Def:  0)
    --logfile   The file to send log output (Def:  STDOUT)
    --help      Prints whatever PODs are found in the calling 
                application

=head1 EXAMPLES

  peck --server=localhost --port=2001 --sound=auth-fail

  peck --server=localhost --port=2001 --type=0 --sound=1

  peck --server=localhost --port=2001 --sound=0 --debug=9

=head1 ALTERNATIVES

To play individual sounds (for example, if you are browsing through
the C<sounds> directory), C<bplay> makes for a nice sound browser.

Last I checked, you can find C<bplay> at 

  http://www.amberdata.demon.co.uk/bplay

The following arguments tend to work well for me:

  bplay -S -s 44100 -b 16 soundfile

where soundfile is whatever sound you want to listen to
(C<hermit-thrush-01.01> is one of my personal favorites).

Note that you should not have the Peep daemon running when you use
C<bplay> and vice-versa.

=head1 AUTHOR

Michael Gilfix <mgilfix@eecs.tufts.edu> Copyright (C) 2001

=head1 SEE ALSO

perl(1), Net::Peep::BC, peck.

=head1 CHANGE LOG

$Log: Peck.pm,v $
Revision 1.2  2002/10/16 04:00:34  starky
Test 200.t and the peck client are now working.

Revision 1.1  2001/10/18 06:01:34  starky
Initial commit of client libraries for version 0.5.0.

Revision 1.4  2001/09/23 08:53:57  starky
The initial checkin of the 0.4.4 release candidate 1 clients.  The release
includes (but is not limited to):
o A new client:  pinger
o A greatly expanded sysmonitor client
o An API for creating custom clients
o Extensive documentation on creating custom clients
o Improved configuration file format
o E-mail notifications
Contact Collin at collin.starkweather@colorado with any questions.

Revision 1.3  2001/08/08 20:17:57  starky
Check in of code for the 0.4.3 client release.  Includes modifications
to allow for backwards-compatibility to Perl 5.00503 and a critical
bug fix to the 0.4.2 version of Net::Peep::Conf.

Revision 1.2  2001/05/06 21:33:17  starky
Bug 421248:  The --help flag should now work as expected.

Revision 1.1  2001/04/23 10:13:20  starky
Commit in preparation for release 0.4.1.

o Altered package namespace of Peep clients to Net::Peep
  at the suggestion of a CPAN administrator.
o Changed Peep::Client::Log to Net::Peep::Client::Logparser
  and Peep::Client::System to Net::Peep::Client::Sysmonitor
  for clarity.
o Made adjustments to documentation.
o Fixed miscellaneous bugs.

Revision 1.8  2001/04/17 06:46:21  starky
Hopefully the last commit before submission of the Peep client library
to the CPAN.  Among the changes:

o The clients have been modified somewhat to more elagantly
  clean up pidfiles in response to sigint and sigterm signals.
o Minor changes have been made to the documentation.
o The Peep::Client module searches through a host of directories in
  order to find peep.conf if it is not immediately found in /etc or
  provided on the command line.
o The make test script conf.t was modified to provide output during
  the testing process.
o Changes files and test.pl files were added to prevent specious
  complaints during the make process.

Revision 1.7  2001/04/07 08:23:35  starky
Added documentation describing how to listen to individual sounds with
bplay for those who may find that interesting.

Revision 1.6  2001/04/04 05:40:00  starky
Made a more intelligent option parser, allowing a user to more easily
override the default options.  Also moved all error messages that arise
from client options (e.g., using noautodiscovery without specifying
a port and server) from the parseopts method to being the responsibility
of each individual client.

Also made some minor and transparent changes, such as returning a true
value on success for many of the methods which have no explicit return
value.

Revision 1.5  2001/03/31 07:51:35  mgilfix


  Last major commit before the 0.4.0 release. All of the newly rewritten
clients and libraries are now working and are nicely formatted. The server
installation has been changed a bit so now peep.conf is generated from
the template file during a configure - which brings us closer to having
a work-out-of-the-box system.

Revision 1.1  2001/03/31 02:17:00  mgilfix
Made the final adjustments to for the 0.4.0 release so everything
now works. Lots of changes here: autodiscovery works in every
situation now (client up, server starts & vice-versa), clients
now shutdown elegantly with a SIGTERM or SIGINT and remove their
pidfiles upon exit, broadcast and server definitions in the class
definitions is now parsed correctly, the client libraries now
parse the events so they can translate from names to internal
numbers. There's probably some other changes in there but many
were made :) Also reformatted all of the code, so it uses
consistent indentation.

=cut
