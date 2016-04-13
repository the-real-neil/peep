#!/usr/bin/perl

# Test of the Net::Peep::Data::Conf::General class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 050.t

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Data::Conf::General;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;

my ($event);

eval {
	$general = new Net::Peep::Data::Conf::General;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep general data class:\n";

eval { 
	my $xml = join '', <DATA>;
	$general->deserialize($xml);
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($general->version() eq '0.5.0' and $general->sound_path() eq '/usr/local/share/peep/sounds') {
	print "ok\n";
} else {
	print STDERR "not ok:  The general data was not parsed correctly.";
	exit 1;
}

eval { 
	print STDERR "\n", $general->serialize();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

__DATA__
<general>
  <version>0.5.0</version>
  <sound_path>/usr/local/share/peep/sounds</sound_path>
</general>
