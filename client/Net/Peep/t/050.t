#!/usr/bin/perl

# Test of the Net::Peep::Data::Conf::Class and Net::Peep::Data::Conf::Class::Server classes
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 050.t

# Tests Peep class configuration parsing and the client configuration
# process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Data::Conf::Class;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;

my ($event);

eval {
	$class = new Net::Peep::Data::Conf::Class;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep class data class:\n";

my ($server,$servers);

eval { 
	my $xml = join '', <DATA>;
	$class->deserialize($xml);
	($servers) = $class->servers();
	($server) = $servers->server();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($class->port() == 2000 and $server->name() eq 'dev.collinstarkweather.com') {
	print "ok\n";
} else {
	print STDERR "not ok:  The event data was not parsed correctly.";
	exit 1;
}

eval { 
	print STDERR "\n", $class->serialize();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

__DATA__
<class>
  <port>2000</port>
  <servers>
    <server>
      <name>dev.collinstarkweather.com</name>
      <port>2001</port>
    </server>
  </servers>
</class>

