#!/usr/bin/perl

# Test of:
# o The full gamut of configuration file parsing
# o The configuration class Net::Peep::Conf
# o Basic client initialization and configuration
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 100.t

# Tests Peep configuration parsing and the client configuration process

BEGIN { $Test::Harness::verbose++; $|++; print "1..3\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Log;
use Net::Peep::Conf;
use Net::Peep::Parser;
use Net::Peep::Client;

$loaded = 1;

print "ok\n";

$Net::Peep::Log::debug = 1;

my ($conf,$parser);

eval {

	$conf = new Net::Peep::Conf;
	$parser = new Net::Peep::Parser;

};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

$Test::Harness::verbose += 1;
$Net::Peep::Log::debug = 1;

print STDERR "\nTesting Peep configuration file parser:\n";

eval { 

    @ARGV=('--config=./conf/peep.conf');
    my $client = new Net::Peep::Client;
    $client->name('logparser');
    $client->initialize();
    $client->parser(sub { my @text = @_; &parse(@text); });
    $conf = $client->configure();
    $client->callback(sub { &loop(); });

};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
	exit 0;
}

sub parse {

	my @text = @_;
	for my $line (@text) {
		print STDERR "Client parser found line [$line] ...\n";
	}

} # end sub parse

sub loop {

	print STDERR "\nIn loop method.\n";

} # end sub loop
