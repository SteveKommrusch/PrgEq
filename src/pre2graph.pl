#!/usr/bin/perl
#
use strict;
use warnings;

if ($ARGV[0]) {
  print "Usage: pre2graph.pl\n";
  print "  Transform src sequence to graph input structure.\n";
  exit(1);
}

my @xform;
my $nodes;

sub edges {
    my $l     = $_[0];
    my $s     = $_[1];
    my $xform = $_[2];
    my $nodes = $_[3];
    my $L_in  = $_[4];
    my $R_in  = $_[5];
    my $LO_in = $_[6];
    my $LL_in = $_[7];
    my $RL_in = $_[8];
    my $LR_in = $_[9];
    my $RR_in = $_[10];

    my $s2 = int($s/2);

    if (${$xform}[$l+$s] ne "Null") {
      ${$L_in}[${$nodes}[$l]] = ${$nodes}[$l+2]." ";
      ${$R_in}[${$nodes}[$l]] = ${$nodes}[$l+$s]." ";
    } else {
      ${$LO_in}[${$nodes}[$l]] = ${$nodes}[$l+2]." ";
    }
    if (${$xform}[$l+4] ne "Null") {
      ${$LL_in}[${$nodes}[$l]] = ${$nodes}[$l+4]." ";
    }
    if (${$xform}[$l+$s+2] ne "Null") {
      ${$RL_in}[${$nodes}[$l]] = ${$nodes}[$l+$s+2]." ";
    }
    if (${$xform}[$l+$s2+2] ne "Null") {
      ${$LR_in}[${$nodes}[$l]] = ${$nodes}[$l+$s2+2]." ";
    }
    if (${$xform}[$l+$s+$s2] ne "Null") {
      ${$RR_in}[${$nodes}[$l]] = ${$nodes}[$l+$s+$s2]." ";
    }
} 
 
sub place {
    my $prog = $_[0];
    my $pos = $_[1];
    my $step = $_[2];

    if ($xform[$pos] ne "Null") {
        $xform[$pos] = "FAIL";
        return;
    }

    if ($prog =~s/^\( (..) //) {
        my $op = $1;
        my $left;
        my $right = "";
        my $in;
    
        if ($prog =~s/^(\([^()]*)//) {
            $in=1;
            $left = $1;
            while ($in >0) {
                if ($prog =~s/^([^()]*)//) {
                    $left .= $1;
                }
                if ($prog =~s/^(\([^()]*)//) {
                    $in+=1;
                    $left .= $1;
                }
                if ($prog =~s/^(\)\s+)//) {
                    $in-=1;
                    $left .= $1;
                }
            }
        } else {
            $prog =~s/(.) //;
            $left = $1;
        }

        if ($prog =~s/^(\([^()]*)//) {
            $in=1;
            $right = $1;
            while ($in >0) {
                if ($prog =~s/^([^()]*)//) {
                    $right .= $1;
                }
                if ($prog =~s/^(\([^()]*)//) {
                    $in+=1;
                    $right .= $1;
                }
                if ($prog =~s/^(\)\s+)//) {
                    $in-=1;
                    $right .= $1;
                }
            }
        } else {
            $prog =~s/(.) // ;
            if ($1 ne ")") {
                $right = $1;
            }
        }
    
        if ($step < 4) {
            $xform[$pos] = "FAIL"
        } else {
            $xform[$pos] = $op;
            $nodes++;
            place($left,$pos+2,int($step/2));
            if ($right) {
                place($right,$pos+$step,int($step/2));
            }
        }
    } else {
        # No tree below this node
        $prog =~s/ *$//;
        $xform[$pos] = $prog;
        $nodes++;
    } 

    return;
}

while (<>) {
    @xform = ("Null") x 256;
    $nodes=0;
    /X (.* )Y (.* )(Z .*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $progB = $2;
    my $transform = $3;
    place($progA,0,128);
    place($progB,1,128);
    my $merged = join(" ",@xform);
    die "Nodes > 100" if $nodes > 100;
    die "Programs too deep: X $progA Y $progB $transform with $merged" if $merged =~/FAIL/;
    $_ = $merged;

    @xform = ("Null") x 256;
    my @nodes = ("Null") x 256;
  
    my $i = 0;
    my $node=0;
    while (s/^(\S+)\s*//){
      if ($1 ne "Null") {
        $xform[$i] = $1;
        $nodes[$i] = $node;
        print "$1 ";
        $node++;
      }
      $i++;
    }
    print "<EOT> ";
    my @features = ("<unk> ") x ($node+1);
    my @L_in = ("") x ($node+1);
    my @R_in = ("") x ($node+1);
    my @LL_in = ("") x ($node+1);
    my @LR_in = ("") x ($node+1);
    my @RL_in = ("") x ($node+1);
    my @RR_in = ("") x ($node+1);
    my @LO_in = ("") x ($node+1);
    my @Strt_in = ("") x ($node+1);
    my @End_in = ("") x ($node+1);
    $features[$node] = "14 ";
    foreach my $lvl0 ( 0 , 1 ) {
      $features[$nodes[$lvl0]] = $lvl0." ";
      if ($xform[$lvl0+2] ne "Null") {
        edges($lvl0,128,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
      }
      foreach my $lvl1 ( $lvl0+2 , $lvl0+128 ) {
        if ($xform[$lvl1] eq "Null") {
          next;
        }
        $features[$nodes[$lvl1]] = ($lvl0+2)." ";
        if ($xform[$lvl1+2] ne "Null") {
          edges($lvl1,64,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
        }
        foreach my $lvl2 ( $lvl1+2 , $lvl1+64 ) {
          if ($xform[$lvl2] eq "Null") {
            next;
          }
          $features[$nodes[$lvl2]] = ($lvl0+4)." ";
          if ($xform[$lvl2+2] ne "Null") {
            edges($lvl2,32,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
          }
          foreach my $lvl3 ( $lvl2+2 , $lvl2+32 ) {
            if ($xform[$lvl3] eq "Null") {
              next;
            }
            $features[$nodes[$lvl3]] = ($lvl0+6)." ";
            if ($xform[$lvl3+2] ne "Null") {
              edges($lvl3,16,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
            }
            foreach my $lvl4 ( $lvl3+2 , $lvl3+16 ) {
              if ($xform[$lvl4] eq "Null") {
                next;
              }
              $features[$nodes[$lvl4]] = ($lvl0+8)." ";
              if ($xform[$lvl4+2] ne "Null") {
                edges($lvl4,8,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
              }
              foreach my $lvl5 ( $lvl4+2 , $lvl4+8 ) {
                if ($xform[$lvl5] eq "Null") {
                  next;
                }
                $features[$nodes[$lvl5]] = ($lvl0+10)." ";
                if ($xform[$lvl5+2] ne "Null") {
                  $features[$nodes[$lvl5+2]] = ($lvl0+12)." ";
                  if ($xform[$lvl5+4] ne "Null") {
                    $features[$nodes[$lvl5+4]] = ($lvl0+12)." ";
                    $L_in[$nodes[$lvl5]] = $nodes[$lvl5+2]." ";
                    $R_in[$nodes[$lvl5]] = $nodes[$lvl5+4]." ";
                  } else {
                    $LO_in[$nodes[$lvl5]] = $nodes[$lvl5+2]." ";
                  }
                }
              }
            }
          }
        }
      }
    }
    print join("",@features);
    print "<EOT> ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($L_in[$i] ne "") {
        print ("$i $L_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($R_in[$i] ne "") {
        print ("$i $R_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LL_in[$i] ne "") {
        print ("$i $LL_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LR_in[$i] ne "") {
        print ("$i $LR_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($RL_in[$i] ne "") {
        print ("$i $RL_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($RR_in[$i] ne "") {
        print ("$i $RR_in[$i]");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LO_in[$i] ne "") {
        print ("$i $LO_in[$i]");
      }
    }
    print ", ";
    $Strt_in[$node]="0 ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Strt_in[$i] ne "") {
        print ("$i $Strt_in[$i]");
      }
    }
    print ", ";
    $End_in[$node]="1 ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($End_in[$i] ne "") {
        print ("$i $End_in[$i]");
      }
    }
    print "X ",$progA,"Y ",$progB, $transform, "\n";
}
