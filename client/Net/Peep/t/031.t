#!/usr/bin/perl

# Test of the Net::Peep::Data::Events class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 031.t

# Tests Peep events configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::Events;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($pool);

eval {
	$pool = new Net::Peep::Data::Events;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep event pool data class:\n";

my (@pool,$event);

eval { 
	my $xml = join '', <DATA>;
	$pool->deserialize($xml);
	@pool = $pool->event();
	$event = pop @pool;
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($event->name() eq 'ibm' and $event->description() eq 'Check the price of IBM stock.') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The event data was not parsed correctly.";
	exit 1;
}

__DATA__
<events>
  <event>
    <name>red-hat</name>
    <description>Check the price of Red Hat (RHAT) stock.</description>
    <sound>doorbell</sound>
  </event>
  <event>
    <name>sun-microsystems</name>
    <description>Check the price of Sun Microsystems (SUNW) stock.</description>
    <sound>rooster</sound>
  </event>
  <event>
    <name>ibm</name>
    <description>Check the price of IBM stock.</description>
    <sound>bells-1</sound>
  </event>
</events>

