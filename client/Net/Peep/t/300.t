#!/usr/bin/perl

# Test of the Net::Peep::Scheduler class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 300.t

# tests Net::Peep::Scheduler and, indirectly, Net::Peep::Peck

BEGIN { $Test::Harness::verbose++; $|++; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Scheduler;
use Net::Peep::Peck;

$loaded = 1;

print "ok\n";

$Net::Peep::Log::debug = 0;

eval {

	$scheduler0 = new Net::Peep::Scheduler;
	$scheduler1 = new Net::Peep::Scheduler;
	$pecker = new Net::Peep::Peck;

};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

$Test::Harness::verbose += 1;

unless ($ENV{'AUTOMATED_BUILD'}) {

	print STDERR <<"eop";

The Peep scheduler will now be tested.

If you have a Peep server running on the machine this client is being installed
on which just so happens to be listening to port 2001 and have the events
'sigh' and 'doorbell' defined, you should hear a sigh in 3 seconds, then a
doorbell in 5 seconds.

If nothing happens for more than 10 seconds, press Ctrl-C.

Press enter to continue ....

eop

	<STDIN>;

}

my $continue = 1;
my $ref = \$continue;

$scheduler0->schedulerAddEvent('test', 5, 0, 'second', sub { &handler(5,$pecker) });
$scheduler1->schedulerAddEvent('test', 3, 0, 'first', sub { &handler(3,$pecker) } );
$scheduler1->schedulerAddEvent('test', 6, 0, 'third', sub { $$ref = 0 } );

while (1) { last unless $continue; }

print "ok\n";
exit 0;

sub handler {

	my $seconds = shift;
	my $pecker = shift;

	eval {

		print <<"eop";

Peep!

eop

		if ($seconds == 3) {
			@ARGV = ( '--type=0','--sound=sigh','--server=localhost','--port=2001','--volume=255','--config=./conf/peep.conf');
		} else {
			@ARGV = ( '--type=0','--sound=doorbell','--server=localhost','--port=2001','--volume=255','--config=./conf/peep.conf');
		}
		$pecker->peck();

	};

	if ($@) {
		print STDERR "not ok:  $@";
	} else {
		print "ok\n";
	}

}
