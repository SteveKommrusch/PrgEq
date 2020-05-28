#!/usr/bin/perl
#
use strict;
use warnings;

#use experimental 'smartmatch';

require "../src/genProgUsingAxioms.pl";
require "../src/allPossibleAxioms.pl";

sub FindEqRec {
    my %visited;
    FindEqRecInt($_[0], $_[1], %visited, 0, $_[2])
}

# WIP
sub FindEqRecInt {
    my $progA = $_[0];
    my $progB = $_[1];

    my $visited = $_[2];
    my $depth = $_[3];
    my $max_depth = $_[4];

    if ($progA eq $progB) {
        return "Eq";
    }

    if ($depth ge $max_depth) {
        return "Neq"
    }

    my $axioms = AllPossibleAxioms($progA, "");
    my @axiomsAndPaths = split / /, $axioms;

    my $toApply = "";
    while (@axiomsAndPaths) {
        my $first = shift @axiomsAndPaths;
        $toApply = $toApply.$first." ";
        # if operation then apply it and not put it into the path
        if ($first ne "left" && $first ne "right") {
            # otherwise apply axiom
            my $newIntermediate = GenProgUsingAxioms($progA, "", $toApply);
            # if the program is not visited we do a recursive search
            if ($newIntermediate !~ $visited) {
                if (FindEqRecInt($newIntermediate, $progB, $visited, $depth+1, $max_depth) eq "Eq") {
                    return "Eq"
                }
            }
            $toApply = "";
        }
    }
    "Neq"
}

sub FindEq {
    my $progA = $_[0];
    my $progB = $_[1];

    my %visited;

    my @progList;
    push @progList, $progA;

    while (@progList) {
        my $progIntermediate = pop @progList;

        if ($progIntermediate eq $progB) {
            return "Eq";
        }

        # mark the current prog as visited
        #push @visited, $progIntermediate;
        $visited{$progIntermediate} = 1;

        # this also returns paths so we can call it from the root
        my $axioms = AllPossibleAxioms($progIntermediate, "");
        my @axiomsAndPaths = split / /, $axioms;

        my $toApply = "";
        while (@axiomsAndPaths) {
            my $first = shift @axiomsAndPaths;
            $toApply = $toApply.$first." ";
            # if operation then apply it and not put it into the path
            if ($first ne "left" && $first ne "right") {
                # otherwise apply axiom
                my $newIntermediate = GenProgUsingAxioms($progIntermediate, "", $toApply);
                # if the program is not visited we add it to the list
                if (!exists $visited{$newIntermediate}) {
                    push @progList, $newIntermediate;
                }
                $toApply = "";
            }
        }
    }

    "Neq"
}

#my $progA = "( +s c ( +s a b ) )";
#my $transA = GenProgUsingAxioms($progA, "", "right Commute ");
#print $progA, "\n";
#print $transA, "\n\n";
#print FindEq("( +s c ( +s a b ) )", "( +s c ( +s b a ) )"), "\n";
#print FindEq("( +s c ( +s a d ) )", "( +s c ( +s b a ) )"), "\n";
#print FindEqRec("( +s c ( +s a b ) )", "( +s c ( +s b a ) )", 5), "\n";

#if ( ! -f $ARGV[2] || ! -f $ARGV[3] ) {
#  print "Usage: search.pl beam maxtok src model\n";
#  print "    Open source file and search 12 steps to see if model can prove\n";
#  print "    programs equal using beam width and up to maxtok for both programs.\n";
#  print "  Example: search.pl 5 all_multi_test.txt final-model_step_100000.pt\n";
#  exit(1);
#}

#my $beam=$ARGV[0];
open(my $src,"<",$ARGV[0]) || die "open src failed: $!";

my $num = 0;

while (<$src>) {
    /X (.*) Y (.*) Z (.*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $progB = $2;
    my $transfo = $3;

    if (FindEq($progA, $progB) ne "Eq") {
        print "Found not equivalent programs", $progA, $progB, $transfo, "\n";
    }

    $num += 1;
    if ($num % 10 eq 0) {
        print "Did 1000 programs\n";
    }
}
