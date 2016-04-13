#!/usr/bin/perl

# Test of the Net::Peep::Data::Sounds class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 011.t

# Tests Peep sounds configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::Sounds;


$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($sounds);

eval {
	$sounds = new Net::Peep::Data::Sounds;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep sound pool data class:\n";

my (@pool,$sound);

eval { 
	my $xml = join '', <DATA>;
	$sounds->deserialize($xml);
	@pool = $sounds->sound();
	$sound = pop @pool;
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($sound->name() eq 'redwing-blackbird-4' and $sound->description() eq '3 quick chirps followed by a long call.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The sound data was not parsed correctly.";
	exit 1;
}

__DATA__
<sounds>
  <sound>
    <name>redwing-blackbird-1</name>
    <category>wetlands</category>
    <type>event</type>
    <format>raw</format>
    <length>2.8 sec</length>
    <description>3 quick chirps followed by a long call.</description>
    <filename>/usr/local/share/peep/sounds/wetlands/events/redwing-blackbird-01.01</filename>
  </sound>
  <sound>
    <name>redwing-blackbird-2</name>
    <category>wetlands</category>
    <type>event</type>
    <format>raw</format>
    <length>2.8 sec</length>
    <description>3 quick chirps followed by a long call.</description>
    <filename>/usr/local/share/peep/sounds/wetlands/events/redwing-blackbird-01.02</filename>
  </sound>
  <sound>
    <name>redwing-blackbird-3</name>
    <category>wetlands</category>
    <type>event</type>
    <format>raw</format>
    <length>2.8 sec</length>
    <description>3 quick chirps followed by a long call.</description>
    <filename>/usr/local/share/peep/sounds/wetlands/events/redwing-blackbird-01.03</filename>
  </sound>
  <sound>
    <name>redwing-blackbird-4</name>
    <category>wetlands</category>
    <type>event</type>
    <format>raw</format>
    <length>2.8 sec</length>
    <description>3 quick chirps followed by a long call.</description>
    <filename>/usr/local/share/peep/sounds/wetlands/events/redwing-blackbird-01.04</filename>
  </sound>
</sounds>

