#!/usr/bin/perl
#
use strict;
use warnings;

if ( scalar @ARGV ) {
  print "Usage: groupcross.pl\n";
  print "    Organizes output from grouptemp into input format suitable for transformer\n";
  exit(1);
}

my %progs=();
while (<>) {
  /, (\d+ f),( \d+ u),( \d+ output),( \d+ input): (.*;) *$/ || next;
  my $group="$1$2$3$4";
  my $prog=$5;
  if (! exists $progs{$group}) {
    @{$progs{$group}} = ("$prog");
  } else {
    push @{$progs{$group}},"$prog";
  }
}

foreach my $group (keys %progs) {
  my @proglist=@{$progs{$group}};
  for (my $i = 0; $i < (scalar @proglist) -1; $i++) {
    for (my $j = $i+1; $j < (scalar @proglist); $j++) {
      print "X $proglist[$i] Y $proglist[$j] Z $group \n";
      print "X $proglist[$j] Y $proglist[$i] Z $group \n";
    }
  }
}
