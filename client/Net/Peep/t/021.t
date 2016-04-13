#!/usr/bin/perl

# Test of the Net::Peep::Data::States class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 021.t

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::States;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($pool);

eval {
	$pool = new Net::Peep::Data::States;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep state pool data class:\n";

my (@pool,$state);

eval { 
	my $xml = join '', <DATA>;
	$pool->deserialize($xml);
	@pool = $pool->state();
	$state = pop @pool;
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($state->name() eq 'load-4' and $state->description() eq 'Sound of rustling leaves.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The state data was not parsed correctly.";
	exit 1;
}

__DATA__
<states>
  <state>
    <name>load-1</name>
    <description>Sound of rustling leaves.</description>
    <threshholds>
      <threshhold>
        <level>0.5</level>
        <sound>leaves-01</sound>
        <fade>0.25</fade>
      </threshhold>
      <threshhold>
        <level>1.0</level>
        <sound>leaves-01</sound>
        <fade>0.1</fade>
      </threshhold>
    </threshholds>
  </state>
  <state>
    <name>load-2</name>
    <description>Sound of running water.</description>
    <threshholds>
      <threshhold>
        <level>1.0</level>
        <sound>water-02</sound>
        <fade>0.25</fade>
      </threshhold>
      <threshhold>
        <level>2.0</level>
        <sound>water-01</sound>
        <fade>0.1</fade>
      </threshhold>
    </threshholds>
  </state>
  <state>
    <name>load-3</name>
    <segments>4</segments>
    <description>Sound of rustling leaves.</description>
    <sound>leaves-3</sound>
  </state>
  <state>
    <name>load-4</name>
    <segments>4</segments>
    <description>Sound of rustling leaves.</description>
    <sound>leaves-4</sound>
  </state>
</states>
