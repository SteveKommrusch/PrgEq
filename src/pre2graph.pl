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
      ${$L_in}[${$nodes}[$l]] = ${$nodes}[$l+1];
      ${$R_in}[${$nodes}[$l]] = ${$nodes}[$l+$s];
    } else {
      ${$LO_in}[${$nodes}[$l]] = ${$nodes}[$l+1];
    }
    if (${$xform}[$l+2] ne "Null") {
      ${$LL_in}[${$nodes}[$l]] = ${$nodes}[$l+2];
    }
    if (${$xform}[$l+$s+1] ne "Null") {
      ${$RL_in}[${$nodes}[$l]] = ${$nodes}[$l+$s+1];
    }
    if (${$xform}[$l+$s2+1] ne "Null") {
      ${$LR_in}[${$nodes}[$l]] = ${$nodes}[$l+$s2+1];
    }
    if (${$xform}[$l+$s+$s2] ne "Null") {
      ${$RR_in}[${$nodes}[$l]] = ${$nodes}[$l+$s+$s2];
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
            $prog =~s/(\S+) //;
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
            $prog =~s/(\S+)\s*// ;
            if ($1 ne ")") {
                $right = $1;
            }
        }
    
        if ($step < 2) {
            $xform[$pos] = "FAIL"
        } else {
            $xform[$pos] = $op;
            place($left,$pos+1,int($step/2));
            if ($right) {
                place($right,$pos+$step,int($step/2));
            }
        }
    } else {
        # No tree below this node
        $prog =~s/ *$//;
        $xform[$pos] = $prog;
    } 

    return;
}

sub placeprog {
    my $prog = $_[0];
    my $pos = $_[1];
    my $step = $_[2];
    my $stmloc=$pos;
    foreach my $stmA (split /;/,$prog) {
        $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
        my $lhs = $1;
        my $eq = $2;
        my $rhs = $3;
        $xform[$stmloc] = $lhs;
        $xform[$stmloc+1] = $eq;
        place($rhs,$stmloc+2,$step);
        $stmloc+=130;
    }
} 

while (<>) {
    # xform allows 25 statements per program
    @xform = ("Null") x (130 * 25 * 2);
    /X (.* )Y (.* )(Z .*)$/ || die "Bad syntax on input $_";
    my $progA = $1;
    my $progB = $2;
    my $transform = $3;
    placeprog($progA,0,64);
    placeprog($progB,130*25,64);

    my @nodes = ("Null") x 256;
    my %terminals;
  
    my $node=0;
    my $xform_str="";
    for (my $i=0; $i < 130 * 25 * 2; $i++) {
      if ($xform[$i] eq "FAIL") {
        $node= -1;
        last;
      }
      if ($xform[$i] ne "Null") {
        if (exists $terminals{$xform[$i]}) {
            $nodes[$i] = $terminals{$xform[$i]};
        } else {
            if (($xform[$i] =~ /^[mvs]\d/) || ($xform[$i] =~ /^[01I][mvs]/)) {
                $terminals{$xform[$i]}=$node;
            }
            $nodes[$i] = $node;
            $xform_str .= "$xform[$i] ";
            $node++;
        }
      }
    }
    if (($node > 255) || ($node < 0)) {
      next;
    }
    print $xform_str;
    print "<EOT> ";
    # Features:
    #  0- 6: Level of operator in progA
    #  7-13: Level of operator in progB
    #    14: Root node
    # 15-39: Statement flag on equal
    #    40: Output scalar variable
    #    41: Output vector variable
    #    42: Output matrix variable
    #    43: Non-output scalar variable
    #    44: Non-output vector variable
    #    45: Non-output matrix variable
    #    46: Input variable
    my @features = (46) x ($node+1);
    my @L_in = ("") x ($node+1);
    my @R_in = ("") x ($node+1);
    my @LL_in = ("") x ($node+1);
    my @LR_in = ("") x ($node+1);
    my @RL_in = ("") x ($node+1);
    my @RR_in = ("") x ($node+1);
    my @LO_in = ("") x ($node+1);
    my @Strt_in = ("") x ($node+1);
    my @End_in = ("") x ($node+1);
    my @Match_in = ("") x ($node+1);
    my @Nxt_in = ("") x ($node+1);
    my @Assign_in = ("") x ($node+1);
    my @Equals_in = ("") x ($node+1);
    my $stmnum=0;
    $features[$node] = "14";
    while ($stmnum < 25 && ($xform[$stmnum*130] ne "Null" || $xform[$stmnum*130 + 130*25] ne "Null")) {
      if ($xform[$stmnum*130 + 1] ne "Null") {
        $Strt_in[$nodes[$stmnum*130 + 1]] = $node;
      }
      if ($xform[$stmnum*130 + 130*25 + 1] ne "Null") {
        $End_in[$nodes[$stmnum*130 + 130 * 25 + 1]] = $node;
      }
      foreach my $lvl0 ( $stmnum*130 +2 , $stmnum*130 + 130*25 + 2 ) {
        if ($xform[$lvl0] eq "Null") {
          next;
        }
        my $offset = $lvl0 < 130 * 25 ? 0 : 7;
        if ($xform[$lvl0-1] eq "===") {
          if ($xform[$nodes[$lvl0-2]] =~ /s/) {
            $features[$nodes[$lvl0-2]] = 40;
          } elsif ($xform[$nodes[$lvl0-2]] =~ /v/) {
            $features[$nodes[$lvl0-2]] = 41;
          } else {
            $features[$nodes[$lvl0-2]] = 42;
          }
          if ($offset == 0) {
            for (my $j=130 * 25; $j < 130*25*2; $j+=130) {
              if ($xform[$j+1] eq "===" && $nodes[$lvl0-2] == $nodes[$j]) {
                $Match_in[$nodes[$lvl0]] = $nodes[$j+2];
                last;
              }
            }
          }
        } elsif ($features[$nodes[$lvl0-2]] == 46) {
          if ($xform[$nodes[$lvl0-2]] =~ /s/) {
            $features[$nodes[$lvl0-2]] = 43;
          } elsif ($xform[$nodes[$lvl0-2]] =~ /v/) {
            $features[$nodes[$lvl0-2]] = 44;
          } else {
            $features[$nodes[$lvl0-2]] = 45;
          }
        }
        $features[$nodes[$lvl0-1]] = $stmnum + 15;
        $Assign_in[$nodes[$lvl0-1]] = $nodes[$lvl0-2];
        $Equals_in[$nodes[$lvl0-1]] = $nodes[$lvl0];
        if ($stmnum < 24 && $xform[$lvl0+130] ne "Null") {
          $Nxt_in[$nodes[$lvl0-1]] = $nodes[$lvl0+129];
        }
        if ($xform[$lvl0+1] ne "Null") {
          edges($lvl0,64,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
        }
        foreach my $lvl1 ( $lvl0+1 , $lvl0+64 ) {
          if ($xform[$lvl1] eq "Null") {
            next;
          }
          $features[$nodes[$lvl0]] = $offset;
          if ($xform[$lvl1+1] ne "Null") {
            edges($lvl1,32,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
          }
          foreach my $lvl2 ( $lvl1+1 , $lvl1+32 ) {
            if ($xform[$lvl2] eq "Null") {
              next;
            }
            $features[$nodes[$lvl1]] = ($offset+1);
            if ($xform[$lvl2+1] ne "Null") {
              edges($lvl2,16,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
            }
            foreach my $lvl3 ( $lvl2+1 , $lvl2+16 ) {
              if ($xform[$lvl3] eq "Null") {
                next;
              }
              $features[$nodes[$lvl2]] = ($offset+2);
              if ($xform[$lvl3+1] ne "Null") {
                edges($lvl3,8,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
              }
              foreach my $lvl4 ( $lvl3+1 , $lvl3+8 ) {
                if ($xform[$lvl4] eq "Null") {
                  next;
                }
                $features[$nodes[$lvl3]] = ($offset+3);
                if ($xform[$lvl4+1] ne "Null") {
                  edges($lvl4,4,\@xform,\@nodes,\@L_in,\@R_in,\@LO_in,\@LL_in,\@RL_in,\@LR_in,\@RR_in);
                }
                foreach my $lvl5 ( $lvl4+1 , $lvl4+4 ) {
                  if ($xform[$lvl5] eq "Null") {
                    next;
                  }
                  $features[$nodes[$lvl4]] = ($offset+4); 
                  if ($xform[$lvl5+1] ne "Null") {
                    $features[$nodes[$lvl5]] = ($offset+5);
                    if ($xform[$lvl5+2] ne "Null") {
                      $L_in[$nodes[$lvl5]] = $nodes[$lvl5+1];
                      $R_in[$nodes[$lvl5]] = $nodes[$lvl5+2];
                    } else {
                      $LO_in[$nodes[$lvl5]] = $nodes[$lvl5+1];
                    }
                  }
                }
              }
            }
          }
        }
      }
      $stmnum++;
    }
    print join(" ",@features);
    print " <EOT> ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($L_in[$i] ne "") {
        print ("$i $L_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($R_in[$i] ne "") {
        print ("$i $R_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LL_in[$i] ne "") {
        print ("$i $LL_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LR_in[$i] ne "") {
        print ("$i $LR_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($RL_in[$i] ne "") {
        print ("$i $RL_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($RR_in[$i] ne "") {
        print ("$i $RR_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($LO_in[$i] ne "") {
        print ("$i $LO_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Strt_in[$i] ne "") {
        print ("$i $Strt_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($End_in[$i] ne "") {
        print ("$i $End_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Match_in[$i] ne "") {
        print ("$i $Match_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Nxt_in[$i] ne "") {
        print ("$i $Nxt_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Assign_in[$i] ne "") {
        print ("$i $Assign_in[$i] ");
      }
    }
    print ", ";
    for (my $i = 0; $i <= $node; $i++) {
      if ($Equals_in[$i] ne "") {
        print ("$i $Equals_in[$i] ");
      }
    }
    print "X ",$progA,"Y ",$progB, $transform, "\n";
}
