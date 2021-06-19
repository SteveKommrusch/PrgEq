#!/usr/bin/perl
#
use strict;
use warnings;

if ( scalar @ARGV ) {
  print "Usage: grouptemp.pl\n";
  print "    Canonicalizes register names in template input file and print out with input/output counts\n";
  exit(1);
}

while (<>) {
  /Y(.*)Z Reuse Str Cse Template $/ || next;
  my $prog=$1;
  # Tmp numbering starts 1 below output and counts down
  my $tmp=29;
  my $in=0;
  my $f=0;
  my $u=0;
  my $out1="";
  my $out2="";
  my %mapping;
  if ($prog=~/ (\S+) ===.* (\S+) ===/) {
    $out1=$1; 
    $out2=$2;
    $prog=~s/ $out1/ out1/g;
    $prog=~s/ $out2/ out2/g;
    $tmp=28;
  } else { 
    $prog=~/ (\S+) ===/ || die "No output found in $prog!";
    $out1=$1; 
    $prog=~s/ $out1/ out1/g;
  }
  for (my $i=1; $i<=30; $i++) {
    my $id = sprintf "%02d",$i;
    $prog=~s/ s$id/ tmp$id/g;
  }
  for (my $i=1; $i<=5; $i++) {
    $prog=~s/ f${i}s/ f2in$i/g;
    $prog=~s/ u${i}s/ u1in$i/g;
  }
  # Put assigned variable at end for easier input check
  my $reorder=$prog;
  while ($reorder=~s/ (\S+) (=+) ([^;:]*) ;/ $3 $2 $1 :/) { };
  my $assign=0;
  foreach my $tok (split / /,$reorder) {
    $tok || next;
    ($tok eq ":") && ($assign=0);
    ($tok=~/=/) && ($assign=1);
    if (($tok=~/^tmp\d/) && (! exists $mapping{$tok})) {
      if ($assign) {
        $mapping{$tok} = sprintf "s%02d",$tmp;
        $tmp--;
      } else {
        $in++;
        $mapping{$tok} = sprintf "s%02d",$in;
      }
    }
    if (($tok=~/^f2in\d/) && (! exists $mapping{$tok})) {
      $f++;
      $mapping{$tok} = "f${f}s";
    }
    if (($tok=~/^u1in\d/) && (! exists $mapping{$tok})) {
      $u++;
      $mapping{$tok} = "u${u}s";
    }
  }
  foreach my $var (keys %mapping) {
    $prog=~s/ $var/ $mapping{$var}/g;
  }
  $prog=~s/ out1/ s30/g;
  $prog=~s/ out2/ s29/g;
  my $nodes=(scalar split /[;() ]+/,$prog)-1;
  ($in > $tmp ) && die "Too many variables: $prog";
  if ($out2) {
    print "$nodes nodes, $f f, $u u, 2 output, $in input:$prog\n";
  } else {
    print "$nodes nodes, $f f, $u u, 1 output, $in input:$prog\n";
  }
}

