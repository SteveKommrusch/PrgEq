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
  $_=$_[0];

  my %vars=("0"=>"0s","1"=>"1s","2"=>"2s","3"=>"3s","4"=>"4s","pow"=>"pow");
  my $s_in=0;
  my $s_out=0;
  my $s_tmp=0;
  my $s_fn=0;
  my $new="";

  $_ && print "DBG orig:$_\n";
  if (/=.*=.*=/ && (/= [^=;,]*[^=;,(] (\*|\/) \w/ || / (\*|\/)= \w/)) {
    s/ \( [^\)\(]+ \* \) / /g;
    while (s/\[ ([^\] ]+) /[ $1_/g) {};
    s/ \[ /_idx_/g;
    s/\.0+f* / /g;
    s/\.[0-9]+f* /9 /g;
    s/.\] / /g;
    s/ -> /_ref_/g;
    s/ \. /_elem_/g;
    s/([=\(+\-\*\/,]) \* \(/$1 (/g;
    s/([=\(+\-\*\/,]) \* /$1 val_/g;
    s/ \( \S+ \w+ \) / /g;
    s/ \( \) / /g;
    s/ \( [^\(\)]+ \)( [\(\w])/$1/g;
    s/; (\S+) (.)= / $1 = $1 $2 /g;
    if (/= [^=;]*[^=;,(] (\*|\/) \w/) {
      print "DBG prep:$_\n";
      my $tmp=$_;
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
          } elsif (($newrhs=~/ t\d+ /) || ($newrhs=~/ i\d+.* i\d+ /)) {
            # Don't create outputs that don't use at least a temp or 2 inputs
            $s_out++;
            $vars{$var} = "o$s_out";
            $new.=" $vars{$var} = $newrhs;";
          }
        }
      }
      ($new =~ /=.*=/) && print "$new\n";
    }
  }
}

open(my $funcs,'-|','gunzip -cd BugFixNoDup_201?_??.tgt.txt.gz | egrep "[+\-\*\/ ]= [^{}]+ ; [^{}]+[+\-\*\/ ]= [^{}]+[+\-\*\/ ]= "') or die "Couldn't open pipe: $!";
while (<$funcs>) {
  s/ \/\/<S2SV>//g;
  my $block="";
  s/^[^{]+ \{//;
  while (s/^([^;}]+).//) {
    my $stm=$1;
    if ($stm=~/^( return [^{};]+)/) {
      ProcessBlock($block.$1.";");
      $block="";
    }
    if ($stm=~s/^[^{]+ \{//) {
      ProcessBlock($block);
      $block="";
    }
    if (! ($stm=~/[+\-\*\/ ]= /) ||
        $stm=~/['`"#]/ || 
        $stm=~/ (\{|\}|\&|\%|<<|>>|NULL|for|if|goto|while|<|>|==|\?) / ||
        $stm=~/,[^()]+,/ || $stm=~/,[^()]+\([^()]+\)[^()]+,/) {
      ProcessBlock($block);
      $block="";
    } else {
      $stm=~s/^[^=\[\]]*( \w)/$1/;
      $stm=~s/^[^)=]*\)//;
      $block.=$stm.";";
    }
  }
}

