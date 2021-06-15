#!/usr/bin/perl
#
use strict;
use warnings;

require "../../src/genProgUsingAxioms.pl";

if ( ! -f "xlate.txt" || ! -f "../all_test.txt" || ! -f "train.out" || ($ARGV[0] && $ARGV[0] ne "-v")) {
  print "Usage: xlatechk.pl \n";
  print "    Opens train.out, xlate.txt and all_test.txt and reports results\n";
  exit(1);
}

my $verbose=$ARGV[0];

open(my $tf, "<","train.out") || die "open train.out failed: $!";
open(my $xf, "<","xlate.txt") || die "open xlate.txt failed: $!";
open(my $af, "<","../all_test.txt") || die "open all_test.txt failed: $!";

my $train=0;
my $val=0;
while (<$tf>) {
  /Step 99[89].0\/.* acc: +(\d+\.*\d*);/ && ($train+=$1/5);
  /Step 100000\/.* acc: +(\d+\.*\d*);/ && ($train+=$1/5);
  if ($train > 0 && $val == 0 && /Validation accuracy: +(\d+\.*\d*)/) {
    $val=$1;
  }
}

my $lines=0;
my @src;
my @tgt;
my @xlate;
while (<$af>) {
  /X (.* )Y .* Z (.*\S)\s*$/ || die "Bad syntax: $_";
  $src[$lines] = $1;
  $tgt[$lines] = $2;
  $lines++;
}

my $xlines=0;
while (<$xf>) {
  s/\s+$//;
  $xlate[$xlines] = $_;
  $xlines++;
}

my $beam = int($xlines/$lines);

if ($xlines != $lines * $beam) {
  die "Error in xlines size: lines= $lines, xlines=$xlines\n";
}

my $match=0;
my $legalany=0;
my $legal=0;
my $syntax=0;
for (my $i = 0; $i < $lines; $i++) {
  my $matched=0;
  my $legaled=0;
  for (my $j = $i*$beam; $j < ($i+1)*$beam; $j++) {
    $verbose && print "$src[$i]Z $tgt[$i] out: $xlate[$j] ";
    if ($xlate[$j] =~ /^(stm\d+) ([A-Z][a-z]+)(.*)$/) {
      my $stm=$1;
      my $axiom=$2;
      my $args=$3;
      if (($axiom =~ /^(Swapprev|Deletestm)$/ && $args eq "") ||
          ($axiom =~ /^(Inline|Usevar|Rename)$/ && $args=~/^ [mvs]\d+\s*$/) ||
          ($axiom =~ /^(Newtmp)$/ && $args=~/^ N[lr]* [mvs]\d+\s*$/) ||
          ($axiom =~ /^(Cancel|Noop|Double|Multzero|Multone|Divone|Addzero|Subzero|Commute|Distribleft|Distribright|Factorleft|Factorright|Assocleft|Assocright|Flipleft|Flipright|Transpose)$/ && $args=~/^ N[lr]*\s*$/)) {
        $syntax++;
        $verbose && print "syntax ";
        my $progB = GenProgUsingAxioms($src[$i],"",$xlate[$j]." ");
        if ($progB ne $src[$i]) {
          $legal++;
          if ($legaled == 0) {
            $legalany++;
            $legaled=1;
          }
          $verbose && print "legal ";
          if (($xlate[$j] eq $tgt[$i]) && ($matched==0)) {
            $matched=1;
            $match++;
            $verbose && print "match ";
          }
        }
      }
    }
    $verbose && print "\n";
  }
}

printf "Train  Valid  Syntax  Legal  AnyLgl  Match\n";
printf "%5.1f  %5.1f  %5.1f   %5.1f  %5.1f   %5.1f\n",$train,$val,100*$syntax/$xlines,100*$legal/$xlines,100*$legalany/$lines,100*$match/$lines;

