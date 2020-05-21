#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/genProgUsingAxioms.pl";

if (! $ARGV[1] || $ARGV[0] < 10 || ! -f $ARGV[1]) {
  print "Usage: pre1axiom.pl maxTokens file\n";
  print "  Transform samples in file to multiple samples each 1 axiom long.\n";
  print "  While insuring training data fits in network input size maxTokens.\n";
  exit(1);
}

my $maxTokens = $ARGV[0];
open(my $src,"<",$ARGV[1]) || die "open src failed: $!";
my %progs;

while (<$src>) {
    /X (.*) Y (.*) Z (.*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $progB = $2;
    my $allTransform = $3." ";
    my $origZ = $3;
    next if exists $progs{$progA};
    $progs{$progA} = 1;
    my $numtokB = int(grep { !/[()]/ } split / /,$progB);
    my $progIntermediate=$progA;
    my $samples="";
    my %inter;
    $inter{$progA}=1;
    while ($progB && $allTransform =~s/^([a-z ]*[A-Z][a-z]*) //) {
        my $Z=$1;
        $samples .= "X $progIntermediate Y $progB Z $Z\n";
        my $progAxiom=GenProgUsingAxioms($progIntermediate,"",$Z." ");
        if ($progIntermediate eq $progAxiom) {
            die "Axiom not applied: X $progA Y $progB Z $origZ died at $Z on $progIntermediate\n";
        }
        if (exists $inter{$progAxiom} || $progAxiom =~/TOODEEP/ || int(grep { !/[()]/ } split / /,$progAxiom) + $numtokB >= $maxTokens) {
            $progB="";  # Delete target, path too large or created loop
        }
        $inter{$progAxiom}=1;
        $progIntermediate = $progAxiom;
    }
    if ($progB) {
        print $samples;
        if ($progIntermediate ne $progB) {
            die "Incorrect path computation: X $progA Y $progB Z $origZ produces $progIntermediate\n";
        }
    }
}
