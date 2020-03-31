#!/usr/bin/perl
#
use strict;
use warnings;

if (! -f $ARGV[0]) {
  print "Usage: geneqv.pl configFile\n";
  print "  Create input and output files for program equivalence checking.\n";
  print "  This full version generates equations with scalars, vectors and\n";
  print "  matrices, simple operators (+,-,*,/,invert,negate,transpose).\n";
  print "  Operators are typed as scalar, matrix, or vector, resulting in this list:\n";
  print "     +s -s *s /s is ns +m -m *m im nm tm +v -v *v nv\n";
  print "  The transformations used are:\n";
  print "  - Cancel: (-s a a) => 0; (/s a a) => 1, (*m A (im A)) => I, etc\n";
  print "  - Noop: (+m A O) => A; (*m A I) => A, etc\n";
  print "  - Double: (ns (ns a)) => a; (im (im A)) => A, etc\n";
  print "  - Multzero: (*m A 0) => O; (*s 0 b) => 0, etc\n";
  print "  - Commute: (+v v w) => (+v w v), etc\n";
  print "  - Distribleft: (*s (+s a b) c) => (+s (*s a c) (*s b c)), etc\n";
  print "  - Distribright: (*m A (+m B C) => (+m (*m A B) (*m A C)), etc\n";
  print "  - Factorleft: (+s (*s a b) (*s a c) => (*s a (+s b c)), etc\n";
  print "  - Factorright: (+s (*s a c) (*s b c) => (*s (+s a b) c), etc\n";
  print "  - Assocleft: (*s a (*s b c)) => (*s (*s a b) c)), etc\n";
  print "  - Assocright: (*s (*s a b) c)) => (*s a (*s b c)), etc\n";
  print "  - Flipleft: (nv (-v v w)) => (-v w v)), (is (/s a b)) => (/s b a), etc\n";
  print "  - Flipright: (/s a (/s b c)) => (*s a (/s c b)),\n";
  print "               (-m A (nm B)) => (+m A B), (+v v w) => (-v v (nv w)),etc\n";
  print "  - Transpose: (*m A B) => (tm (*m (tm B) (tm A)); (+m A B) => (tm (+m (tm B) (tm A))\n";
  print "               (tm (*m A B)) => (*m (tm B) (tm A)), etc\n";
  print " Example:\n";
  print "  ./geneqv.pl \n";
  exit(1);
}

# Define variables used in configuration file
my @scalars;
my @matrices;
my @vectors;

my $functions;
my $rootProbChildSubtree;
my $childProbChildSubtreeDelta;
my $axioms;
my $genNotEq;
my $numSamples;
my $maxTokens;
my $maxOutputTokens;
my @axNumFrac;
my $multipass;

# Read in configuration data for generation variables
open(my $cfg,"<",$ARGV[0]);
while (<$cfg>){
  eval;
}
close $cfg;

# Probability ratio used during program generation
my $pr = $multipass ? 0.4 : 1.0;

sub GenerateProgA {
    # Generate a random legal program tree
     
    # Input is list of operations allowed, can have multiples to skew generation
    # i.e.: "+s -s *s /s is ns +m -m *m im nm tm +v -v *v nv"
    my @ops = split / /,$_[0];
    my $prob = $_[1];

    my $op = $ops[rand @ops];
    while (! ($op =~ /$functions/)) {
        $op = $ops[rand @ops];
    }
    my $left;
    my $right;

    if ($op eq "*s") {
        if (rand() < $prob) {
            $left = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
        } else {
            $left = $scalars[rand @scalars];
        }
        if (rand() < $prob) {
            $right = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
        } else {
            $right = $scalars[rand @scalars];
        }
        return "($op $left $right)";
    }
    if ($op eq "+s" || $op eq "-s" || $op eq "/s" || $op eq "is" || $op eq "ns") {
        my $factor="";
        if (rand() < 0.5 && $prob > 0.01 && $prob < 0.5 && $op=~/[\+\-]/) {
            if (rand() < 0.5) {
               $factor="*s";
            } else {
               $factor="/s";
            }
        }
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $left = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $left = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
        } else {
            if ($op eq "is") {
                $left = $scalars[rand (@scalars-1)];
            } else {
                $left = $scalars[rand @scalars];
            }
        }
        if ($op eq "is" || $op eq "ns") {
            return "($op $left)";
        } 
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $right = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $right = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
        } else {
            if ($op eq "/s") {
                $right = $scalars[rand (@scalars-1)];
            } else {
                $right = $scalars[rand @scalars];
            }
        }
        return "($op $left $right)";
    }
    if ($op eq "*m") {
        if (rand() < 0.2) {
            if (rand() < $prob) {
                $left = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
            } else {
                $left = $scalars[rand @scalars];
            }
            if (rand() < $prob) {
                $right = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
            } else {
                $right = $matrices[rand @matrices];
            }
        } else {
            if (rand() < $prob) {
                $left = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
            } else {
                $left = $matrices[rand @matrices];
            }
            if (rand() < 0.25) {
                if (rand() < $prob) {
                    $right = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
                } else {
                    $right = $scalars[rand @scalars];
                }
            } else {
                if (rand() < $prob) {
                    $right = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
                } else {
                    $right = $matrices[rand @matrices];
                }
            }
        }
        return "($op $left $right)";
    }
    if ($op eq "+m" || $op eq "-m" || $op eq "tm" || $op eq "im" || $op eq "nm") {
        my $factor="";
        if (rand() < 0.5 && $prob > 0.1 && $prob < 0.5 && $op=~/[\+\-]/) {
            $factor="*m";
        }
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $left = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $left = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
        } else {
            if ($op eq "im") {
                $left = $matrices[rand (@matrices-1)];
            } else {
                $left = $matrices[rand @matrices];
            }
        }
        if ($op eq "im" || $op eq "nm" || $op eq "tm") {
            return "($op $left)";
        } 
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $right = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $right = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
        } else {
            $right = $matrices[rand @matrices];
        }
        return "($op $left $right)";
    }
    if ($op eq "*v") {
        # Generate a vector as a matrix-vector multiply
        if (rand() < 0.20) {
            if (rand() < $prob) {
                $left = GenerateProgA("+m -m *m +m -m *m tm im nm",$prob+$childProbChildSubtreeDelta);
            } else {
                $left = $matrices[rand @matrices];
            }
            if (rand() < $prob) {
                $right = GenerateProgA("+v -v *v +v -v *v nv",$prob+$childProbChildSubtreeDelta);
            } else {
                $right = $vectors[rand @vectors];
            }
        } elsif (rand() < 0.5) {
            if (rand() < $prob) {
                $left = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
            } else {
                $left = $scalars[rand @scalars];
            }
            if (rand() < $prob) {
                $right = GenerateProgA("+v -v *v +v -v *v nv",$prob+$childProbChildSubtreeDelta);
            } else {
                $right = $vectors[rand @vectors];
            }
        } else {
            if (rand() < $prob) {
                $left = GenerateProgA("+v -v *v +v -v *v nv",$prob+$childProbChildSubtreeDelta);
            } else {
                $left = $vectors[rand @vectors];
            }
            if (rand() < $prob) {
                $right = GenerateProgA("+s -s *s /s +s -s *s /s is ns",$prob+$childProbChildSubtreeDelta);
            } else {
                $right = $scalars[rand @scalars];
            }
        }
        return "($op $left $right)";
    }
    if ($op eq "+v" || $op eq "-v" || $op eq "nv") {
        my $factor="";
        if (rand() < 0.5 && $prob > 0.1 && $prob < 0.5 && $op=~/[\+\-]/) {
            $factor="*v";
        }
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $left = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $left = GenerateProgA("+v -v *v +v -v *v nv",$prob+$childProbChildSubtreeDelta);
        } else {
            $left = $vectors[rand @vectors];
        }
        if ($op eq "nv") {
            return "($op $left)";
        } 
        if ($factor) {
            # Bias so that Factor transform can occur more often
            $right = GenerateProgA($factor,$prob+$childProbChildSubtreeDelta);
        } elsif (rand() < $prob) {
            $right = GenerateProgA("+v -v *v +v -v *v nv",$prob+$childProbChildSubtreeDelta);
        } else {
            $right = $vectors[rand @vectors];
        }
        return "($op $left $right)";
    }
}

my $transform = "";

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
    my $dont_commute = 0;

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

    if ($op =~/^[+\-*\/]/ && rand() < 0.03 * $pr && $genNotEq) {
        # 2 operands
        $transform = "Not_equal ";
        if (rand() < 0.2 || $op eq "*v") {
            $op =~s/^./n/;
            $newleft= GenerateProgBfromProgA($right,$path."left ");
            return "($op $newleft)";
        }
        if (rand() < 0.33 && ($op =~/[+\-\/][sm]/)) {
            $op =~s/^./\*/;
        } elsif (rand() < 0.5 && !($op =~/\+/)) {
            $op =~s/^./\+/;
        } elsif (rand() < 0.5 && ($op =~/s[+\-*]/)) {
            $op =~s/^./\//;
        } else {
            if (!($op =~/\-/)) {
                $op =~s/^./\-/;
            } else {
                $op =~s/^./\+/;
            }
        }
        if (rand() < 0.25 && $leftop) {
            $newleft= GenerateProgBfromProgA($leftleft,$path."left ");
            $newright= GenerateProgBfromProgA($right,$path."right ");
            return "($op $newleft $newright)";
        } 
        if (rand() < 0.33 && $rightop) {
            $newleft= GenerateProgBfromProgA($left,$path."left ");
            $newright= GenerateProgBfromProgA($rightleft,$path."right ");
            return "($op $newleft $newright)";
        } 
    }
    
    if ($op =~/^[int]/ && rand() < 0.04 * $pr && $leftop && $genNotEq) {
        # 1 operand
        $transform = "Not_equal ";
        if (rand() < 0.6 || $op eq "nv") {
            if (rand() < 0.5) {
                $op =~s/^./\+/;
            } else {
                $op =~s/^./\-/;
            }
            $newleft= GenerateProgBfromProgA($leftleft,$path."left ");
            $newright= GenerateProgBfromProgA($left,$path."right ");
            return "($op $newleft $newright)";
        } elsif ($op eq "is") {
            $op = "ns";
        } elsif ($op eq "ns") {
            $op = "is";
        } elsif ($op eq "im") {
            $op = "nm";
        } elsif ($op eq "tm") {
            $op = "im";
        } else {
            $op = "tm";
        }
    }
    
    if (rand() < 0.4 * $pr && ($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $axioms =~/Cancel/) {
        $transform .= $path."left Cancel ";
        if ($leftop eq "-s") {
            return GenerateProgBfromProgA("($op 0 $right)",$path);
        } else {
            return GenerateProgBfromProgA("($op 1 $right)",$path);
        }
    }

    if (rand() < 0.4 * $pr && ($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= $path."right Cancel ";
        if ($rightop eq "-s") {
            return GenerateProgBfromProgA("($op $left 0)",$path);
        } else {
            return GenerateProgBfromProgA("($op $left 1)",$path);
        }
    }

    if (rand() < 0.4 * $pr && ($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $axioms =~/Cancel/) {
        $transform .= $path."left Cancel ";
        if ($leftop eq "-m") {
            return GenerateProgBfromProgA("($op O $right)",$path);
        } else {
            return GenerateProgBfromProgA("($op o $right)",$path);
        }
    }

    if (rand() < 0.4 * $pr && ($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= $path."right Cancel ";
        if ($rightop eq "-m") {
            return GenerateProgBfromProgA("($op $left O)",$path);
        } else {
            return GenerateProgBfromProgA("($op $left o)",$path);
        }
    }

    if (rand() < 0.4 * $pr && $op eq "*m" && $axioms =~/Cancel/ && 
                     (($leftleft eq $right && $leftop eq "im") ||
                      ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= $path."Cancel ";
        return "I";
    }

    if (rand() < 0.4 * $pr && (($op eq "+s" && ($left eq "0" || $right eq "0")) ||
                         ($op eq "-s" && $right eq "0") ||
                         ($op eq "*s" && ($left eq "1" || $right eq "1")) ||
                         ($op eq "/s" && $right eq "1")) && $axioms =~/Noop/) {
        $transform .= $path."Noop ";
        if ($left eq "0" || $left eq "1") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if (rand() < 0.4 * $pr && (($op eq "+m" && ($left eq "O" || $right eq "O")) ||
                         ($op eq "-m" && $right eq "O")) && $axioms =~/Noop/) {
        $transform .= $path."Noop ";
        if ($left eq "O") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if (rand() < 0.4 * $pr && $op eq "*m" && (($left eq "I" && ($rightop =~ /.m/ || $right =~ /^[A-Z]/)) || ($right eq "I" && ($leftop =~ /.m/ || $left =~ /^[A-Z]/))) && $axioms =~/Noop/) {
        $transform .= $path."Noop ";
        if ($left eq "I") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if (rand() < 0.4 * $pr && (($op eq "+v" && ($left eq "o" || $right eq "o")) ||
                         ($op eq "-v" && $right eq "o")) && $axioms =~/Noop/) {
        $transform .= $path."Noop ";
        if ($left eq "o") {
            return GenerateProgBfromProgA($right,$path);
        } else {
            return GenerateProgBfromProgA($left,$path);
        }
    }

    if (rand() < 0.4 * $pr && (($op eq "*s" && ($left eq "0" || $right eq "0")) ||
                         ($op eq "/s" && $left eq "0")) && $axioms =~/Multzero/) {
        $transform .= $path."Multzero ";
        return "0";
    }

    if (rand() < 0.4 * $pr && ($op eq "*m" && ($left eq "O" || $right eq "O" || $left eq "0" || $right eq "0"))
                        && $axioms =~/Multzero/) {
        $transform .= $path."Multzero ";
        return "O";
    }

    if (rand() < 0.4 * $pr && ($op eq "*v" && ($left =~/^[oO0]/ || $right =~/^[oO0]/))
                        && $axioms =~/Multzero/) {
        $transform .= $path."Multzero ";
        return "o";
    }

    if (rand() < 0.5 * $pr && ($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= $path."Distribleft ";
        $newleft = GenerateProgBfromProgA("($op $leftleft $right)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        $leftop =~s/.$/m/;
        return "($leftop $newleft $newright)";
    }

    if (rand() < 0.5 * $pr && ($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= $path."Distribright ";
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $left $rightright)",$path."right ");
        $rightop =~s/.$/m/;
        return "($rightop $newleft $newright)";
    }

    if (rand() < 0.5 * $pr && ($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= $path."Distribleft ";
        $newleft = GenerateProgBfromProgA("($op $leftleft $right)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "($leftop $newleft $newright)";
    }

    if (rand() < 0.5 * $pr && ($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= $path."Distribright ";
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("($op $left $rightright)",$path."right ");
        if ($op =~/.v/) {$rightop =~s/.$/v/}
        return "($rightop $newleft $newright)";
    }

    if (rand() < 0.6 * $pr && ($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./) && $axioms =~/Factorleft/) {
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
            $transform .= $path."Factorleft ";
            $newleft = GenerateProgBfromProgA("$leftleft",$path."left ");
            $newright= GenerateProgBfromProgA("($op $leftright $rightright)",$path."right ");
            return "($leftop $newleft $newright)";
        }
    }

    if (rand() < 0.6 * $pr && ($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./) && $axioms =~/Factorright/) {
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
            $transform .= $path."Factorright ";
            $newleft = GenerateProgBfromProgA("($op $leftleft $rightleft)",$path."left ");
            $newright= GenerateProgBfromProgA("$rightright",$path."right ");
            return "($leftop $newleft $newright)";
        }
    }

    if (rand() < 0.5 * $pr && ($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $rightop) && $axioms =~/Assocleft/) {
        $transform .= $path."Assocleft ";
        $newleft = GenerateProgBfromProgA("($op $left $rightleft)",$path."left ");
        $newright= GenerateProgBfromProgA("$rightright",$path."right ");
        return "($op $newleft $newright)";
    }

    if (rand() < 0.5 * $pr && ($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $leftop) && $axioms =~/Assocright/) {
        $transform .= $path."Assocright ";
        $newleft = GenerateProgBfromProgA("$leftleft",$path."left ");
        $newright= GenerateProgBfromProgA("($op $leftright $right)",$path."right ");
        return "($op $newleft $newright)";
    }
  
    if (rand() < 0.5 * $pr && (($op eq "nv" && $leftop eq "-v") ||
                         ($op eq "ns" && $leftop eq "-s") ||
                         ($op eq "is" && $leftop eq "/s") ||
                         ($op eq "nm" && $leftop eq "-m")) && $axioms =~/Flipleft/) {
        $transform .= $path."Flipleft ";
        $newleft = GenerateProgBfromProgA("$leftright",$path."left ");
        $newright= GenerateProgBfromProgA("$leftleft",$path."right ");
        return "($leftop $newleft $newright)";
    }

    if (rand() < 0.5 * $pr && (($op eq "-s" && $rightop =~/[\-n]s/) ||
                         ($op eq "/s" && $rightop =~/[\/i]s/) ||
                         ($op eq "-m" && $rightop =~/[\-n]m/) ||
                         ($op eq "-v" && $rightop =~/[\-n]v/)) && $axioms =~/Flipright/) {
        $transform .= $path."Flipright ";
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
    if (rand() < 0.2 * $pr && $op eq "*m" && $axioms =~/Transpose/) {
        $transform .= $path."Transpose ";
        $newleft = GenerateProgBfromProgA("$right",$path."left left left ");
        $newright= GenerateProgBfromProgA("$left",$path."left right left ");
        return "(tm (*m (tm $newleft) (tm $newright)))";
    }
    if (rand() < 0.2 * $pr && (($op eq "-m") || ($op eq "+m")) && $axioms =~/Transpose/) {
        $transform .= $path."Transpose ";
        $newleft = GenerateProgBfromProgA("$left",$path."left left left ");
        $newright= GenerateProgBfromProgA("$right",$path."left right left ");
        return "(tm ($op (tm $newleft) (tm $newright)))";
    }
    if (rand() < 0.5 * $pr && ($op eq "tm") && ($leftop eq "*m") && $axioms =~/Transpose/) {
        $transform .= $path."Transpose ";
        $newleft = GenerateProgBfromProgA("$leftright",$path."left left ");
        $newright= GenerateProgBfromProgA("$leftleft",$path."right left ");
        return "(*m (tm $newleft) (tm $newright))";
    }
    if (rand() < 0.5 * $pr && ($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $axioms =~/Transpose/) {
        $transform .= $path."Transpose ";
        $newleft = GenerateProgBfromProgA("$leftleft",$path."left left ");
        $newright= GenerateProgBfromProgA("$leftright",$path."right left ");
        return "($leftop (tm $newleft) (tm $newright))";
    }
    if ($right eq "") {
        if (rand() < 0.5 * $pr && ($leftop eq $op) && $axioms =~/Double/) {
            $transform .= $path."Double ";
            return GenerateProgBfromProgA($leftleft,$path);
        } else {
            $newleft = GenerateProgBfromProgA($left,$path."left ");
        }
        return "($op $newleft)";
    }

    if (($op =~/-./ || $op eq "/s" || $op eq "*m") && (!$genNotEq || rand() < 0.95) || $op eq "*v") {
        $dont_commute = 1;
    }
    if (rand() < 0.1 * $pr && !$dont_commute && $left ne $right && $axioms =~/Commute/) {
        if ($op =~/-./ || $op eq "*m" || $op eq "/s") {
            $transform = "Not_equal ";
        } else {
            $transform .= $path."Commute ";
        }
        $newleft = GenerateProgBfromProgA($right,$path."left ");
        $newright = GenerateProgBfromProgA($left,$path."right ");
        return "($op $newleft $newright)";
    } else {
        $newleft = GenerateProgBfromProgA($left,$path."left ");
        $newright = GenerateProgBfromProgA($right,$path."right ");
        return "($op $newleft $newright)";
    }
}

my $samples=0;
my %progs;
my $simplify = 0;
if ($axioms =~ /Cancel/ && $axioms =~ /Noop/ && $axioms =~ /Double/ && $axioms =~ /Multzero/ && $multipass) {
    $simplify=1;
}
my $axiomsOrig = $axioms;
while ($samples < $numSamples) {
    $transform = "";
    # Triple binary operations to skew probabilities at root
    my $progA = GenerateProgA("+s -s *s /s +s -s *s /s +s -s *s /s is ns +m -m *m +m -m *m +m -m *m im nm tm +v -v *v +v -v *v +v -v *v nv",$rootProbChildSubtree);
    my $progTmp = $progA;
    my $progMid;
    my $transformMid;
    next if exists $progs{$progA};
    $progTmp =~s/(.)/$1 /g;
    $progTmp =~s/\s+/ /g;
    $progTmp =~s/(\( .) (.)/$1$2/g;
    next if (int(split / /,$progTmp) > ($maxTokens/2 + int(@axNumFrac)));
    my $progB = GenerateProgBfromProgA($progA,"");
    if ($multipass) {
        if ($simplify) {
            $axioms = "(Cancel|Noop|Double|Multzero)";
            $progB = GenerateProgBfromProgA($progB,"");
            $axioms = $axiomsOrig;
        }
        $progB = GenerateProgBfromProgA($progB,"");
        next if $progB eq $progA;
        $progMid = $progB;
        $transformMid = $transform;
        $progB = GenerateProgBfromProgA($progB,"");
        next if $progB eq $progA;
        if ((int(split /[A-Z]/,$transform)-1 < 4 || rand() < 0.7) && $simplify) {
            $axioms = "(Cancel|Noop|Double|Multzero)";
            $progB = GenerateProgBfromProgA($progB,"");
            $axioms = $axiomsOrig;
        }
        next if $progB eq $progA;
    }
    if ($genNotEq) {
      if ((rand() < 0.01 && !($progA =~/b/) && $progB =~s/a/b/) || 
        (rand() < 0.01 && !($progA =~/d/) && $progB =~s/c/d/) || 
        (rand() < 0.01 && !($progA =~/B/) && $progB =~s/A/B/) || 
        (rand() < 0.01 && !($progA =~/C/) && $progB =~s/B/C/) || 
        (rand() < 0.01 && !($progA =~/x/) && $progB =~s/w/x/) ||
        (rand() < 0.01 && !($progA =~/a/) && $progB =~s/c/a/) || 
        (rand() < 0.01 && !($progA =~/c/) && $progB =~s/e/c/) || 
        (rand() < 0.01 && !($progA =~/e/) && $progB =~s/b/e/) || 
        (rand() < 0.01 && !($progA =~/D/) && $progB =~s/C/D/) || 
        (rand() < 0.01 && !($progA =~/w/) && $progB =~s/y/w/)) {
        $transform = "Not_equal";
      }
    }
    $transform =~ s/^.*Not_equal.*$/Not_equal/;
    $transform =~ s/\s+$//;
    next if !$transform;
    my $axiomNum = int(split /[A-Z]/,$transform)-1;
    next if $axiomNum >= int(@axNumFrac);
    next if (!($transform =~/Not_equal/) && (rand() > $axNumFrac[$axiomNum]));
    $progs{$progA} = 1;
    $progA =~s/(.)/$1 /g;
    $progA =~s/\s+/ /g;
    $progA =~s/(\( .) (.)/$1$2/g;
    $progB =~s/(.)/$1 /g;
    $progB =~s/\s+/ /g;
    $progB =~s/(\( .) (.)/$1$2/g;
    my $all = "X $progA Y $progB Z $transform";
    $all =~s/\s+/ /g;
    if ((int(split / /,$progA) + int(split / /,$progB) < $maxTokens) && (int(split / /,$transform) <= $maxOutputTokens)) {
        $samples+=1;
        print $all."\n";
    }
    if ($multipass && !($transform=~/Not_equal/) && !(exists $progs{$progMid})) {
        $transformMid =~ s/\s+$//;
        $transform =~s/^$transformMid\s*//;
        $progA = $progMid;
        $progA =~s/(.)/$1 /g;
        $progA =~s/\s+/ /g;
        $progA =~s/(\( .) (.)/$1$2/g;
        $axiomNum = int(split /[A-Z]/,$transform)-1;
        $all = "X $progA Y $progB Z $transform";
        $all =~s/\s+/ /g;
        if ($transform && (int(split / /,$progA) + int(split / /,$progB) < $maxTokens) && (int(split / /,$transform) <= $maxOutputTokens) && (rand() < 2*$axNumFrac[$axiomNum])) {
            $progs{$progMid} = 1;
            $samples+=1;
            print $all."\n";
        }
    }
}

