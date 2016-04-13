#!/usr/bin/perl

# Test of the Net::Peep::Data::Sound class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 010.t

# Tests Peep sound configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Data::Sound;
use Net::Peep::Log;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($sound);

eval {
	$sound = new Net::Peep::Data::Sound;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep sound data class:\n";

eval { 
	my $xml = join '', <DATA>;
	$sound->deserialize($xml);
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($sound->name() eq 'Redwing Blackbird 1' and $sound->description() eq '3 quick chirps followed by a long call.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The sound data was not parsed correctly.";
	exit 1;
}

__DATA__
<sound name="Redwing Blackbird 1">
  <category>Wetlands</category>
  <type>event</type>
  <?testproc arg1 arg2 arg3 ?>
  <format>raw</format>
  <length>2.8 sec</length>
  <description>3 quick chirps followed by a long call.</description>
  <filename>/usr/local/share/peep/events/wetlands/sounds/redwing-blackbird-01.01</filename>
</sound>
