#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/allPossibleAxioms.pl";

if (! $ARGV[0] || ! -f $ARGV[0]) {
  print "Usage: possibleAxioms.pl file\n";
  print "  Print our program along with all possible axioms.\n";
  exit(1);
}

open(my $src,"<",$ARGV[0]) || die "open src failed: $!";

while (<$src>) {
    /X (.*) Y (.*) Z (.*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $allAxioms = AllPossibleAxioms($progA,"");
    my $numtokA = int(grep { !/[()]/ } split / /,$progA);
    my $numAxioms = int(grep { /[A-Z]/ } split / /,$allAxioms);
    print "X $progA Y $numtokA $numAxioms Z $allAxioms\n";
}
