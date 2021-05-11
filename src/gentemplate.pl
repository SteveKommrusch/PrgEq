#!/usr/bin/perl
#
use strict;
use warnings;

if ($ARGV[0]) {
  print "Usage: gentemplate.pl \n";
  print "  Process function samples from GitHub in Full directory.\n";
  print "  Find interesting code blocks and create templates.\n";
  print " Example:\n";
  print "  ./gentemplate.pl \n";
  exit(1);
}

sub ProcessBlock {
  my $x=$_[0];

  my %vars=("0"=>"0s","1"=>"1s","2"=>"2s","3"=>"3s","4"=>"4s","pow"=>"pow");
  my $s_in=0;
  my $s_out=0;
  my $s_tmp=0;
  my $s_fn=0;
  my $new="";

  $x && print "DBG orig:$x\n";
  if ($x=~/= .*=/ && (($x=~/= [^=;,]*[^=;,(] (\*|\/|pow) \w/) || ($x=~/ (\*|\/)= \w/)) && (($x=~/= [^=;,]*[^=;,(] (\+|\-) \w/) || ($x=~/ (\+|\-)= \w/))) {
    $x=~s/ \( [^\)\(]+ \* \) / /g;
    $x=~s/\·/_elem_/g;
    $x=~s/\&/*/g;
    $x=~s/\|/+/g;
    $x=~s/([=\(+\-\*\/,]) \* \(/$1 (/g;
    $x=~s/([=\(+\-\*\/,]) \* /$1 val_/g;
    $x=~s/ ([0-9]+)[0-9.]*[eE][+\-]*\d+f* / 9$1 /g;
    $x=~s/(\d)\.0*f* /$1 /g;
    $x=~s/\.[0-9]+f* /9 /g;
    $x=~s/ -> /_ref_/g;
    $x=~s/ \. /_elem_/g;
    $x=~s/ \( \S+ \w+ \) / /g;
    $x=~s/ \( \) / /g;
    $x=~s/ \( [^\(\)]+ \)( [\(\w])/$1/g;
    while ($x=~s/\[ ([^\] ]+) /[ $1_/g) {};
    $x=~s/.\][^\[]+\] / /g;
    $x=~s/.\]//g;
    while ($x=~s/.\[./_idx_/g) {};
    $x=~s/\(_/array_/g;
    $x=~s/_[\(\)\+\-\*\/\^\!,]+//g;
    $x=~s/\)_\S+ /) /g;
    $x=~s/; (\S+) (.)= /; $1 = $1 $2 /g;
    if (($x=~/= [^=;]*[^=;,(] (\*|\/|pow) \w/) && ($x=~/= [^=;]*[^=;,(] (\+|\-) \w/)) {
      print "DBG prep:$x\n";
      my $tmp=$x;
      while ($tmp=~s/^ (\S+) = ([^;=]+ );//) {
        my $var=$1;
        my $rhs=$2;
        my $newrhs="";
        while ($rhs =~ s/^(\S+) //) {
          my $tok=$1;
          if ($tok =~/^[\w\d]+$/) {
            if (! exists $vars{$tok}) {
              if ($rhs=~/^\(/) {
                $s_fn++;
                $vars{$tok} = "f$s_fn";
              } else {
                $s_in++;
                $vars{$tok} = "i$s_in";
              }
            }
            $newrhs .= "$vars{$tok} ";
          } else {
            $newrhs .= "$tok ";
          }
        }
        if ($tmp=~/=[^=;]* \Q$var\E /) {
          $s_tmp++;
          $vars{$var} = "t$s_tmp";
          $new.=" $vars{$var} = $newrhs;";
        } else {
          if (!$s_tmp) {
            # Ignore assignments until we see one that's used later
            %vars=("0"=>"0s","1"=>"1s","2"=>"2s","3"=>"3s","4"=>"4s","pow"=>"pow");
            $s_out=0;
            $s_fn=0;
            $s_in=0;
            $new="";
          } elsif (($newrhs=~/t\d+ /) || ($newrhs=~/i\d+.* i\d+ /)) {
            # Don't create outputs that don't use at least a temp or 2 inputs
            $s_out++;
            $vars{$var} = "o$s_out";
            $new.=" $vars{$var} = $newrhs;";
          }
        }
      }
      ($new =~ /^ t1 = .*= .* t\d+ /) && print "$new\n";
    }
  }
}

open(my $funcs,'-|','gunzip -cd BugFixNoDup_201?_??.tgt.txt.gz | egrep "[+\-\*\/ ]= [^{}]+ ; [^{}]+[+\-\*\/ ]= [^{}]+[+\-\*\/ ]= "') or die "Couldn't open pipe: $!";
while (<$funcs>) {
  s/\#.*? \/\/<S2SV>//g;
  s/ \/\/<S2SV>//g;
  s/ \+\+ / /g;
  s/ \-\- / /g;
  s/, (\w+ = )/; $1/g;
  my $block="";
  s/^[^{]+ \{//;
  while (s/^([^;}]+).//) {
    my $stm=$1;
    if ($stm=~/(<<|>>)/) {
       $stm=~s/ << 0 / * 1 /g;
       $stm=~s/ << 1 / * 2 /g;
       $stm=~s/ << 2 / * 4 /g;
       $stm=~s/ << 3 / * pow ( 2 , 3 ) /g;
       $stm=~s/ << 4 / * pow ( 2 , 4 ) /g;
       $stm=~s/ >> 0 / \/ 1 /g;
       $stm=~s/ >> 1 / \/ 2 /g;
       $stm=~s/ >> 2 / \/ 4 /g;
       $stm=~s/ >> 3 / \/ pow ( 2 , 3 ) /g;
       $stm=~s/ >> 4 / \/ pow ( 2 , 4 ) /g;
    }
    $stm=~s/^return ([^{};]+)/return_value = $1/;
    if ($stm=~s/^[^{]+ \{//) {
      ProcessBlock($block);
      $block="";
    }
    if (! ($stm=~/[+\-\*\/ ]= /) ||
        $stm=~/['`"#]/ || 
        $stm=~/ (\{|\}|\%|<<|>>|NULL|for|if|goto|while|<|>|==|\?) / ||
        $stm=~/,[^()]+,/ || $stm=~/,[^()]+\([^()]+\)[^()]+,/) {
      ProcessBlock($block);
      $block="";
    } else {
      $stm=~s/ \+\+ //g;
      $stm=~s/ \-\- //g;
      $stm=~s/\( [^;=()]+ \) ([\+\-\*\/]*)= /$1=/;
      $stm=~s/^[^=\[\]]*( \w)/$1/;
      $stm=~s/ \* \* / * /g;
      $stm=~s/ \( \* ([^\)\(]+) \) / val_$1 /g;
      $stm=~s/^[^)=]*\)//;
      $block.=$stm.";";
    }
    if (20 < scalar split /=/,$block) {
      ProcessBlock($block);
      $block="";
    }
  }
  ProcessBlock($block);
}

