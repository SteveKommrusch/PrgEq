#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/genProgUsingAxioms.pl";

if ( ! -f $ARGV[0] || ! -f $ARGV[1] ) {
  print "Usage: checkeq.pl truth predicted\n";
  print "    Check number of programs that were correctly predicted.\n";
  print "    The predicited file should include 'beam\\d+' in the name \n";
  print "    which indicates the number of attempted transformations to test.\n";
  print "WARNING: this is old code from last year and needs updating\n";
#  print " Example:\n";
#  print "  ./checkeq.pl \n";
  exit(1);
}

open(my $truth,"<",$ARGV[0]);
open(my $pred,"<",$ARGV[1]);
$ARGV[1]=~/beam(\d+)/ || die "Error: $ARGV[1] filename does not include 'beam\\d+'\n";
my $beam=$1;

my $total=0;
my $pos=0;
my $neg=0;
my $exactpos=0;
my $tpos=0;
my $tneg=0;

while (<$truth>) {
    /X (.*) Y (.*) Z (.*)$/ || die "Error: incorrect syntax on input file: $_\n";
    my $progA=$1;
    my $progB=$2;
    my $target=$3;
    $total++;
    if ($target eq "Not_equal") {
        $neg++;
    } else {
        $pos++;
    }
    my $inc=1;
    for (my $i=0; $i < $beam; $i++) {
        my $p=<$pred>;
        chop($p);
        if ($target eq $p) {
            if ($target eq "Not_equal") {
                $tneg+=$inc;
            } else {
                $exactpos+=1;
                $tpos+=$inc;
                print "Exact:\n progA=$progA\n progB=$progB\n target=$target\n";
            }
            $inc = 0;
        } elsif ($target ne "Not_equal") {
            my $predB = GenProgUsingAxioms($progA,"",$p." ");
            if ($predB eq $progB) {
                print "Pos but not exact:\n progA=$progA\n progB=$progB\n target=$target\n pred=$p\n";
                $tpos+=$inc;
                $inc = 0;
            }
        }
    }
}

print "Total = $total; Pos = $pos; True Pos = $tpos, exact = $exactpos\n";
print "               Neg = $neg; True Neg = $tneg\n";

