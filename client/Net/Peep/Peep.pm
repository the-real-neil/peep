package Net::Peep;

require 5.00503;
use strict;
# use warnings; # commented out for 5.005 compatibility

require Exporter;

use vars qw{ @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION };

@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw( ) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );
$VERSION = '0.5.0-rc2';

# This module serves no useful purpose at this time other than as a
# placeholder for documentation

1;

__END__

=head1 NAME

Net::Peep - Perl extension for Peep:  The Network Auralizer.

=head1 DESCRIPTION

Peep is an open source free software network monitoring tool issued
under the Gnu General Public License that presents information via
audio output.  Network diagnosis with Peep is made not only based on
single network events, but the network as a whole "sounds normal."

Although Peep has found much use as a monitoring tool, the tool has
been designed to allow customized clients to be created for virtually
any purpose.  It could be used, for example, to create a stock ticker
or to parse input from a web cam with ImageMagick and create aural
output based on the nature of the image.

Please refer to the section on creating a custom client below
for more information.

=head1 SYNOPSIS

This document serves as an introduction to the Peep clients and the
Peep client architecture.

=head1 REQUIRES

The following modules are required for all clients:

  Time::HiRes
  XML::Parser
  File::MMagic

The following modules are required for select clients:

  logparser:   File::Tail
  pinger:      Net::Ping::External
  sysmonitor:  Filesys::DiskFree, Proc::ProcessTable

=head1 INTRODUCTION

Peep is built on a client-server model in which the clients generate
"events" based on user-defined criteria (e.g., whether a packet denial
has been logged or a broken link on a web site was found).  One or
several Peep servers are then notified of the events by clients, at
which time an audio signal is generated.

The clients, which include such applications as C<logparser> and
C<sysmonitor> and for which this document constitutes introductory
documentation, are written in Perl, IMHO about the coolest language
ever.  The bulk of the client code is composed of a set of Perl
modules comprising objects and base classes for use by Peep clients
and their derivatives.

The server, C<peepd>, is written in C.

Both the client and server are available for download free of charge
from the Peep homepage located at

  http://peep.sourceforge.net

The Peep client modules and executables are also available on the CPAN
(Comprehensive Perl Archive Network) for installation via the
time-honored

  perl -MCPAN -e "install Net::Peep"

In fact, this is the preferred method of installation of the Peep
clients.

Consult the core Peep documentation for more information on
installation and usage of Peep.

=head2 PEEP CLIENTS

The Peep client library comes bundled with a number of ready-to-use clients.  These include

  logparser            Generates events based on matching regular
                       expressions to tailed logs (e.g., 
                       /var/log/messages).

  sysmonitor           Generates events based on system events (e.g.,
                       load average exceeding 2.0).

  pinger               Generates events based on whether a host
                       is responsive.

  peck                 Generates ad hoc Peep events.  Primarily for 
                       testing purposes.

  keytest              Generates ad hoc Peep events.  Primarily for 
                       fun.

Other user-contributed clients can be found on the Peep homepage at 

  http://www.auralizer.com

Although several useful clients have been provided with the distribution, the
true power of Peep comes in the ability for users to quickly and easily create
their own customized clients with a simple API and the whole of the CPAN at
thier disposal.  Please read on for more information.

=head2 SUPPLEMENTAL INTRODUCTORY INFORMATION FOR DEVELOPERS

Peep clients are built on a class heirarchy composed of a set of core classes,
helper classes, and a large set of data classes.

While the number of classes may seem overwhelming at first, as you will see
later you don't need to know much to implement a Peep client.  However, if you
are interested in the internals, the client class library is well-documented
and, we hope, organized in an intuitive fashion.

The Peep client library is composed of the following core modules:

  Perl Modules
  ------------

  Net::Peep            A non-functional module.  Simply holds 
                       POD documentation for Peep; in fact, 
                       it holds the documentation that you are
                       reading right now!

  Net::Peep::BC        The Peep broadcast module.  Used to notify Peep  
                       servers that an event has been generated.

  Net::Peep::Client    Base and utility class for Peep clients and 
                       client modules.

  Net::Peep::Conf      The Peep configuration object.  An  
                       object representation of peep.conf.

  Net::Peep::Log       Provides utility methods for logging, debugging,
                       and benchmarking.

  Net::Peep::Notifier  A class Peep uses to send out e-mail 
                       notifications.

  Net::Peep::Parser    The Peep configuration file parser.  Reads  
                       peep.conf and populates Peep::Conf 
                       appropriately.

  Net::Peep::Data      Superclass for Peep data objects representing
                       configuration, theme, and notification 
                       information internally.   See below for a 
                       complete list of the Peep data objects.

Peep data, including configuration, theme, and notification information, is
represented internally by a set of data classes:

  Peep Data Classes
  -----------------

  Net::Peep::Data::XML
  Net::Peep::Data::Client
  Net::Peep::Data::Clients
  Net::Peep::Data::Client::Notification
  Net::Peep::Data::Conf
  Net::Peep::Data::Conf::Class
  Net::Peep::Data::Conf::Class::Server
  Net::Peep::Data::Conf::Class::Servers
  Net::Peep::Data::Conf::General
  Net::Peep::Data::Conf::Classes
  Net::Peep::Data::Event
  Net::Peep::Data::Events
  Net::Peep::Data::Host
  Net::Peep::Data::Notice
  Net::Peep::Data::Option
  Net::Peep::Data::Options
  Net::Peep::Data::Pool
  Net::Peep::Data::Sound
  Net::Peep::Data::Sounds
  Net::Peep::Data::State
  Net::Peep::Data::State::ThreshHold
  Net::Peep::Data::State::ThreshHolds
  Net::Peep::Data::States
  Net::Peep::Data::Theme
  Net::Peep::Data::Themes

There are a variety of helper classes other than those mentioned above
that server a variety of useful functions.  Consult the individual
PODs for more information.

Please refer to the individual modules of the Peep distribution (e.g.,
Net::Peep::BC) or the Peep client executables (e.g., logparser) for
further documentation.

=head1 CREATING A CUSTOM PEEP CLIENT

One of the most powerful features of Peep is the ability to create
customized clients to use Peep for whatever you like.  Although Peep
is used widely as a systems and network monitor because it is well
suited to the task, you could do anything from creating a stock
monitoring client to creating a client that will take output from a
web cam, parse it with ImageMagick (see http://www.imagemagick.org and
http://www.imagemagick.org/www/perl.html) and generate real-time sound
effects based on what you see.

With the whole of the CPAN at your disposal, the sky is the limit.

The Net::Peep::Client module and other helper classes make
constructing a custom Peep client a breeze.

It is quite formulaic, and once you have done it once, you will
already feel like it is old hat.  In describing the process, we will
create the first example mentioned above: A client to monitor stock
prices.  All told, the code is only 50 lines (only 33 statements!) and
took me about a half hour to write.

The client will wake up every 60 seconds, get some stock quotes over
the web, and depending on whether the stock is above or below a
certain price, will alert you with both a peep and an e-mail
notification.

Bear in mind that you really do not need to know much Perl to create a
client.  If you are a newbie, just copy what is done here while using
your favorite Perl book to figure out whatever you do not understand.

The full code listing is given at the end of this section for
reference.

=head2 SOME PRELIMINARIES

The C<ticker> requires a Perl module by the name of C<Finance::Quote>.

I will assume that the reader is familiar with how to install a Perl
module.  For those who are unfamiliar with the process of installing a
Perl module from the CPAN, a hint:

  sudo perl -MCPAN -e 'install Finance::Quote'

=head2 THE CLIENT CONFIGURATION

First, create a section in the Peep configuration file, C<peep.conf>,
for your client.  (C<peep.conf> would typically be put in your
C</usr/local/etc> directory during install.)  C<peep.conf> is heavily
commented, so you should use that as a reference as well as this
document.

The section begins with a C<client> declaration and ends with an C<end
client> declaration.

There is some window dressing you have to add, including a C<class>
and C<port> declaration.  You can just copy those from one of the
other clients.

You can also put an optional C<default> section, which specifies any
defaults for command-line options.  See the C<logparser> section of
C<peep.conf> for an example.

Next (and this is where you are doing the real work), you create the
C<config> section.

Between the C<config> and C<end config>, you can put anything you
want.  You will see what this section is all about in a bit, but for
now let us just create a section that lists some stock symbols and
related information we will need for the client.

If you want to receive e-mail notifications, you can include an
optional C<notification> section following the C<config> section as
well which will describe who is to be sent the e-mail and some other
information.

The whole thing looks like this:

  client ticker
    class morgenstern
    port 1999
    config
      # Stock symbol  Stock exchange    Event             Max      Min  
      RHAT            nasdaq            red-hat           4.0      3.6
      SUNW            nasdaq            sun-microsystems  9.0      8.0
    end config
    notification
      notification-hosts morgenstern
      notification-recipients collin.starkweather@colorado.edu
      notification-level warn
    end notification
  end client ticker

Finally, you should define the events you just created.  An event
named C<red-hat> is associated with the stock symbol for Red Hat (no
endorsement implied) and one named C<sun-microsystems> is associated
with, you guessed it, Sun Microsystems (again, no endorsement
implied).

So let us tie these events into some sounds.  Going down to the
C<events> block in the configuration file, put in the following:

  sound
    name doorbell
    category misc
    type event
    format raw
    path misc/events/doorbell
  end sound

  sound
    name rooster
    category misc
    type event
    format raw
    path misc/events/doorbell
  end sound

  event
    name red-hat
    sound rooster
  end event
  
  event
    name sun-microsystems
    sound doorbell
  end event

This will cause a rooster to crow when C<RHAT> goes out of bounds and
a doorbell to chime when the same happens with C<SUNW>.

=head2 THE CODE

Creating the client itself is really quite easy.  There is going to be
alot of discussion in this section, and the code is quite liberally
commented.  However there are actually only 50 lines (and only 33
statements - some statements span lines for clarity) of code to create
the entire client.  So you should not feel intimidated.  There is
really not much to it.

I assume that the reader has some working knowledge of Perl.  If you
are just starting out, I would recommend that you look up

  http://www.perlmonks.org

to supplement any other learning you are doing.  It is a very helpful
forum and a real boon to those just starting out.

=over 4

=item OPEN A FILE

Open a file called C<ticker> in your text editor of choice.

=item USE SOME MODULES

The first thing we will create is the C<use> section.  This will read
in all of the objects we need.  I will also use the C<strict> pragma.
Using C<strict> is a habit I highly recommend:

  #!/usr/bin/perl
  use strict;
  use Net::Peep::BC;
  use Net::Peep::Log;
  use Net::Peep::Client;
  use Net::Peep::Data::Notice;
  use Net::Peep::Notifier;
  use Net::Peep::Notification;
  use Finance::Quote;
  use vars qw{ %config $logger $client $quoter $conf };

After using C<strict>, several Peep modules are used.  The
C<Net::Peep::BC> module is used to send a broadcast to the server to
let it know it is supposed to play a sound.  C<Net::Peep::Log> is a
helpful module if you need to create some well-formatted output.  (We
will use it in a couple of places to let ourselves know what we are
doing.)  

The C<Net::Peep::Client> module is the real workhorse.  That is what
will enable us to write a client in 33 statements or less.  The
C<Net::Peep::Notifier> and C<Net::Peep::Notification> modules are used
to send e-mail notifications.  (I want to know it if my stocks take a
nosedive and I am out of my office!)

Next is the C<Finance::Quote> module, which we will use to fetch the
stock prices.

Finally we declare some global variables with the C<vars> pragma.  You
will see what these are used for later.

=item INSTANTIATE SOME OBJECTS

We will be using three objects in the main section of the script: A
logging object, a Peep client object, and the object that gets our
stock quotes for us.

  $logger = new Net::Peep::Log;
  $client = new Net::Peep::Client;
  $quoter = new Finance::Quote;

=item WORKING WITH THE CLIENT OBJECT

Now we will work some magic with the client object.

The first thing we do is give the client a name.  We will call our
client 'ticker'.

  $client->name('ticker');

Now we need to initialize the client.  

  $client->initialize();

There are a variety of command-line options that will be read and
parsed during the initialization.  If you would like to supply some of
your own command-line options to the initialization, you can do so
using the format of the C<Getopt::Long> object with something like:

  my $foo = '';
  my %options = ( 'foo=s'=>\$foo, ... );
  $client->initialize(%options);

Next we will tell the client what it will use to parse the C<config>
block we defined above.  We will simply pass it a reference to a
subroutine which we will define later.  How about we call the
subroutine C<parse>?

  $client->parser( \&parse );

Now that we have told the client what to use to parse the C<config>
block, we can tell it to read in the configuration information from
the Peep configuration file:

  my $conf = $client->configure();

The return value of the configure method, C<$conf>, is a
C<Net::Peep::Conf> object containing the information gleaned from the
Peep configuration file and a variety of useful methods.  See the
C<Net::Peep::Conf> PODs for more information.

After the configuration information is read, we will start the client
on its way.  The first thing we do is tell the client what to do every
time it wakes up.  We will feed it a callback (another reference to a
subroutine, this one called C<loop>) which will be run every time the
client wakes up.  Then we will start the client up, telling it to wake
up every 60 seconds and execute the callback.

  $client->callback( \&loop );
  $client->MainLoop(60);

That is all there is to it!  Well, almost.  We mentioned two
subroutines above which we have not yet defined.  So the last thing we
will do is write these subroutines.

=item THE PARSER

The parser is given everything between the C<config> and C<end config>
lines in the section of the configuration file we defined above.

Though you can parse it any way you like, I favor using a regular
expression.  They seem to intimidate people because they look so
cryptic, but they were much easier for me to get the hang of than I
expected.

  # This subroutine will be used to parse the following 2 lines from
  # peep.conf (see above) and store the information in %config:
  #   RHAT            nasdaq            red-hat           4.0      3.6
  #   SUNW            nasdaq            sun-microsystems  9.0      8.0
  sub parse {
    for my $line (@_) {
      if ($line =~ /^\s*([A-Z]+)\s+(\w+)\s+([\w\-]+)\s+([\d\.]+)\s+([\d\.]+)/) {
        my ($symbol,$exchange,$event,$max,$min) = ($1,$2,$3,$4,$5,$6);
          $config{$symbol} = { event=>$event, exchange=>$exchange, max=>$max, min=>$min };
       }
    }
  } # end sub parse

We basically create a data structure from the C<%config> hash.  The
keys of the hash are the stock symbols and the values are hash
references used to describe some information about the stock symbol
such as what stock exchange to look at, what event (sound) to play,
and what the maximum and minimum prices that will trigger the event
are.

The information that we get from the configuration file will be used
in the next section to trigger the event and the e-mail notification.

=item THE CALLBACK

Finally, the meat of the client: The callback.  I will leave it as an
exercise to the reader to browse the documentation for
C<Finance::Quote>.

First the code, then the explanation:

  sub loop {
    for my $key (sort keys %config) {
      $logger->log("Checking the price of [$key] ...");
      # Fetch some information about the stock including the price
      my %results = $quoter->fetch($config{$key}->{'exchange'},$key);
      my $price = $results{$key,'price'};
      $logger->log("\tThe price of [$key] is [$price].");
      if ($price > $config{$key}->{'max'} or $price < $config{$key}->{'min'}) {
        $logger->log("\tThe price is out of bounds!  Sending notification ....");
        # The price is out of bounds!  We'll start peeping ...
        my $broadcast = Net::Peep::BC->new($conf);
        my $notice = new Net::Peep::Data::Notice;
	$notice->host(hostname());
	$notice->client('ticker');
	$notice->type(0);
	$notice->sound($config{$key}->{'event'});
	$notice->location(128);
	$notice->priority(0);
	$notice->volume(255);
	$notice->date(time);
	$notice->data("The price of $key is $price!");
	$notice->metric($price);
	$notice->level('crit');
        $broadcast->send($notice);
        my $notifier = new Net::Peep::Notifier;
        my $notification = new Net::Peep::Notification;
        $notification->client('ticker');
        $notification->status('crit');
        $notification->datetime(time());
        $notification->message("The price of $key is $price!");
        $notifier->notify($notification);
      }
    }
  } # end sub loop

If that all made perfect sense, great!  If not, we'll break the callback down
line-by-line:

In the callback, we loop over the stock symbols we found in the
C<parse> subroutine described above with

  for my $key (sort keys %config) {
    ...
  }

For each stock symbol, we fetch the price and other information using 

  my %results = $quoter->fetch($config{$key}->{'exchange'},$key);

Next, we check if the price is greater than the maximum or less than
the minimum defined in the configuration file:

  if ($price > $config{$key}->{'max'} or $price < $config{$key}->{'min'}) {
        ...
  }

If it is, we first send a message to the Peep server to play a sound.  

Messages are generated by populating the attributes of a
C<Net::Peep::Data::Notice> object.  The message is sent by instantiating a
C<Net::Peep::BC>, the Peep broadcast object, and calling its C<send> method
with a C<Net::Peep::Data::Notice> object as its argument.

  my $broadcast = Net::Peep::BC->new($conf);
  my $notice = new Net::Peep::Data::Notice;
  $notice->host(hostname());
  $notice->client('ticker');
  $notice->type(0);
  $notice->sound($config{$key}->{'event'});
  $notice->location(128);
  $notice->priority(0);
  $notice->volume(255);
  $notice->date(time);
  $notice->data("The price of $key is $price!");
  $notice->metric($price);
  $notice->level('crit');
  $broadcast->send($notice);

The C<type> option indicates the type of sound (0 for an event, 1 for
a state).  The sound option tells it what type of sound it should play
(in this case either C<red-hat> or C<sun-microsystems>).  The
remainder of the settings are described in the C<Net::Peep::BC>
documentation.

Second, we send out an e-mail notification.  This is done by creating
a C<Net::Peep::Notifier> object, which will actually send the e-mail,
and giving it a C<Net::Peep::Notification> object properly populated
with information that will be included in the e-mail:

  my $notifier = new Net::Peep::Notifier;
  my $notification = new Net::Peep::Notification;
  $notification->client('ticker');
  $notification->status('crit');
  $notification->datetime(time());
  $notification->message("The price of $key is $price!");
  $notifier->notify($notification);

For more information, consult the documentation for these objects.

It is worth noting that this does not imply that we will receive an
e-mail every 60 seconds.  The notification system sends out a
notification when it first receives one, then sends all subsequent
notifications in a bundle at regular intervals (you can set the
bundling interval in C<peep.conf>) .

We have created a Peep client from scratch!  Let us see how it works
....

=back

=head2 RUN THE CLIENT

Simply as an example, I would start the server with

  ./peepd -S /usr/local/etc/peep.conf --nodaemon

I use the C<--nodeamon> flag so that I can watch the output.

Then 

  ./ticker --noautodiscovery --server=localhost --port=2001 \ 
           --nodaemon --config=/usr/local/etc/peep.conf

=head2 DROP US A LINE

We would be interested in any clients that are created, both out of
curiosity and because the code may be useful to others.  Our e-mail
addresses are given below.

=head1 THEMES

With the advent of the 0.5.x series, you may define themes in Peep.  A theme is
a mini-configuration file that defines of sounds, events, states, and clients.

The idea behind themes is that you can build a theme for a client based on
sounds, states, and events that you find pleasant, then send the theme to a
friend.  

You friend can then simply call a client with a C<--theme> flag to point it at
the right theme and they will hear the same states and events that you do.

Themes have been written to provide both a general audio experience based on
events and states or for specific tasks such as identifying a Nimbda or Code
Red exploit.

While Peep configuration files can be defined either as text or XML documents,
themes can only be defined as XML.  If you've never used XML before, don't
worry.  It has become so popular in part because it is so easy.  And since will
only become more pervasive, there is no better time to learn it than now.

In the following sections, we'll go step-by-step through the process of
creating a theme that will be used by the C<logparser> client.  I like to know
when someone tries to log in as root and, more importantly, when someone
unsuccessfully tries to log in as root.

=head2 CREATING A THEME FILE

Let's create a theme file called C<collin.xml> that defines a particular theme
for the C<logparser> client that I like.

=over 4

=item GETTING STARTED

To create a theme file, you need to create an XML document to define a set of
sounds, events, states, and a client configuration.  To start, put the
following string at the top of the document:

  <?xml version='1.0' encoding='UTF-8' standalone='no'?>

This is just a formality that identifies the document as an XML document.  Just
put it at the top of every theme file as your standard operating procedure.

Next you need to start defining the theme and give it a name.  My name is
Collin, so I'll call my theme "collin":

  <theme name="collin">

I mentioned earlier that we need to define a set of sounds, events, states, and
a client configuration.

=item DEFINING THE SOUNDS

Let's start with the sounds:

  <sounds>
    <sound>
      <name>light-chirps-04</name>
      <category>wetlands</category>
      <type>events</type>
      <format>raw</format>
      <description></description>
      <path>wetlands/events/light-chirps</path>
    </sound>
    <sound>
      <name>rooster</name>
      <category>misc</category>
      <type>events</type>
      <format>raw</format>
      <description>A rooster crow</description>
      <path>misc/events/rooster</path>
    </sound>
  </sounds>

The "sounds" tags indicate that there are going to be a bunch of sounds
defined.  Each sound between the "sounds" tags is indicated by a (you guessed
it!) "sound" tag.  Within each sound tag there are tags which describe the
name, category, type, format, description, and path of the sound.  For now, the
name and path are the only required sound attributes. 

We'll describe two sounds:  Light chirps, which will be used for a successful
root login, and a rooster crow, which will be used for an unsuccessful root
login.

=item DEFINING THE EVENTS

Now that we've described all the sounds we want to use, we'll describe the
events that will be used by the client.

As mentioned earlier, we will be defining one event for an unsuccessful root
login and another for a successful root login:

  <events>
    <event>
      <name>su-login</name>
      <sound>light-chirps-04</sound>
      <description>If someone logs in as root, this event will be triggered</description>
    </event>
    <event>
      <name>bad-su-login</name>
      <sound>rooster</sound>
      <description>If someone unsuccessfully tries to log in as root, this event will be triggered</description>
    </event>
  </events>

Each event must have a name and be associated with a sound.  The description is
optional, but if you are distributing a theme, it is helpful to clue folks into
what your theme is all about.

=item DEFINING STATES

Although the theme in this example uses the C<logparser> client, which only
supports events, if you were to define a theme for another client (such as
C<sysmonitor>) which supports states, you would define some states at this
point:

  <states>
    <state>
      <name>loadavg</name>
      <description>
      The sound of running water gets progressively stronger
      as the 5 minute load average increases
      </description>
      <threshold>
        <level>0.5</level>
        <fade>0.5</fade>
        <sound>water-01</sound>
      </threshold>
      <threshold>
        <level>1.0</level>
        <fade>0.25</fade>
        <sound>water-02</sound>
      </threshold>
    </state>
  </states>

Besides a name and a description, a state is composed of a variety of
threshholds.  As each threshhold level is crossed, the sound is changed.  In
the case of the above example, as the load average increases, the sound of
running water turns into the sound of rushing water.

=item DEFINING A CLIENT

Finally we come to defining the client.  The client must have a name.  It can
also have some options defined.  In this case, the client port is defined as
1999 and the logfile option is defined to parse C</var/log/messages>.  The
configuration section is identical to the format in the plain-text client
declarations, though in this case we surround the configuration block in 

  <![CDATA[...]]>

The C<CDATA> block tells the XML parser to treat that block of text as a
verbatim string.  Since <, >, and & have a special meaning in XML, if they are
used in an XML text block they will cause the parser to barf.  (They can be
included with the special "entities" C<&lt;>, C<&gt;>, and C<&amp;> as in
HTML.)  The C<logparser> client uses regular expressions as part of its
configuration, in which <, >, and & are not uncommon characters.

Here is the full client declaration:

  <clients>
    <client name="logparser">
      <options>
        <option>
          <name>port</name>
          <value>1999</value>
        </option>
        <option>
          <name>logfile</name>
          <value>/var/log/messages</value>
        </option>
        <option>
          <name>groups</name>
          <value>default</value>
        </option>
      </options>
      <configuration><![CDATA[
        # All patterns matched are done using Perl/awk matching syntax
        #  Commented lines are ones that BEGIN with a '#'
        #  Reference letters are used for the default section as well as
        #  the command line options -events and -logfile.

        events
            # Name       Group     Location     Priority   Notification   Pattern                                 Hosts
            su-login     default   128         255         warn          "\(pam_unix\)\[\d+\]: .* opened .* root" localhost
            # note that if the previous regex matches, the following will be ignored
            bad-su-login default   128         255         warn          "\(pam_unix\)\[\d+\]: .* closed .* root" localhost
        end events
        ]]>
        </configuration>
    </client>
  </clients>

=item FINISHING UP

Finally, conclude the theme section with

  </theme>

That's all there is to it!  You can now send your theme to friends or coworkers
who want to know how to monitor root logins.

The complete text of the theme file is given in appendix C.

=back

=head2 USING A THEME FILE

After you have sent your theme file to your friend, they can include it in their Peep configuration file (e.g., C<peep.conf>) with something like

  theme themes/collin.xml

Now your friend can use the theme by calling the C<logparser> client from the
command line with the C<--theme> option:

  ./logparser --theme=collin.xml ...

That's all there is to it!

=head1 AUTHOR

Michael Gilfix <mgilfix@eecs.tufts.edu> Copyright (C) 2001

Collin Starkweather <collin.starkweather@colorado.edu>

=head1 ACKNOWLEDGEMENTS

Many thanks to the folks at SourceForge for creating a robust
development environment to support open source projects such as Peep.

If you are not familiar with SourceForge, please visit their site at

  http://www.sourceforge.net

=head1 SEE ALSO

perl(1), peepd(1), logparser, sysmonitor, pinger, peck, keytest.

=head1 TERMS AND CONDITIONS

This software is issued under the Gnu General Public License.

For more information, write to Michael Gilfix
(mgilfix@eecs.tufts.edu).

This version of Peep is open source; you can redistribute it and/or
modify it under the terms listed in the file COPYING included with the
full Peep distribution which can be found at

  http://peep.sourceforge.net

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 RELATED SOFTWARE

For those interested in a robust network and systems monitoring tools,
your humble author has found Big Brother to be a valuable resource
which is complementary to Peep.  Big Brother is an open source product
and there are a large number of user-contributed plug-ins which make
it ideal for a variety of needs.

You can find more information on Big Brother at

  http://www.bb4.com

Those who enjoy Peep may also enjoy checking out logplay, which is
similar in concept but fills a different niche.

You can find more information on logplay at

  http://projects.babblica.net/logplay

Logplay is not under active development at the time, though many ideas
from the project are being incorporated into Peep with the assistance
of the author, Rando Christensen, who has generously donated his time
in many productive discussions.

Please contact me at

  collin.starkweather@colorado.edu

if you have any questions.

=head1 APPENDIX A:  THE STOCK TICKER CONFIGURATION

  client ticker
    class morgenstern
    port 1999
    config
      # Stock symbol  Stock exchange    Event             Max      Min  
      RHAT            nasdaq            red-hat           4.0      3.6
      SUNW            nasdaq            sun-microsystems  9.0      8.0
    end config
    notification
      notification-hosts morgenstern
      notification-recipients collin.starkweather@colorado.edu
      notification-level warn
    end notification
  end client ticker

  events
  # Event Type    | Path to Sound File               | # of sounds to load
  ... 
  red-hat           /usr/local/share/peep/sounds/misc/events/rooster.*   1
  sun-microsystems  /usr/local/share/peep/sounds/misc/events/doorbell.*  1
  end events

=head1 APPENDIX B:  THE STOCK TICKER

Note the PODs at the beginning of the script.  When the script is run with the help flag

  ./ticker --help

the client will display whatever PODs are included with the script.

  #!/usr/bin/perl

  =head1 NAME
  
  ticker - A stock monitoring client written for Peep: The Network
  Auralizer.
  
  =head1 USAGE
  
    ./ticker --help
  
    ./ticker --noautodiscovery --server=localhost --port=2001 --nodaemon
  
  If you have any problems, try turning on debugging output with
  something like --debug=9.
  
  =head1 CONFIGURATION
  
  To use this client, include a section like the following in peep.conf:
  
    client ticker
      class home
      port 1999
      config
        # Stock symbol  Stock exchange    Event             Max      Min  
        RHAT            nasdaq            red-hat           4.0      3.6
        SUNW            nasdaq            sun-microsystems  9.0      8.0
      end config
      notification
        notification-hosts localhost
        notification-recipients bogus.user@bogusdomain.com
        notification-level warn
      end notification
    end client ticker
  
  and another section in the events block with something like

    events
    #Event Type      |          Path to Sound File           | # of sounds to load
    ...
    red-hat            /usr/local/share/peep/sounds/misc/events/rooster.*        1
    sun-microsystems   /usr/local/share/peep/sounds/misc/events/doorbell.*       1
    end events

  =head1 AUTHOR
  
  Collin Starkweather <collin.starkweather@colorado.edu> Copyright (C) 2001
  
  =head1 SEE ALSO 
  
  perl(1), peepd(1), Net::Peep, Net::Peep::Client, Net::Peep::BC,
  Net::Peep::Notifier, Net::Peep::Notification, Finance::Quote
  
  http://www.sourceforge.net

  =cut
  
  # Always use strict :-)
  use strict;
  use Sys::Hostname;
  use Net::Peep::BC;
  use Net::Peep::Log;
  use Net::Peep::Client;
  use Net::Peep::Data::Notice;
  use Net::Peep::Notifier;
  use Net::Peep::Notification;
  use Finance::Quote;
  use vars qw{ %config $logger $client $quoter $conf };

  $logger = new Net::Peep::Log;
  $client = new Net::Peep::Client;
  $quoter = new Finance::Quote;

  $client->name('ticker');

  $client->initialize();

  $client->parser( \&parse );

  my $conf = $client->configure();

  $client->callback( \&loop );
  $client->MainLoop(60);

  sub parse {
    for my $line (@_) {
      if ($line =~ /^\s*([A-Z]+)\s+(\w+)\s+([\w\-]+)\s+([\d\.]+)\s+([\d\.]+)/) {
        my ($symbol,$exchange,$event,$max,$min) = ($1,$2,$3,$4,$5,$6);
          $config{$symbol} = { event=>$event, exchange=>$exchange, max=>$max, min=>$min };
       }
    }
  } # end sub parse

  sub loop {
    for my $key (sort keys %config) {
      $logger->log("Checking the price of [$key] ...");
      # Fetch some information about the stock including the price
      my %results = $quoter->fetch($config{$key}->{'exchange'},$key);
      my $price = $results{$key,'price'};
      $logger->log("\tThe price of [$key] is [$price].");
      if ($price > $config{$key}->{'max'} or $price < $config{$key}->{'min'}) {
        $logger->log("\tThe price is out of bounds!  Sending notification ....");
        # The price is out of bounds!  We'll start peeping ...
        my $broadcast = Net::Peep::BC->new($conf);
        my $notice = new Net::Peep::Data::Notice;
	$notice->host(hostname());
	$notice->client('ticker');
	$notice->type(0);
	$notice->sound($config{$key}->{'event'});
	$notice->location(128);
	$notice->priority(0);
	$notice->volume(255);
	$notice->date(time);
	$notice->data("The price of $key is $price!");
	$notice->metric($price);
	$notice->level('crit');
        $broadcast->send($notice);
        my $notifier = new Net::Peep::Notifier;
        my $notification = new Net::Peep::Notification;
        $notification->client('ticker');
        $notification->status('crit');
        $notification->datetime(time());
        $notification->message("The price of $key is $price!");
        $notifier->notify($notification);
      }
    }
  } # end sub loop
  
=cut

=head1 APPENDIX C:  THE THEME FILE

  <theme name="collin">
    <sounds>
      <sound>
        <name>light-chirps-04</name>
        <category>wetlands</category>
        <type>events</type>
        <format>raw</format>
        <description></description>
        <path>wetlands/events/light-chirps</path>
      </sound>
      <sound>
        <name>rooster</name>
        <category>misc</category>
        <type>events</type>
        <format>raw</format>
        <description>A rooster crow</description>
        <path>misc/events/rooster</path>
      </sound>
    </sounds>
    <events>
      <event>
        <name>su-login</name>
        <sound>light-chirps-04</sound>
        <description>If someone logs in as root, this event will be triggered</description>
      </event>
      <event>
        <name>bad-su-login</name>
        <sound>rooster</sound>
        <description>If someone unsuccessfully tries to log in as root, this event will be triggered</description>
      </event>
    </events>
    <states>
      <state>
        <name>loadavg</name>
        <description>
        The sound of running water gets progressively stronger
        as the 5 minute load average increases
        </description>
        <threshold>
          <level>0.5</level>
          <fade>0.5</fade>
          <sound>water-01</sound>
        </threshold>
        <threshold>
          <level>1.0</level>
          <fade>0.25</fade>
          <sound>water-02</sound>
        </threshold>
      </state>
    </states>
    <clients>
      <client name="logparser">
        <options>
          <option>
            <name>port</name>
            <value>1999</value>
          </option>
          <option>
            <name>logfile</name>
            <value>/var/log/messages</value>
          </option>
          <option>
            <name>groups</name>
            <value>default</value>
          </option>
        </options>
        <configuration><![CDATA[
          # All patterns matched are done using Perl/awk matching syntax
          #  Commented lines are ones that BEGIN with a '#'
          #  Reference letters are used for the default section as well as
          #  the command line options -events and -logfile.
  
          events
              # Name       Group     Location     Priority   Notification   Pattern                                 Hosts
              su-login     default   128         255         warn          "\(pam_unix\)\[\d+\]: .* opened .* root" localhost
              # note that if the previous regex matches, the following will be ignored
              bad-su-login default   128         255         warn          "\(pam_unix\)\[\d+\]: .* closed .* root" localhost
          end events
          ]]>
          </configuration>
      </client>
    </clients>
  </theme>

=cut
