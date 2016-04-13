#!/usr/bin/perl

# Test of the Net::Peep::Data::Themes class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 041.t

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::Themes;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($pool);

eval {
	$pool = new Net::Peep::Data::Themes;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep theme pool data class:\n";

my (@pool,$state);

eval { 
	my $xml = join '', <DATA>;
	$pool->deserialize($xml);
	@pool = $pool->theme();
	$theme = pop @pool;
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($theme->name() eq 'another-test-theme' and $theme->description() eq 'Another test.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The state data was not parsed correctly.";
	exit 1;
}

__DATA__
<themes>
  <theme>
    <name>test-theme</name>
    <description>A test.</description>
    <author>Collin Starkweather</author>
    <sounds>
      <sound>
        <name>redwing-blackbird</name>
        <category>wetlands</category>
        <type>event</type>
        <format>raw</format>
        <length>2.8 sec</length>
        <description>3 quick chirps followed by a long call.</description>
        <path>wetlands/events/redwing-blackbird</path>
      </sound>
      <sound>
        <name>thrush</name>
        <category>wetlands</category>
        <type>event</type>
        <format>raw</format>
        <length>2.8 sec</length>
        <description>3 quick chirps.</description>
        <path>wetlands/events/thrush</path>
      </sound>
    </sounds>
    <events>
      <event>
        <name>test-event</name>
        <length>1.27</length>
        <description>This is a test.</description>
        <sound>rooster</sound>
      </event>
    </events>
    <states>
      <state>
        <name>test-state</name>
        <description>This is yet another test.</description>
        <threshholds>
          <threshhold>
            <level>0.5</level>
            <sound>water-02</sound>
            <fade>0.25</fade>
          </threshhold>
          <threshhold>
            <level>1.0</level>
            <sound>water-01</sound>
            <fade>0.1</fade>
          </threshhold>
        </threshholds>
      </state>
    </states>
  </theme>
  <theme>
    <name>another-test-theme</name>
    <description>Another test.</description>
    <author>Collin Starkweather</author>
    <sounds>
      <sound>
        <name>redwing-blackbird</name>
        <category>wetlands</category>
        <type>event</type>
        <format>raw</format>
        <length>2.8 sec</length>
        <description>3 quick chirps followed by a long call.</description>
        <path>wetlands/events/redwing-blackbird</path>
      </sound>
      <sound>
        <name>thrush</name>
        <category>wetlands</category>
        <type>event</type>
        <format>raw</format>
        <length>2.8 sec</length>
        <description>3 quick chirps.</description>
        <path>wetlands/events/thrush</path>
      </sound>
    </sounds>
    <events>
      <event>
        <name>test-event</name>
        <length>1.27</length>
        <description>This is a test.</description>
        <sound>rooster</sound>
      </event>
    </events>
    <states>
      <state>
        <name>test-state</name>
        <description>This is yet another test.</description>
        <threshholds>
          <threshhold>
            <level>0.5</level>
            <sound>water-02</sound>
            <fade>0.25</fade>
          </threshhold>
          <threshhold>
            <level>1.0</level>
            <sound>water-01</sound>
            <fade>0.1</fade>
          </threshhold>
        </threshholds>
      </state>
    </states>
  </theme>
</themes>
