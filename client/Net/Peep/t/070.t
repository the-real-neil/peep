#!/usr/bin/perl

# Test of the Net::Peep::Data::Conf class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 070.t

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Data::Dumper;
use Net::Peep::Data::Conf;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;

my ($event);

eval {
	$conf = new Net::Peep::Data::Conf;
};

if ($@) {
	print "not ok:  $@\n";
	exit 1;
} else {
	print "ok\n";
}

print STDERR "\nTesting Peep configuration data class:\n";

my ($classes,$class,$general);
eval { 
	my $xml = join '', <DATA>;
	$conf->deserialize($xml);
	($classes) = $conf->classes();
	($class) = $classes->class();
	($general) = $conf->general();
};

if ($@) {
	print STDERR "not ok:  $@";
	exit 1;
} else {
	print "ok\n";
}

if ($general->version() eq '0.5.0' and $general->sound_path() eq '/usr/local/share/peep/sounds' and $class->port() == 2000) {
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
<configuration>
  <classes>
    <class>
      <port>2000</port>
      <servers>
        <server>
          <name>dev.collinstarkweather.com</name>
          <port>2001</port>
        </server>
      </servers>
    </class>
  </classes>
  <general>
    <version>0.5.0</version>
    <sound_path>/usr/local/share/peep/sounds</sound_path>
  </general>
</configuration>
