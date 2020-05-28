#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/genProgUsingAxioms.pl";

if ( ! -f $ARGV[2] || ! -f $ARGV[3] ) {
  print "Usage: search.pl beam maxtok src model\n";
  print "    Open source file and search 12 steps to see if model can prove\n";
  print "    programs equal using beam width and up to maxtok for both programs.\n";
  print "  Example: search.pl 5 all_multi_test.txt final-model_step_100000.pt\n";
  exit(1);
}

my $beam=$ARGV[0];
my $maxTokens=$ARGV[1];
open(my $fh_all,"<",$ARGV[2]) || die "open fh_all failed: $!";
my $model=$ARGV[3];

my $pos=0;
my $neg=0;
my $exactpos=0;
my $tpos=0;
my $tneg=0;
my @progAs;
my @progBs;
my @tgt;
my @axpath;
my @axioms;
my %searching;
my @nsrc;
my $progA;
my $progB;
my $legal=0;
my $illegal=0;

my $lnum=0;
while (<$fh_all>) {
  $lnum++;
  /X (.*) Y (.*) Z (.*)$/ || die "Error: incorrect syntax on input file: $_\n";
  $progA=$1;
  $progB=$2;
  $tgt[$lnum]=$3;
  $progAs[$lnum][1][1]=$progA; # Dims are sample,axiom,beam
  $nsrc[$lnum]=1;              # Current number of active beam
  $progBs[$lnum]=$progB;
  $axioms[$lnum][1][1]="";
  $axpath[$lnum]="";           # No proven path yet
  $searching{$lnum.$progA}=1;  # Allows quick equiv check
}
close($fh_all) || die "close fh_all failed: $!";

for (my $axsteps=1; $axsteps < 12; $axsteps++) {
  open(my $fh_raw,">","search_raw$axsteps.txt") || die "open fh_raw failed: $!";
  for (my $i=1; $i <= $lnum; $i++) {
    for (my $j=1; $j <= $nsrc[$i]; $j++) {
      $progA = $progAs[$i][$axsteps][$j];
      print $fh_raw "X $progA Y $progBs[$i] Z Emptyprediction\n";
    }
  }
  close($fh_raw) || die "close fh_raw failed: $!";
#  system "../../src/pre2graph.pl < search_raw$axsteps.txt > search_all$axsteps.txt\n";
  system "perl -ne '/X (.*) Z/ && print \$1.\"\\n\"' search_raw$axsteps.txt > search_src-test$axsteps.txt";
  system "cd \$OpenNMT_py; python translate.py -model \$data_path/$model -src \$data_path/search_src-test$axsteps.txt -beam_size 3 -n_best 3 -gpu 0 -output \$data_path/search_pred$axsteps.txt -dynamic_dict 2>&1 > \$data_path/search_translate$axsteps.out";
  
  open(my $fh_pred,"<","search_pred$axsteps.txt") || die "open fh_pred failed: $!";
  for (my $i=1; $i <= $lnum; $i++) {
    my $new_nsrc=0;
    my @preds;
    my $found=0;
    $progB = $progBs[$i];
    my $numtokB = int(grep { !/[()]/ } split / /,$progB);
    for (my $j=1; $j <= $nsrc[$i]; $j++) {
      $progA=$progAs[$i][$axsteps][$j];
      for (my $k=1; $k <= 3; $k++) {
        my $ln = <$fh_pred> || die "Unexpected end of fh_pred";
        chomp($ln);
        $preds[$j][$k]=$ln;
      }
    }
    # Process predictions prioritizing 'best' predictions for each sample
    for (my $k=1; $k <= 3; $k++) {
      for (my $j=1; $j <= $nsrc[$i] && $new_nsrc < ($beam > 1 ? 2*$beam : $beam) && !$found; $j++) {
        $progA=$progAs[$i][$axsteps][$j];
        my $ln = $preds[$j][$k];
        if ($ln) {
          my $predB = GenProgUsingAxioms($progA,"",$ln." ");
          if (($predB ne $progA) && !($ln=~/[A-Z].*[A-Z]/)) {
            $legal++;
            my $progTmp=$predB;
            $progTmp=~s/[^()]//g;
            while ($progTmp =~s/\)\(//g) {};
            # Only add new programs which fit in maxToken (network size)
            if (!$searching{$i.$predB} && !($predB=~/(TOODEEP|FAILTOMATCH)/) && ($numtokB + int(grep { !/[()]/ } split / /,$predB) < $maxTokens) && length($progTmp)/2 < 7) {
              $new_nsrc++;
              $axioms[$i][$axsteps+1][$new_nsrc] = $axioms[$i][$axsteps][$j]." $ln";
              if ($new_nsrc <= $beam) {
                $searching{$i.$predB}=1;
                $progAs[$i][$axsteps+1][$new_nsrc] = $predB;
              }
              # Check up to twice as many predictions as beam width
              # This guarantees that at all of the 2nd-best guesses of
              # the samples get checked.
              if ($predB eq $progB) {
                # Found path!
                $axpath[$i] = $axioms[$i][$axsteps+1][$new_nsrc];
                $found=1;
                $new_nsrc = 0;   # No need to keep searching
              }
            }
          } else {
            $illegal++;
          }
        }
      }
    }
    $nsrc[$i] = $new_nsrc > $beam ? $beam: $new_nsrc; 
  }
  <$fh_pred> && die "Too many lines in fh_pred";
  close($fh_pred) || die "close fh_pred failed: $!";
}

for (my $i=1; $i <= $lnum; $i++) {
  if ($axpath[$i]) {
    print "FOUND: $progAs[$i][1][1] to $progBs[$i] with $axpath[$i] Target path: $tgt[$i]\n";
  } else {
    for (my $j=1; $j <= 12; $j++) {
        if (! exists $axioms[$i][$j+1][1]) {
            print "FAIL: $progAs[$i][1][1] to $progBs[$i] bestguess after $j steps: $axioms[$i][$j][1] Target path: $tgt[$i]\n";
            last;
        }
    }
  }
}
print "Legal axiom proposals: $legal; Illegal axiom proposals: $illegal\n";
