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
my $maxTokens;
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

for ($axsteps=1; $axsteps < 12; $axsteps++) {
  open(my $fh_raw,">","PrgEq_search_raw.txt") || die "open fh_raw failed: $!";
  for ($i=1; $i <= $lnum; $i++) {
    for ($j=1; $j <= $nsrc[$lnum]; $j++) {
      $progA = @src[$i][$axsteps][$j];
      print $fh_raw "X $progA Y $progBs[$i] Z Emptyprediction\n";
    }
  }
  close($fh_raw) || die "close fh_raw failed: $!";
  system "pre2graph.pl < PrgEq_search_raw.txt > PrgEq_search_all$axsteps.txt\n";
  system "perl -ne '/^(.*) X / && print \\$1' PrgEq_search_all$axsteps.txt > src-test$axsteps.txt"
  system "cd \$OpenNMT_py; python translate.py -model \$data_path/$model -src \$data_path/src-test$axsteps.txt -beam_size 3 -n_best 3 -gpu 0 -output \$data_path/pred-test_beam$axsteps.txt -dynamic_dict 2>&1 > \$data_path/translate$axsteps.out";
  
  open(my $fh_pred,"<","pred-test_beam$axsteps.txt") || die "open fh_pred failed: $!";
  for ($i=1; $i <= $lnum; $i++) {
    my $new_nsrc=0;
    my @preds;
    my $found=0;
    $progB = $progBs[$i];
    my $numtokB = int(grep { !/[()]/ } split / /,$progB);
    for ($j=1; $j <= $nsrc[$i]; $j++) {
      $progA=$progAs[$i][$axiom][$j];
      for ($k=1; $k <= 3; $k++) {
        my $ln = <$fh_pred> || die "Unexpected end of fh_pred";
        chomp($ln);
        $preds[$j][$k]=$ln;
      }
    }
    # Process predictions prioritizing 'best' predictions for each sample
    for ($k=1; $k <= 3; $k++) {
      for ($j=1; $j <= $nsrc[$i] && $new_nsrc <= $beam +1 && !$found; $j++) {
        $progA=$progAs[$i][$axiom][$j];
        my $ln = $preds[$j][$k];
        if ($ln) {
          $predB = GenProgUsingAxioms($progA,"",$ln." ");
          if ($predB ne $progA && ! $ln =~ /[A-Z].*[A-Z]/) {
            $legal++;
            # Only add new programs which fit in maxToken (network size)
            if (!$searching[$i.$predB] && ($numtokB +  int(grep { !/[()]/ } split / /,$predB) < $maxTokens)) {
              $new_nsrc++;
              $axioms[$i][$axioms+1][$new_nsrc] = $axioms[$i][$axioms][$j]." $ln";
              if ($new_nsrc <= $beam) {
                $searching[$i.$predB]=1
                $progAs[$i][$axioms+1][$new_nsrc] = $predB;
              }
              # Beyond beam width, check one extra axiom for correctness
              # (This guarantees that at least 1 of the 2nd-best guesses of
              # at least one sample gets checked).
              if ($predB eq $progB) {
                # Found path!
                $axpath[$i] = $axioms[$i][$axioms+1][$new_nsrc];
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

for ($i=1; $i <= $lnum; $i++) {
  if ($axpath[$i]) {
    print "FOUND: $progAs[$i][1][1] to $progBs[$i] with $axpath[$i] in $axiom steps. Target path: $tgt[$i]\n";
  } else {
    # FIXME: Sometimes a program may fail to find path before 12 attempts (too many
    # duplicates caused axiom path to deadend)
    print "FAIL: $progAs[$i][1][1] to $progBs[$i] bestguess: $axioms[$i][12][1] Target path: $tgt[$i]\n";
  }
}
