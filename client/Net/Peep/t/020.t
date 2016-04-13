#!/usr/bin/perl

# Test of the Net::Peep::Data::State and Net::Peep::Data::State::ThreshHolds classes
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 020.t

# Tests Peep state configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Log;
use Net::Peep::Data::State;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($state,$threshholds,$threshhold);

eval {
	$state = new Net::Peep::Data::State;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep state data class:\n";

eval { 
	my $xml = join '', <DATA>;
	$state->deserialize($xml);
	($threshholds) = $state->threshholds();
	($threshhold) = $threshholds->threshhold();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($state->name() eq 'Test' and $state->description() eq 'This is a test.' and
    $threshhold->level() == 0.5) {
	print "ok\n";
} else {
	print STDERR "not ok:  The state data was not parsed correctly.";
}

eval { 
	print STDERR "\n", $state->serialize();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

__DATA__
<state>
  <name>Test</name>
  <description>This is a test.</description>
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
