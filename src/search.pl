#!/usr/bin/perl
#
use strict;
use warnings;

if ( ! -f $ARGV[1] || ! -f $ARGV[2] ) {
  print "Usage: search.pl beam src model\n";
  print "    Open source file and search 12 steps to see if model can prove\n";
  print "    programs equal using beam width\n";
  print "  Example: search.pl 5 all_multi_test.txt final-model_step_100000.pt\n";
  exit(1);
}

my $beam=$ARGV[0];
open(my $fh_all,"<",$ARGV[1]) || die "open fh_all failed: $!";
my $model=$ARGV[2];

my $transform="";

sub GenerateProgBfromProgA {
    my $progA = $_[0];
    my $path = $_[1];

    $progA =~s/^\((..) // || return $progA;
    my $op = $1;
    my $leftop="";
    my $rightop="";
    my $left="";
    my $right="";
    my $leftleft="";
    my $leftright="";
    my $rightleft="";
    my $rightright="";
    my $newop="";
    my $newleft="";
    my $newright="";
    my $in;

    if ($progA =~s/^\((..) //) {
        $in=1;
        $left = "(".$1." ";
        $leftop = $1;
        my $leftdone=0;
        while ($in >0) {
            if ($progA =~s/^(\s*)([^()])(\s*)//) {
                $left .= $1.$2.$3;
                if ($leftdone) {
                    if ($in == 1) {
                        $leftright .= $2;
                    } else {
                        $leftright .= $1.$2.$3;
                    }
                } else {
                    if ($in == 1) {
                        $leftleft .= $2;
                        $leftdone=1;
                    } else {
                        $leftleft .= $1.$2.$3;
                    }
                }
            }
            if ($progA =~s/^(\([^()]*)//) {
                $in+=1;
                $left .= $1;
                if ($in == 2) {
                    if ($leftdone) {
                        $leftright = $1;
                    } else {
                        $leftleft = $1;
                    }
                } else {
                    if ($leftdone) {
                        $leftright .= $1;
                    } else {
                        $leftleft .= $1;
                    }
                }
            }
            if ($progA =~s/^\)//) {
                $in-=1;
                $left .= ")";
                if ($in > 0) {
                    if ($leftdone) {
                        $leftright .= ")";
                    } else {
                        $leftleft .= ")";
                        if ($in == 1) {
                            $leftdone=1;
                        }
                    }
                }
            }
        }
    } else {
        $progA =~s/^(.)\s*//;
        $left = $1;
    }

    if ($progA =~s/^\s*\((..) //) {
        $in=1;
        $right = "(".$1." ";
        $rightop = $1;
        my $leftdone=0;
        while ($in >0) {
            if ($progA =~s/^(\s*)([^()])(\s*)//) {
                $right .= $1.$2.$3;
                if ($leftdone) {
                    if ($in == 1) {
                        $rightright .= $2;
                    } else {
                        $rightright .= $1.$2.$3;
                    }
                } else {
                    if ($in == 1) {
                        $rightleft .= $2;
                        $leftdone=1;
                    } else {
                        $rightleft .= $1.$2.$3;
                    }
                }
            }
            if ($progA =~s/^(\([^()]*)//) {
                $in+=1;
                $right .= $1;
                if ($in == 2) {
                    if ($leftdone) {
                        $rightright = $1;
                    } else {
                        $rightleft = $1;
                    }
                } else {
                    if ($leftdone) {
                        $rightright .= $1;
                    } else {
                        $rightleft .= $1;
                    }
                }
            }
            if ($progA =~s/^\)//) {
                $in-=1;
                $right .= ")";
                if ($in > 0) {
                    if ($leftdone) {
                        $rightright .= ")";
                    } else {
                        $rightleft .= ")";
                        if ($in == 1) {
                            $leftdone=1;
                        }
                    }
                }
            }
        }
    } else {
        $progA =~s/^\s*(\S)\s*// ;
        if ($1 ne ")") {
            $right = $1;
        }
    }

    if (($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $transform =~s/^${path}left Cancel //) {
        if ($leftop eq "-s") {
            return GenerateProgBfromProgA("($op 0 $right)",$path);
        } else {
            return GenerateProgBfromProgA("($op 1 $right)",$path);
        }
    }

    if (($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $transform =~s/^${path}right Cancel //) {
        if ($rightop eq "-s") {
            return GenerateProgBfromProgA("($op $left 0)",$path);
        } else {
            return GenerateProgBfromProgA("($op $left 1)",$path);
        }
    }

    if (($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $transform =~s/^${path}left Cancel //) {
        if ($leftop eq "-m") {
            return GenerateProgBfromProgA("($op O $right)",$path);
        } else {
            return GenerateProgBfromProgA("($op o $right)",$path);
        }
    }

    if (($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $transform =~s/^${path}right Cancel //) {
        if ($rightop eq "-m") {
            return GenerateProgBfromProgA("($op $left O)",$path);
        } else {
            return GenerateProgBfromProgA("($op $left o)",$path);
        }
    }

    if ((($op eq "+s" && ($left eq "0" || $right eq "0")) ||
         ($op eq "-s" && $right eq "0") ||
         ($op eq "*s" && ($left eq "1" || $right eq "1")) ||
         ($op eq "/s" && $right eq "1")) && $transform =~s/^${path}Noop //) {
        if ($left eq "0" || $left eq "1") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if ((($op eq "+m" && ($left eq "O" || $right eq "O")) ||
         ($op eq "-m" && $right eq "O")) && $transform =~s/^${path}Noop //) {
        if ($left eq "O") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if ($op eq "*m" && (($left eq "I" && ($rightop =~ /.m/ || $right =~ /^[A-Z]/)) || ($right eq "I" && ($leftop =~ /.m/ || $left =~ /^[A-Z]/))) && $transform =~s/^${path}Noop //) {
        if ($left eq "I") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if ((($op eq "+v" && ($left eq "o" || $right eq "o")) ||
         ($op eq "-v" && $right eq "o")) && $transform =~s/^${path}Noop //) {
        if ($left eq "o") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if (($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^${path}Distribleft //) {
        $newleft = GenerateProgBfromProgA("($op $leftleft $right)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        $leftop =~s/.$/m/;
        return "($leftop $newleft $newright)";
    }

    if (($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^${path}Distribright //) {
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $left $rightright)",$path."right ");
        $rightop =~s/.$/m/;
        return "($rightop $newleft $newright)";
    }

    if (($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^${path}Distribleft //) {
        $newleft = GenerateProgBfromProgA("($op $leftleft $right)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "($leftop $newleft $newright)";
    }

    if (($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^${path}Distribright //) {
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $left $rightright)",$path."right ");
        if ($op =~/.v/) {$rightop =~s/.$/v/}
        return "($rightop $newleft $newright)";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./) && $transform =~s/^${path}Factorleft //) {
        my $typematch=0;
        if (($rightright =~/^\( .s / || $rightright =~/^[a-j01]/) &&
            ($leftright =~/^\( .s / || $leftright =~/^[a-j01]/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightright =~/^\( .m / || $rightright =~/^[A-Z]/) &&
            ($leftright =~/^\( .m / || $leftright =~/^[A-Z]/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightright =~/^\( .v / || $rightright =~/^[o-z]/) &&
            ($leftright =~/^\( .v / || $leftright =~/^[o-z]/)) {
            $typematch=1;
            $op =~s/.$/v/;
        }
        if ($typematch) {
            $newleft = GenerateProgBfromProgA("$leftleft",$path."left ");
            $newright= GenerateProgBfromProgA("($op $leftright $rightright)",$path."right ");
            return "($leftop $newleft $newright)";
        } else {
            return "<PROGBFAILTOMATCH>";
        }
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./) && $transform =~s/^${path}Factorright //) {
        my $typematch=0;
        if (($rightleft =~/^\( .s / || $rightleft =~/^[a-j01]/) &&
            ($leftleft =~/^\( .s / || $leftleft =~/^[a-j01]/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightleft =~/^\( .m / || $rightleft =~/^[A-Z]/) &&
            ($leftleft =~/^\( .m / || $leftleft =~/^[A-Z]/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightleft =~/^\( .v / || $rightleft =~/^[o-z]/) &&
            ($leftleft =~/^\( .v / || $leftleft =~/^[o-z]/)) {
            $typematch=1;
            $op =~s/.$/v/;
        }
        if ($typematch) {
            $newleft = GenerateProgBfromProgA("($op $leftleft $rightleft)",$path."left ");
            $newright= GenerateProgBfromProgA("$rightright",$path."right ");
            return "($leftop $newleft $newright)";
        } else {
            return "<PROGBFAILTOMATCH>";
        }
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $rightop) && $transform =~s/^${path}Assocleft //) {
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("$rightright",$path."right ");
        return "($op $newleft $newright)";
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $leftop) && $transform =~s/^${path}Assocright //) {
        $newleft = GenerateProgBfromProgA("$leftleft",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        return "($op $newleft $newright)";
    }
  
    if ((($op eq "nv" && $leftop eq "-v") ||
         ($op eq "ns" && $leftop eq "-s") ||
         ($op eq "is" && $leftop eq "/s") ||
         ($op eq "nm" && $leftop eq "-m")) && $transform =~s/^${path}Flipleft //) {
        $newleft = GenerateProgBfromProgA("$leftright",$path."left ");
        $newright= GenerateProgBfromProgA("$leftleft",$path."right ");
        return "($leftop $newleft $newright)";
    }

    if ((($op eq "-s" && $rightop =~/[\-n]s/) ||
         ($op eq "/s" && $rightop =~/[\/i]s/) ||
         ($op eq "-m" && $rightop =~/[\-n]m/) ||
         ($op eq "-v" && $rightop =~/[\-n]v/)) && $transform =~s/^${path}Flipright //) {
        $newop = $op;
        $newop =~s/\-/\+/;
        $newop =~s/\//\*/;
        $newleft = GenerateProgBfromProgA("$left",$path."left ");
        if ($op eq $rightop) {
            $newright= GenerateProgBfromProgA("($op $rightright $rightleft)",$path."right ");
        } else {
            $newright= GenerateProgBfromProgA("$rightleft",$path."right ");
        }
        return "($newop $newleft $newright)";
    }
    if ($op eq "*m" && $transform =~s/^${path}Transpose //) {
        $newleft = GenerateProgBfromProgA("$right",$path."left left left ");
        $newright= GenerateProgBfromProgA("$left",$path."left right left ");
        return "(tm (*m (tm $newleft) (tm $newright)))";
    }
    if ((($op eq "-m") || ($op eq "+m")) && $transform =~s/^${path}Transpose //) {
        $newleft = GenerateProgBfromProgA("$left",$path."left left left ");
        $newright= GenerateProgBfromProgA("$right",$path."left right left ");
        return "(tm ($op (tm $newleft) (tm $newright)))";
    }
    if (($op eq "tm") && ($leftop eq "*m") && $transform =~s/^${path}Transpose //) {
        $newleft = GenerateProgBfromProgA("$leftright",$path."left left ");
        $newright= GenerateProgBfromProgA("$leftleft",$path."right left ");
        return "(*m (tm $newleft) (tm $newright))";
    }
    if (($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $transform =~s/^${path}Transpose //) {
        $newleft = GenerateProgBfromProgA("$leftleft",$path."left left ");
        $newright= GenerateProgBfromProgA("$leftright",$path."right left ");
        return "($leftop (tm $newleft) (tm $newright))";
    }
    if ($right eq "") {
        if (($leftop eq $op) && $transform =~s/^${path}Double //) {
            return GenerateProgBfromProgA($leftleft,$path);
        } else {
            $newleft = GenerateProgBfromProgA($left,$path."left ");
        }
        return "($op $newleft)";
    }

    if ($left ne $right && $transform =~s/^${path}Commute //) {
        $newleft = GenerateProgBfromProgA($right,$path."left ");
        $newright = GenerateProgBfromProgA($left,$path."right ");
        return "($op $newleft $newright)";
    } else {
        $newleft = GenerateProgBfromProgA($left,$path."left ");
        $newright = GenerateProgBfromProgA($right,$path."right ");
        return "($op $newleft $newright)";
    }
}

my $pos=0;
my $neg=0;
my $exactpos=0;
my $tpos=0;
my $tneg=0;
my @src;
my @tgt;
my @axpath;
my $progA;
my $progB;

my $lnum=0;
while (<$fh_all>) {
  $lnum++;
  /X (.*) Y (.*) Z (.*)$/ || die "Error: incorrect syntax on input file: $_\n";
  $progA=$1;
  $progB=$2;
  @src[$lnum]=": $progA\n";
  @tgt[$lnum]=$progB;
}
close($fh_all) || die "close fh_all failed: $!";

for ($axsteps=1; $axsteps < 13; $axsteps++) {
  open(my $fh_raw,">","/tmp/PrgEq_search_raw.txt") || die "open fh_raw failed: $!";
  for ($i=1; $i <= $lnum; $i++) {
    $groupA = @src[$i];
    $groupA =~ s/^.*: //;
    while ($groupA =~ s/^([^\n])\n//) {
      $progA = $1;
      print $fh_raw "X $progA Y $tgt[$i] Z Emptyprediction\n";
    }
  }
  close($fh_raw) || die "close fh_raw failed: $!";
  system "pre2graph.pl < tmpraw > tmpall\n";
  system "python translate.py -model $data_path/final-model_step_100000.pt -src $data_path/src-test.txt -beam_size 3 -n_best 3 -gpu 0 -output $data_path/pred-test_beam2.txt -dynamic_dict 2>&1 > $data_path/translate2.out";
  FIXME: Process beam outputs, call genBfromA
  FIXME: Check outputs for success, add outputs that are legal and not duplicates to src[$lnum], add axiom to axpath[$lnum]
}


zzzzzzzzzzz

while (<$truth>) {
    $total++;
    if ($target eq "Not_equal") {
        $neg++;
    } else {
        $pos++;
    }
    my $inc=1;
    for (my $i=0; $i < $beam; $i++) {
        my $p=<$pred>;
        chop($p);
        if ($target eq $p) {
            if ($target eq "Not_equal") {
                $tneg+=$inc;
            } else {
                $exactpos+=1;
                $tpos+=$inc;
            }
            $inc = 0;
        } elsif ($target ne "Not_equal") {
            $transform = "$p ";
            $progA =~s/\( /(/g;
            $progA =~s/ \)/)/g;
            $progB =~s/\( /(/g;
            $progB =~s/ \)/)/g;
            my $predB = GenerateProgBfromProgA($progA,"");
            if ($predB eq $progB && $transform eq "") {
                print "Pos but not exact:\n progA=$progA\n progB=$progB\n target=$target\n pred=$p\n";
                $tpos+=$inc;
                $inc = 0;
            }
        }
    }
}

print "Total = $total; Pos = $pos; True Pos = $tpos, exact = $exactpos\n";
print "               Neg = $neg; True Neg = $tneg\n";

