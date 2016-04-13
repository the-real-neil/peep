#!/usr/bin/perl

# Test of client-server communication.  The first test that produces a sound.
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 200.t

# tests both Net::Peep::BC and Net::Peep::Peck

BEGIN { $Test::Harness::verbose++; $|++; print "1..3\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Log;
use Net::Peep::Peck;

$loaded = 1;

print "ok\n";

$Net::Peep::Log::debug = 0;

my ($conf,$parser);

eval {

	$pecker = new Net::Peep::Peck;

};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

unless ($ENV{'AUTOMATED_BUILD'}) {

	$Test::Harness::verbose += 1;

	print STDERR <<"eop";


If you have a Peep server running on the machine this client is being installed
on which just so happens to be listening to port 2001 and just so happens to
have the event 'rooster' defined in its configuration file, you should hear a
rooster crow after pressing Enter.

Please press Enter.
eop

	<STDIN>;

} # end unless $ENV{'AUTOMATED_BUILD'}

eval {
	@ARGV = ( '--type=0','--sound=rooster','--server=localhost','--port=2001','--volume=255','--config=./conf/peep.conf');
	$pecker->peck();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
	exit 0;
}

