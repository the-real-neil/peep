#!/usr/bin/perl

# Test of the Net::Peep::Data::Event class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 030.t

# Tests Peep event configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Log;
use Net::Peep::Data::Event;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($event);

eval {
	$event = new Net::Peep::Data::Event;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep event data class:\n";

eval { 
	my $xml = join '', <DATA>;
	$event->deserialize($xml);
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($event->name() eq 'Test' and $event->description() eq 'This is a test.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The event data was not parsed correctly.";
	exit 1;
}

__DATA__
<event>
  <name>Test</name>
  <sound>water-01</sound>
  <description>This is a test.</description>
</event>
