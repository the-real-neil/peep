#!/usr/bin/perl

# Test of:
# o XML configuration file parsing
# o The configuration class Net::Peep::Conf
# o Client notifications to a server
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 101.t

# Tests Peep configuration parsing and the client configuration process

BEGIN { $Test::Harness::verbose++; $|++; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Carp;
use Data::Dumper;
use Net::Peep::BC;
use Net::Peep::Conf;
use Net::Peep::Log;
use Net::Peep::Data::Notice;

$loaded = 1;

print "ok\n";

$Net::Peep::Log::debug = 3;

my ($conf,$bc,$notice);

eval {

	$conf = new Net::Peep::Conf;
	$conf->client('hacked.keytest');
	my $data = join '', <DATA>;
	$conf->deserialize($data);

};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

$Test::Harness::verbose += 1;
$Net::Peep::Log::debug = 1;

print STDERR "\nTesting Peep configuration file parser:\n";

eval { 

	$bc = new Net::Peep::BC ( $conf );
	$notice = new Net::Peep::Data::Notice;

};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep client notice:\n";

eval { 

	$notice->host('www.collinstarkweather.com');
	$notice->client('hacked.keytest');
	$notice->type('event');
	$notice->location(128);
	$notice->priority(1);
	$notice->volume(0);
	$notice->dither(255);
	$notice->flags(0);
	$notice->data('May 18 04:18:48 foo sendmail[24566]: to=bogususer, stat=Sent');
	$notice->sound('bad-login');
	#$notice->sound('whistle-01');
	$notice->date(time());
	print STDERR "\tSending notice ...\n";
	$bc->send($notice);
	print STDERR "\tNotice sent.\n";

};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
	exit 0;
}

__DATA__
<?xml version='1.0' encoding='UTF-8' standalone='no'?>

<configuration>
  <!--
     Peep:  The Network Auralizer - Main configuration file
  -->
  <general>
    <version>0.5.1</version>
    <!-- Path where the sounds are stored -->
    <soundpath>/usr/local/share/peep/sounds</soundpath>
    <!-- These global options can be overridden by either -->
    <!-- command-line options or options defined for a -->
    <!-- specific client -->
    <options>
      <option name="logfile" value="/var/log/peep/peep.log"/>
      <option name="debug" value="3"/>
      <option name="protocol" value="tcp"/>
    </options>
  </general>
  <notification interval="21600">
    <relays>
      <host name="localhost" ip="127.0.0.1"/>
    </relays>
  </notification>
  <class name="main" port="2000">
    <servers>
      <server name="darktower" port="2001"/>
    </servers>
  </class>
  <sounds>
    <sound>
      <name>whistle-01</name>
      <category>wetlands</category>
      <type>coupled</type>
      <format>raw</format>
      <description></description>
      <path>wetlands/coupled/whistle-01</path>
    </sound>
    <sound>
      <name>light-chirps-04</name>
      <category>wetlands</category>
      <type>events</type>
      <format>raw</format>
      <description></description>
      <path>wetlands/events/light-chirps-04</path>
    </sound>
    <sound>
      <name>thrush-01</name>
      <category>wetlands</category>
      <type>events</type>
      <format>raw</format>
      <description></description>
      <path>wetlands/events/thrush-01</path>
    </sound>
    <sound>
      <name>doorbell</name>
      <category>misc</category>
      <type>events</type>
      <format>raw</format>
      <description>A "ding dong" doorbell sound</description>
      <path>misc/events/doorbell</path>
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
      <name>http</name>
      <sound>whistle-01</sound>
      <description>Anybody who accesses a web page will trigger this event</description>
    </event>
    <event>
      <name>su-login</name>
      <sound>light-chirps-04</sound>
      <description>If someone logs in as root, this event will be triggered</description>
    </event>
    <event>
      <name>su-logout</name>
      <sound>thrush-01</sound>
      <description>When someone logs out of a root account, this event will be triggered</description>
    </event>
    <event>
      <name>ping-yahoo</name>
      <sound>doorbell</sound>
      <description>When www.yahoo.com can't be pinged, a doorbell will ring</description>
    </event>
    <event>
      <name>red-hat</name>
      <sound>rooster</sound>
      <description>When Red Hat (RHAT) goes above or below a certain price, a rooster will crow</description>
    </event>
  </events>
  <states>
    <state>
      <name>loadavg</name>
      <path>water-01</path>
      <description>
        The sound of running water gets progressively stronger 
        as the 5 minute load average increases
      </description>
      <threshhold>
        <level>0.5</level>
        <fade>0.5</fade>
      </threshhold>
    </state>
  </states>
  <clients>
    <client name="hacked.keytest" port="2000">
      <options>
        <option name="autodiscovery" value="0"/>
        <option name="server" value="127.0.0.1"/>
        <option name="port" value="2001"/>
      </options>
      <configuration>
        # All patterns matched are done using Perl/awk matching syntax
        # Commented lines are ones that BEGIN with a '#'
        # Reference letters are used for the default section as well as
        # the command line options -events and -logfile.
        #·
        # Name      Reference-Letter    Location     Priority             Pattern·
        #
        su                 U            128         255           "(su.*root)|(su: SU)"
        badsu              B            128         255           "BADSU"
        </configuration>
        <notification level="warn">
          <hosts>
            <host name="localhost" ip="127.0.0.1"/>
          </hosts>
          <recipients>
            <recipient email="bogus.user@bogusdomain.com"/>
            <recipient email="bogus.admin@bogusdomain.com"/>
          </recipients>
        </notification>
    </client>
    <client name="logparser" port="2000">
      <options>
        <option>
          <name>logfile</name>
          <value>/var/log/messages,/var/log/syslog</value>
        </option>
      </options>
      <configuration>
        # All patterns matched are done using Perl/awk matching syntax
        # Commented lines are ones that BEGIN with a '#'
        # Reference letters are used for the default section as well as
        # the command line options -events and -logfile.
        #·
        # Name      Reference-Letter    Location     Priority             Pattern·
        #
        su                 U            128         255           "(su.*root)|(su: SU)"
        badsu              B            128         255           "BADSU"
        </configuration>
        <notification level="warn">
          <hosts>
            <host name="localhost" ip="127.0.0.1"/>
          </hosts>
          <recipients>
            <recipient email="bogus.user@bogusdomain.com"/>
            <recipient email="bogus.admin@bogusdomain.com"/>
          </recipients>
        </notification>
    </client>
    <client name="sysmonitor">
      <configuration>
        # You can figure out what options these correspond to by doing a Uptime -help
        sleep      60         # Number of seconds to sleep
        loadsound  loadavg    # The sound to use when playing a load sound
        userssound users      # The sound to use for number of users
        maxload    2.5        # The initial value to consider maximum load
        maxusers   200        # The initial value to consider a lot of users
        loadloc    128        # Stereo location for load sounds
        usersloc   128        # Stereo location for user sounds
      </configuration>
    </client>
  </clients>
</configuration>
