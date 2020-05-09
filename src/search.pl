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
my @progAs;
my @progBs;
my @tgt;
my @axpath;
my @axioms;
my @searching;
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
  $progAs[$lnum][1][1]="$progA";  # Dims are sample,axiom,beam
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
          $transform = $ln." ";
          $predB = GenerateProgBfromProgA($progA,"");
          if ($!transform eq "") {
            $legal++;
            if (!$searching[$i.$predB]) {
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
