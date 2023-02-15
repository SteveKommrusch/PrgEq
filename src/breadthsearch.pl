#!/usr/bin/perl
#
use strict;
use warnings;

require "../src/allPossibleAxioms.pl";
require "../src/genProgUsingAxioms.pl";

if ( ! -f $ARGV[2] || ! -d $ARGV[3] ) {
  print "Usage: breadsearch.pl maxax maxtok src dir \n";
  print "    Open source file and search maxax steps to see if model can prove\n";
  print "    programs equal using bread-first search and up to maxtok for both programs.\n";
  print "  Example: search.pl 25 250 all_test_fullaxioms.txt tr_x\n";
  exit(1);
}
my $host=`hostname`;
$host=~s/\n$//;

my $maxAxioms=$ARGV[0];
my $beam=9999999;
my $maxTokens=$ARGV[1];
open(my $fh_all,"<",$ARGV[2]) || die "open fh_all failed: $!";
my $dir=$ARGV[3];

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
my @rare;
my %searching;
my @nsrc;
my @axcnt;
my @syntax;
my @legal;
my @new;
my $progA;
my $progB;
my $foundall=0;
my $newall=0;
my $legal=0;
my $illegal=0;
my $badsyntax=0;

my $lnum=0;
while (<$fh_all>) {
  $lnum++;
  /X (.*) Y (.*) Z (.*)$/ || die "Error: incorrect syntax on input file: $_\n";
  $progA=$1;
  $progB=$2;
  $tgt[$lnum]=$3;
  $progAs[$lnum][1][1]=$progA; # Dims are sample,axiom,beam
  $nsrc[$lnum]=1;              # Current number of active beam
  $axcnt[$lnum]=0;
  $syntax[$lnum]=0;
  $legal[$lnum]=0;
  $new[$lnum]=0;
  $progBs[$lnum]=$progB;
  $axioms[$lnum][1][1]="";
  $axpath[$lnum]="";           # No proven path yet
  $rare[$lnum]="";             # Track rare legal axioms for learning examples
  $searching{$lnum.$progA}=1;  # Allows quick equiv check
}
close($fh_all) || die "close fh_all failed: $!";

for (my $axsteps=1; $axsteps <= $maxAxioms; $axsteps++) {
  print "Starting step $axsteps at ",`date`;
  # system "../../src/pre2graph.pl < search_raw_$host.txt > search_all_$host.txt\n";
  # system "perl -ne '/^(.*) X / && print \$1.\"\\n\"' search_all_$host.txt > search_src-test_$host.txt";
  # system "perl -ne '/X (.*) Z / && print \$1.\"\\n\"' $dir/search_raw_$host.txt > $dir/search_src-test_$host.txt";
  #system "onmt_translate -model $model -src $dir/search_src-test_$host.txt -output $dir/search_pred_$host.txt -gpu 0 -replace_unk -beam_size 5 -n_best 5 -batch_size 4 -verbose > /dev/null 2>&1";
  # open(my $fh_pred,"<","$dir/search_pred_$host.txt") || die "open fh_pred failed: $!";
  
  for (my $i=1; $i <= $lnum; $i++) {
    my $new_nsrc=0;
    my @preds;
    $progB = $progBs[$i];
    my $numtokB = (scalar split /[;() ]+/,$progB);
    for (my $j=1; $j <= $nsrc[$i]; $j++) {
      $progA=$progAs[$i][$axsteps][$j];
      my $progTmp = $progB;
      my $tmpscalar="";
      my $tmpvector="";
      my $tmpmatrix="";
      while ($progTmp=~s/([svm]\d+) *=//) {
        my $tmpv = $1;
        if (($progTmp=~s/$tmpv *=//) ? ($progA=~/$tmpv *=.*$tmpv *=/) : ($progA=~/$tmpv *=/)) {
           # Variable accounted for in progA
        } else {
           ($tmpv =~/^s/) && ($tmpscalar.="$tmpv ");
           ($tmpv =~/^v/) && ($tmpvector.="$tmpv ");
           ($tmpv =~/^m/) && ($tmpmatrix.="$tmpv ");
           while ($progTmp=~s/$tmpv *=//) { }
        }
      }
      $tmpscalar=~s/ +$//;
      $tmpvector=~s/ +$//;
      $tmpmatrix=~s/ +$//;
      my $allAxioms = AllPossibleAxioms($progA,0,"","Scalar:$tmpscalar Vector:$tmpvector Matrix:$tmpmatrix")." stm99 END";
      for (my $k=1; ($k <= 9999999) && ($allAxioms =~/stm.*stm99 END/); $k++) {
        $allAxioms =~s/^\s*(stm\d+ .*?) +stm/stm/;
        my $ln=$1;
        $preds[$j][$k]=$ln;
      }
    }
    # Process predictions prioritizing 'best' predictions for each sample
    for (my $k=1; $k <= 9999999; $k++) {
      # For beam above 2, check up to 5 proposals from neural net
      for (my $j=1; $j <= $nsrc[$i] && $new_nsrc < ($beam > 2 ? 5*$beam : $beam); $j++) {
        my $ln = $preds[$j][$k];
        if (! $ln) {
            last;
        }
        $axcnt[$i]++;
        $progA=$progAs[$i][$axsteps][$j];
        my $stm="";
        my $axiom="";
        my $args="";
        if ($ln =~ /^(stm\d+) ([A-Z][a-z]+)(.*)$/ ) {
          $stm=$1;
          $axiom=$2;
          $args=$3;
        }
        # Syntax check before legality attempt
        if (($axiom =~ /^(Swapprev|Deletestm)$/ && $args eq "") ||
          ($axiom =~ /^(Inline|Usevar|Rename)$/ && $args=~/^ [mvs]\d+\s*$/) ||
          ($axiom =~ /^(Newtmp)$/ && $args=~/^ N[lr]* [mvs]\d+\s*$/) ||
          ($axiom =~ /^(Cancel|Noop|Double|Multzero|Multone|Divone|Addzero|Subzero|Commute|Distribleft|Distribright|Factorleft|Factorright|Assocleft|Assocright|Flipleft|Flipright|Transpose)$/ && $args=~/^ N[lr]*\s*$/)) {
          $syntax[$i]++;
          my $predB = GenProgUsingAxioms($progA,"",$ln." ");
          $predB=~s/\s*$//;
          if (($predB ne $progA) && !($predB=~/FAILTOMATCH/)) {
            $legal[$i]++;
            $legal++;
            my $progTmp=$predB;
            $progTmp=~s/[^()]//g;
            while ($progTmp =~s/\)\(//g) {};
            # Only add new programs which fit in maxToken (network size)
            # And fewer than 21 statements and depth less than 7
            if (!$searching{$i.$predB} && !($predB=~/TOODEEP/) && ($numtokB + (scalar split /[;() ]+/,$predB) < $maxTokens) && int(grep { /=/ } split / /,$predB) < 21 && length($progTmp)/2 < 6) {
              $new_nsrc++;
              $newall++;
              $new[$i]++;
              $axioms[$i][$axsteps+1][$new_nsrc] = $axioms[$i][$axsteps][$j]." $ln";
              if ($new_nsrc <= $beam) {
                $searching{$i.$predB}=1;
                $progAs[$i][$axsteps+1][$new_nsrc] = $predB;
              } else {
                # Track rare legal token use as 4th choice or later after
                #  beam is filled for later learning (hindsight learning)
                if (($k > 3) 
                    && (! $rare[$i] || (($ln=~/ N[lr][lr][lr][lr]/) && ! ($rare[$i]=~/ N[lr][lr][lr][lr]/)))
                    && (($ln=~/ N[lr][lr][lr][lr]/) ||
                        ($ln=~/Newtmp/) ||
                        ($ln=~/Factor/) ||
                        ($ln=~/stm20/) ||
                        ($ln=~/stm19/))) {
                  $rare[$i] = "X $progA Y $predB Z $ln ";
                }
              }
              if ($predB eq $progB) {
                # Found path!
                $axpath[$i] = $axioms[$i][$axsteps+1][$new_nsrc];
                $foundall++;
              }
            }
          } else {
            $illegal++;
          }
        } else {
          $badsyntax++;
        }
      }
    }
    $nsrc[$i] = $new_nsrc > $beam ? $beam: $new_nsrc; 
  }
  print "Axiom step $axsteps done. Found $foundall proofs. Legal axiom proposals: $legal; New programs: $newall Bad syntax: $badsyntax; Illegal axiom proposals: $illegal\n";
  select()->flush();
}

for (my $i=1; $i <= $lnum; $i++) {
  if ($axpath[$i]) {
    print "FOUND: $progAs[$i][1][1] to $progBs[$i] with $axpath[$i] Target path: $tgt[$i]Axioms Evaluated: $axcnt[$i], syntax: $syntax[$i], legal: $legal[$i], new: $new[$i]\n";
  } else {
    for (my $j=1; $j <= $maxAxioms + 1; $j++) {
        if (! exists $axioms[$i][$j+1][1]) {
            if ($rare[$i]) {
              print "RARE: $rare[$i]\n";
            }
            print "FAIL: $progAs[$i][1][1] to $progBs[$i] bestguess after $j steps: $axioms[$i][$j][1] Target path: $tgt[$i]Axioms Evaluated: $axcnt[$i], syntax: $syntax[$i], legal: $legal[$i], new: $new[$i]\n";
            last;
        }
    }
  }
}
print "Search done. Found $foundall proofs. Legal axiom proposals: $legal; New programs: $newall Bad syntax: $badsyntax; Illegal axiom proposals: $illegal. ",`date`;
