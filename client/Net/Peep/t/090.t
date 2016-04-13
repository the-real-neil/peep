#!/usr/bin/perl

# Test of the Net::Peep::Data::Theme class
# 
# Run with
#
# perl -I../blib/lib -e 'use Test::Harness qw(&runtests $verbose); $verbose=0; runtests @ARGV;' 090.t

# Tests Peep theme configuration parsing and the client configuration process

BEGIN { $Test::Harness::verbose=1; $|=1; print "1..1\n"; }
END {print "not ok\n", exit 1 unless $loaded;}

$loaded = 1;

print "ok\n";

$Test::Harness::verbose = 1;

print STDERR "\nThis test has been deprecated and will be replaced at a later date.\n";

__DATA__
