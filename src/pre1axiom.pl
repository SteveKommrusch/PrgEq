#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/genProgUsingAxioms.pl";

if ($ARGV[0]) {
  print "Usage: pre1axiom.pl\n";
  print "  Transform src sequence to multiple samples each 1 axiom long.\n";
  exit(1);
}

my %progs;

while (<>) {
    /X (.*) Y (.*) Z (.*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $progB = $2;
    my $allTransform = $3." ";
    my $origZ = $3;
    my $tokA = $progA;
    $tokA =~s/(.)/$1 /g;
    $tokA =~s/\s+/ /g;
    $tokA =~s/(\( .) (.)/$1$2/g;
    die "tokA didn't match: $tokA vs $progA\n" if ($tokA ne "$progA ");
    my $tokB = $progB;
    $tokB =~s/(.)/$1 /g;
    $tokB =~s/\s+/ /g;
    $tokB =~s/(\( .) (.)/$1$2/g;
    die "tokB didn't match: $tokB vs $progB\n" if ($tokB ne "$progB ");
    next if exists $progs{$progA};
    $progs{$progA} = 1;
    my $progIntermediate=$progA;
    my $samples="";
    while ($allTransform =~s/^([a-z ]*[A-Z][a-z]*) //) {
        my $Z=$1;
        print "X $progIntermediate Y $progB Z $Z\n";
        my $progAxiom=GenProgUsingAxioms($progIntermediate,"",$Z." ");
        if ($progIntermediate eq $progAxiom) {
            die "Axiom not applied: X $progA Y $progB Z $origZ died at $Z on $progIntermediate\n";
        }
        $progIntermediate = $progAxiom;
    }
    if ($progIntermediate ne $progB) {
        die "Incorrect path computation: X $progA Y $progB Z $origZ produces $progIntermediate\n";
    }
}
