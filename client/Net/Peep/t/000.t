#!/usr/bin/perl

# Test of whether some modules are installed that are necessary for some of the bundled clients
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 000.t

# Tests whether some Perl modules are installed which are used by bundled clients

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..5\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

use Net::Peep::Log;

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;
$Net::Peep::Log::debug=3;

my ($sound);

eval {
	require File::Tail;
};

if ($@) {

	print STDERR <<"eop";

You do not appear to have File::Tail installed.  This module is used
for the logparser client.  

Please install File::Tail if you would like to use the logparser
client.  You can install File::Tail through the CPAN with 

  sudo perl -MCPAN -e 'install File::Tail'

eop
	;

	unless ($ENV{'AUTOMATED_BUILD'}) {
		print STDERR <<"eop";
Press Enter to continue.

eop
		;
		<STDIN>;
	}
	
} else {

	print STDERR <<"eop";

You appear to have File::Tail installed.  This module is used
for the logparser client.

eop

}

print "ok\n";

eval {
	require Net::Ping::External;
};

if ($@) {

	print STDERR <<"eop";

You do not appear to have Net::Ping::External installed.  This module is used
for the pinger client.  

Please install Net::Ping::External if you would like to use the pinger
client.  You can install Net::Ping::External through the CPAN with 

  sudo perl -MCPAN -e 'install Net::Ping::External'

eop
	;

	unless ($ENV{'AUTOMATED_BUILD'}) {
		print STDERR <<"eop";
Press Enter to continue.

eop
		;
		<STDIN>;
	}
	
} else {

	print STDERR <<"eop";

You appear to have Net::Ping::External installed.  This module is used
for the pinger client.

eop

}

print "ok\n";

eval {
	require Filesys::DiskFree;
};

if ($@) {

	print STDERR <<"eop";

You do not appear to have Filesys::DiskFree installed.  This module is used
for the sysmonitor client.  

Please install Filesys::DiskFree if you would like to use the sysmonitor
client.  You can install Filesys::DiskFree through the CPAN with 

  sudo perl -MCPAN -e 'install Filesys::DiskFree'

eop
	;

	unless ($ENV{'AUTOMATED_BUILD'}) {
		print STDERR <<"eop";
Press Enter to continue.

eop
		;
		<STDIN>;
	}
	
} else {

	print STDERR <<"eop";

You appear to have Filesys::DiskFree installed.  This module is used
for the sysmonitor client.

eop

}

print "ok\n";

eval {
	require Proc::ProcessTable;
};

if ($@) {

	print STDERR <<"eop";

You do not appear to have Proc::ProcessTable installed.  This module is used
for the sysmonitor client.  

Please install Proc::ProcessTable if you would like to use the sysmonitor
client.  You can install Proc::ProcessTable through the CPAN with 

  sudo perl -MCPAN -e 'install Proc::ProcessTable'

eop
	;

	unless ($ENV{'AUTOMATED_BUILD'}) {
		print STDERR <<"eop";
Press Enter to continue.

eop
		;
		<STDIN>;
	}
	
} else {

	print STDERR <<"eop";

You appear to have Proc::ProcessTable installed.  This module is used
for the sysmonitor client.

eop

}

print "ok\n";
exit 0;

__DATA__
