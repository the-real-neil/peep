#!/usr/bin/perl

# Test of the Net::Peep::Data::Notice class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 080.t

# Tests Peep theme configuration parsing and the client configuration process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..4\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Log;
use Net::Peep::Data::Notice;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug = 3;

my ($notice);

eval {
	$notice = new Net::Peep::Data::Notice;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep notice data class:\n";

eval { 
	my $xml = join '', <DATA>;
	$notice->deserialize($xml);
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($notice->host() eq 'freak.collinstarkweather.com' and $notice->level() eq 'warn') {
	print "ok\n";
	exit 0;
} else {
	print STDERR "not ok:  The notice data was not parsed correctly.";
	exit 1;
}

__DATA__
<notice>
  <host>freak.collinstarkweather.com</host>
  <client>logparser</client>
  <type>state</type>
  <metric>1.0</metric>
  <location>128</location>
  <volume>255</volume>
  <level>warn</level>
  <data>This is a test.  This is only a test.</data>
  <date>Sat Jun  1 23:36:15 2002</date>
</notice>
