#!/usr/bin/perl
#
use List::Util qw(shuffle);
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
my $functions;
my $axioms;
my $numSamples;
my $maxTokens;
my $maxOutputTokens;
my @axNumFrac;
my %nonTerm;
my @rndevals;
my $output_matrixes;
my $output_scalars;
my $output_vectors;
my $var_reuse;
my $transform = "";

# Read in configuration data for generation variables
open(my $cfg,"<",$ARGV[0]);
my $lastNonTerm="";
while (<$cfg>){
  if (!/ -> / && /^ *[^#]/ && / = /) {
    # Handle random ranges in variable setup
    if (s/rnd\((\d+),(\d+)\)/(int(rand(1+$2-$1))+$1)/) {
      push @rndevals,$_;
    }
    eval;
  } elsif (/^\s*(\S+)\s+->\s+(.*\S)\s+p\*(\d+)\s*$/) {
    $lastNonTerm=$1;
    @{$nonTerm{$lastNonTerm}}=("$2")x$3;
  } elsif (/^\s*(\S+)\s+->\s+(.*\S)\s*$/) {
    $lastNonTerm=$1;
    @{$nonTerm{$lastNonTerm}}=("$2");
  } elsif (/^\s+->\s+(.*\S)\s+p\*(\d+)\s*$/) {
    push @{$nonTerm{$lastNonTerm}},("$1")x$2;
  } elsif (/^\s+->\s+(.*\S)\s*$/) {
    push @{$nonTerm{$lastNonTerm}},"$1";
  }
}
close $cfg;

sub FindPath {
    my $stm = $_[0];
    my $var = $_[1];
    my $path = "";

    $stm =~ s/^(.*)= //;
    $stm =~ s/ +$//;
    if ($stm eq $var) {
       return "";
    }
    $stm =~ s/ $var .*$/ /;
    while ($stm =~ s/\( [^()]+ \) /Token /g) {
        # Loop removes trees
    }
    while ($stm =~ s/^\( \S+ //) {
        if ($stm =~ s/^[^()]\S* //) {
            $path .= "r"
        } else {
            $path .= "l"
        } 
    }
    return $path;
}

sub ExpandNonTerm {
    my $expr_type = $_[0];
    my @scalar_avail = @{$_[1]};
    my @vector_avail = @{$_[2]};
    my @matrix_avail = @{$_[3]};
    my $max_tokens = $_[4];

    my @tmplist;

    if ($expr_type eq "Scalar_id") {
        if(scalar @scalar_avail == 0) {
           @tmplist=("0s","1s");
        } else {
           @tmplist=@scalar_avail;
        }
        return $tmplist[ rand @tmplist ];
    } 
    if ($expr_type eq "Vector_id") {
        if(scalar @vector_avail == 0) {
           return "0v";
        } else {
           @tmplist=@vector_avail;
        }
        return $tmplist[ rand @tmplist ];
    } 
    if ($expr_type eq "Matrix_id") {
        if(scalar @matrix_avail == 0) {
           @tmplist=("0m","Im");
        } else {
           @tmplist=@matrix_avail;
        }
        return $tmplist[ rand @tmplist ];
    }
    if (! $nonTerm{$expr_type}) {
        die "No expansion rule for $expr_type\n";
    }
    @tmplist = @{$nonTerm{$expr_type}};
    @tmplist = split / /,($tmplist[ rand @tmplist ]);
    while ((scalar @tmplist > 1) && (rand($max_tokens) < 1.5)) {
        @tmplist = @{$nonTerm{$expr_type}};
        @tmplist = split / /,($tmplist[ rand @tmplist ]);
    }
    my $retval="";
    foreach my $expr (@tmplist) {
        if ($nonTerm{$expr}) {
            $retval .= ExpandNonTerm($expr,\@scalar_avail,\@vector_avail,\@matrix_avail,int(($max_tokens - 1)/(scalar @tmplist < 3 ? 1 : 2 )))." ";
        } else {
            $retval .= $expr." ";
        }
    }
    chop $retval;
    return $retval;
}

sub CreateRHS {
    my $var = $_[0];
    my @scalar_avail = @{$_[1]};
    my @vector_avail = @{$_[2]};
    my @matrix_avail = @{$_[3]};
    my $max_tokens = $_[4];

    my $assign = "";
    my $nonTerm = "";
    my $expr_type = "";

    if ($var =~ /^s/) {
        $expr_type = "Scalar_Exp";
    } elsif ($var =~ /^v/) {
        $expr_type = "Vector_Exp";
    } else {
        $expr_type = "Matrix_Exp";
    }
    $nonTerm = ExpandNonTerm($expr_type,\@scalar_avail,\@vector_avail,\@matrix_avail,$max_tokens);
    # Rerun expansion if we generated a simple assign 
    # This makes them rarer but not impossible
    if ($nonTerm =~ /^\s*\S+\s*$/) {
        $nonTerm = ExpandNonTerm($expr_type,\@scalar_avail,\@vector_avail,\@matrix_avail,$max_tokens);
    }
    $assign .= $nonTerm;
    $assign .= " ; ";
    return $assign;
}

sub InterAssignAxioms {
    my $progA     = $_[0];
    my $tmpscalar = $_[1];
    my $tmpvector = $_[2];
    my $tmpmatrix = $_[3];
    my $progB = "";

    my $lhsPrev = "";
    my $eqPrev = "";
    my $rhsPrev = "";
    my $stmnum=1;
    my $DoInline= (rand() < 0.5);

    # Check for possible swaps
    if (rand() < 0.3 && $axioms =~/Swapprev/) {
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if (rand()<0.2 && $eqPrev && ! ($rhsPrev =~ /$lhs/) && ! ($stmA =~ /$lhsPrev/)) {
                $transform .= "stm$stmnum Swapprev ";
                $progB .= "$lhs $eq $rhs ; ";
            } else {
                if ($lhsPrev) {
                    $progB .= "$lhsPrev $eqPrev $rhsPrev ; ";
                }
                $lhsPrev = $lhs;
                $eqPrev = $eq;
                $rhsPrev = $rhs;
            }
            $stmnum++;
        }
        $progB .= "$lhsPrev $eqPrev $rhsPrev ; ";
        $progA = $progB;
    }

    # Possibly inline a variable
    if (rand() < 0.3 && $DoInline && $axioms =~/Inline/) {
        my %vars;
        $progB = "";
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            foreach my $var (shuffle(keys %vars)) {
                if (rand()<0.2 && $rhs =~ s/$var/$vars{$var}/g) {
                    $transform .= "stm$stmnum Inline $var ";
                    last;
                }
            }
            if (! ($rhs =~/\(.*\(.*\(/) && $eq ne "===" && ! ($rhs =~/$lhs/)) {
                $vars{$lhs}=$rhs;
            } else {
                (exists $vars{$lhs}) && (delete $vars{$lhs});
            }
            $progB .= "$lhs $eq $rhs ; ";
            $stmnum++;
        }
        $progA = $progB;
    }
    
    # Possibly delete dead code (unused variable assign)
    if (rand() < 0.8 && $DoInline && $axioms =~/Deletestm/) {
        my %vars;
        $progB = "";
        $stmnum=1;
        while ($progA =~ s/^([^;]+); //) {
            my $stmA = $1;
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || die "Illegal statement in dead code check: $stmA\n"; 
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($progA =~/$lhs/ || $eq eq "===") {
                $progB .= "$lhs $eq $rhs ; ";
            } else {
                $transform .= "stm$stmnum Deletestm ";
                last;
            }
            $stmnum++;
        }
        $progA = $progB.$progA;
    }
    
    # Check for possible new variables
    if (rand() < 0.8 && !$DoInline && $axioms =~/Newtmp/) {
        my %expr;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~ s/^\s*\S+ =+ //;
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) \( ([^()]+) \) \)/ ( )/) {
                $expr{"$1 ( $2 ) ( $3 )"}+=6;
                $expr{$2}+=3;
                $expr{$3}+=3;
            }
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) ([^()]+) \)/ ( )/) {
                $expr{"$1 ( $2 ) $3"}+=5;
                $expr{$2}+=3;
            }
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) \)/ ( )/) {
                $expr{"$1 ( $2 )"}+=4;
                $expr{$2}+=3;
            }
            while ($stmA =~s/ \( ([^()]+) \)/ ( )/) {
                $expr{$1}+=3;
            }
        }
        my $stmnum=1;
        $progB="";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S.*)$/ || next;
            $stmA = $1;
            foreach my $key (shuffle(keys %expr)) {
                if (rand() < (1.0-6.0/$expr{$key})) {
                    my $var="";
                    $key =~/^.s / && ($var=$tmpscalar);
                    $key =~/^.v / && ($var=$tmpvector);
                    $key =~/^.m / && ($var=$tmpmatrix);
                    if (! ($stmA =~/= \( \Q$key\E \) *$/) && ($stmA =~ s/\( \Q$key\E \)/$var/g)) {
                        my $path = FindPath($stmA,$var);
                        %expr=();
                        $transform .= "stm$stmnum Newtmp N$path $var ";
                        $progB .= "$var = ( $key ) ; ";
                        last;
                    }
                }
            }
            $progB .= $stmA."; ";
            $stmnum++;
        }
        $progA = $progB;
    }

    # Possibly replace statement with lexically equivalent variable
    if (rand() < 0.8 && !$DoInline && $axioms =~/Usevar/) {
        my %vars;
        $progB = "";
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            foreach my $var (shuffle(keys %vars)) {
                if (rand()<0.6 && ($rhs =~ s/\Q$vars{$var}\E/$var/g)) {
                    $transform .= "stm$stmnum Usevar $var ";
                    last;
                }
            }
            foreach my $var (keys %vars) {
                if ($vars{$var} =~/$lhs/) {
                    delete $vars{$var};
                }
            }
            if (! ($rhs =~/\(.*\(.*\(.*\(.*\(/) && ($rhs =~/\(/) && $eq ne "===" && ! ($rhs =~/$lhs/)) {
                $vars{$lhs}=$rhs;
            } else {
                delete $vars{$lhs};
            }
            $progB .= "$lhs $eq $rhs ; ";
            $stmnum++;
        }
        $progA = $progB;
    }
    return $progA;
}

sub GenerateStmBfromStmA {
    my $progA = $_[0];
    my $stmnum = $_[1];
    my $path = $_[2];

    $progA =~s/^\( (..) // || return $progA;
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
    my $rightFirst = (rand() < 0.5) ? 1 : 0;

    if ($progA =~s/^\( (..) //) {
        $in=1;
        $left = "( ".$1." ";
        $leftop = $1;
        my $leftdone=0;
        while ($in >0) {
            if ($progA =~s/^(\s*)([^()\s]+)(\s*)//) {
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
            if ($progA =~s/^\)\s*//) {
                $in-=1;
                $left .= ")";
                if ($in > 0) {
                    $left .= " ";
                    if ($leftdone) {
                        if ($in == 1) {
                            $leftright .= ")";
                        } else {
                            $leftright .= ") ";
                        }
                    } else {
                        if ($in == 1) {
                            $leftleft .= ")";
                            $leftdone=1;
                        } else {
                            $leftleft .= ") ";
                        }
                    }
                }
            }
        }
    } else {
        $progA =~s/^(\S+)\s*//;
        $left = $1;
    }

    if ($progA =~s/^\s*\( (..) //) {
        $in=1;
        $right = "( ".$1." ";
        $rightop = $1;
        my $leftdone=0;
        while ($in >0) {
            if ($progA =~s/^(\s*)([^()\s]+)(\s*)//) {
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
            if ($progA =~s/^\)\s*//) {
                $in-=1;
                $right .= ")";
                if ($in > 0) {
                    $right .= " ";
                    if ($leftdone) {
                        if ($in == 1) {
                            $rightright .= ")";
                        } else {
                            $rightright .= ") ";
                        }
                    } else {
                        if ($in == 1) {
                            $rightleft .= ")";
                            $leftdone=1;
                        } else {
                            $rightleft .= ") ";
                        }
                    }
                }
            }
        }
    } else {
        $progA =~s/^\s*(\S+)\s*// ;
        if ($1 ne ")") {
            $right = $1;
        }
    }

    if (rand() < 0.2 && ($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}l ";
        if ($right ne "") {
            if ($leftop eq "-s") {
                return GenerateStmBfromStmA("( $op 0s $right )",$stmnum,$path);
            } else {
                return GenerateStmBfromStmA("( $op 1s $right )",$stmnum,$path);
            }
        } else {
            if ($leftop eq "-s") {
                return GenerateStmBfromStmA("( $op 0s )",$stmnum,$path);
            } else {
                return GenerateStmBfromStmA("( $op 1s )",$stmnum,$path);
            }
        }
    }

    if (rand() < 0.2 && ($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}r ";
        if ($rightop eq "-s") {
            return GenerateStmBfromStmA("( $op $left 0s )",$stmnum,$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 1s )",$stmnum,$path);
        }
    }

    if (rand() < 0.2 && ($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}l ";
        if ($right ne "") {
            if ($leftop eq "-m") {
                return GenerateStmBfromStmA("( $op 0m $right )",$stmnum,$path);
            } else {
                return GenerateStmBfromStmA("( $op 0v $right )",$stmnum,$path);
            }
        } else {
            if ($leftop eq "-m") {
                return GenerateStmBfromStmA("( $op 0m )",$stmnum,$path);
            } else {
                return GenerateStmBfromStmA("( $op 0v )",$stmnum,$path);
            }
        }
    }

    if (rand() < 0.2 && ($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}r ";
        if ($rightop eq "-m") {
            return GenerateStmBfromStmA("( $op $left 0m )",$stmnum,$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 0v )",$stmnum,$path);
        }
    }

    if (rand() < 0.2 && $op eq "*m" && $axioms =~/Cancel/ && 
                     (($leftleft eq $right && $leftop eq "im") ||
                      ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= "stm$stmnum Cancel ${path} ";
        return "Im";
    }

    if (rand() < 0.15 && (($op eq "+s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "-s" && $right eq "0s") ||
                         ($op =~ /\*./ && ($left eq "1s" || $right eq "1s")) ||
                         ($op =~ "/s" && $right eq "1s")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "0s" || $left eq "1s") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.15 && (($op eq "+m" && ($left eq "0m" || $right eq "0m")) ||
                         ($op eq "-m" && $right eq "0m")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "0m") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.15 && $op eq "*m" && (($left eq "Im" && ($rightop =~ /.m/ || $right =~ /^([0I]m|m\d+)/)) || ($right eq "Im" && ($leftop =~ /.m/ || $left =~ /^([0I]m|m\d+)/))) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "Im") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.15 && (($op eq "+v" && ($left eq "0v" || $right eq "0v")) ||
                         ($op eq "-v" && $right eq "0v")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "0v") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.2 && (($op eq "*s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "/s" && $left eq "0s")) && $axioms =~/Multzero/) {
        $transform .= "stm$stmnum Multzero ${path} ";
        return "0s";
    }

    if (rand() < 0.2 && ($op eq "*m" && ($left eq "0m" || $right eq "0m" || $left eq "0s" || $right eq "0s"))
                        && $axioms =~/Multzero/) {
        $transform .= "stm$stmnum Multzero ${path} ";
        return "0m";
    }

    if (rand() < 0.2 && ($op eq "*v" && ($left =~/^0[msv]/ || $right =~/^0[msv]/))
                        && $axioms =~/Multzero/) {
        $transform .= "stm$stmnum Multzero ${path} ";
        return "0v";
    }

    if (rand() < 0.2 && ($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= "stm$stmnum Distribleft ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $leftleft $right )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        $leftop =~s/.$/m/;
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.2 && ($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= "stm$stmnum Distribright ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$stmnum,$path."r");
        }
        $rightop =~s/.$/m/;
        return "( $rightop $newleft $newright )";
    }

    if (rand() < 0.2 && ($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= "stm$stmnum Distribleft ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $leftleft $right )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.2 && ($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= "stm$stmnum Distribright ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$stmnum,$path."r");
        }
        if ($op =~/.v/) {$rightop =~s/.$/v/}
        return "( $rightop $newleft $newright )";
    }

    if (rand() < 0.3 && ($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./) && $axioms =~/Factorleft/) {
        my $typematch=0;
        if (($rightright =~/^\( .s / || $rightright =~/^([01]s|s\d+)/) &&
            ($leftright =~/^\( .s / || $leftright =~/^([01]s|s\d+)/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightright =~/^\( .m / || $rightright =~/^([0I]m|m\d+)/) &&
            ($leftright =~/^\( .m / || $leftright =~/^([0I]m|m\d+)/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightright =~/^\( .v / || $rightright =~/^(0v|v\d+)/) &&
            ($leftright =~/^\( .v / || $leftright =~/^(0v|v\d+)/)) {
            $typematch=1;
            $op =~s/.$/v/;
        }
        if ($typematch) {
            $transform .= "stm$stmnum Factorleft ${path} ";
            if ($rightFirst) {
                $newright= GenerateStmBfromStmA("( $op $leftright $rightright )",$stmnum,$path."r");
            }
            $newleft = GenerateStmBfromStmA("$leftleft",$stmnum,$path."l");
            if (! $rightFirst) {
                $newright= GenerateStmBfromStmA("( $op $leftright $rightright )",$stmnum,$path."r");
            }
            return "( $leftop $newleft $newright )";
        }
    }

    if (rand() < 0.3 && ($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./) && $axioms =~/Factorright/) {
        my $typematch=0;
        if (($rightleft =~/^\( .s / || $rightleft =~/^([01]s|s\d+)/) &&
            ($leftleft =~/^\( .s / || $leftleft =~/^([01]s|s\d+)/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightleft =~/^\( .m / || $rightleft =~/^([0I]m|m\d+)/) &&
            ($leftleft =~/^\( .m / || $leftleft =~/^([0I]m|m\d+)/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightleft =~/^\( .v / || $rightleft =~/^(0v|v\d+)/) &&
            ($leftleft =~/^\( .v / || $leftleft =~/^(0v|v\d+)/)) {
            $typematch=1;
            $op =~s/.$/v/;
        }
        if ($typematch) {
            $transform .= "stm$stmnum Factorright ${path} ";
            if ($rightFirst) {
                $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
            }
            $newleft = GenerateStmBfromStmA("( $op $leftleft $rightleft )",$stmnum,$path."l");
            if (! $rightFirst) {
                $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
            }
            return "( $leftop $newleft $newright )";
        }
    }

    if (rand() < 0.2 && $op =~/\*./ && $rightop =~ /\*./ && $axioms =~/Assocleft/) {
        $transform .= "stm$stmnum Assocleft ${path} ";
        if (($leftop =~ /.s/ || $left =~/^([01]s|s\d+)/) && ($rightleft =~/^. .s/ || $rightleft =~/^([01]s|s\d+)/)) {
          $leftop = "*s";
        } elsif ($leftop =~ /.v/ || $left =~/^(0v|v\d+)/ || $rightleft =~/^. .v/ || $rightleft =~/^(0v|v\d+)/) {
          $leftop = "*v";
        } else {
          $leftop = "*m";
        }
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $leftop $left $rightleft )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
        }
        return "( $op $newleft $newright )";
    }

    if (rand() < 0.2 && 
             (($op =~/\+./ && $rightop =~/[\-+]./) || 
              ($op =~ /\*s/ && $rightop eq "/s")) &&
             $axioms =~/Assocleft/) {
        $transform .= "stm$stmnum Assocleft ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$stmnum,$path."r");
        }
        return "( $rightop $newleft $newright )";
    }

    if (rand() < 0.2 && $op =~/\*./ && $leftop =~ /\*./ && $axioms =~/Assocright/) {
        $transform .= "stm$stmnum Assocright ${path} ";
        if (($rightop =~ /.s/ || $right =~/^([01]s|s\d+)/) && ($leftright =~/^. .s/ || $leftright =~/^([01]s|s\d+)/)) {
          $rightop = "*s";
        } elsif ($rightop =~ /.v/ || $right =~/^(0v|v\d+)/ || $leftright =~/^. .v/ || $leftright =~/^(0v|v\d+)/) {
          $rightop = "*v";
        } else {
          $rightop = "*m";
        }
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $rightop $leftright $right )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $rightop $leftright $right )",$stmnum,$path."r");
        }
        return "( $op $newleft $newright )";
    }
  
    if (rand() < 0.2 && 
             (($op =~/[\-+]./ && $leftop =~/\+./) || 
              ($op eq "/s" && $leftop =~/\*s/)) &&
             $axioms =~/Assocright/) {
        $transform .= "stm$stmnum Assocright ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$stmnum,$path."r");
        }
        return "( $leftop $newleft $newright )";
    }
  
    if (rand() < 0.25 && (($op eq "nv" && $leftop eq "-v") ||
                         ($op eq "ns" && $leftop eq "-s") ||
                         ($op eq "is" && $leftop eq "/s") ||
                         ($op eq "nm" && $leftop eq "-m")) && $axioms =~/Flipleft/) {
        $transform .= "stm$stmnum Flipleft ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftright",$stmnum,$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."r");
        }
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.25 && (($op eq "-s" && $rightop =~/[\-n]s/) ||
                         ($op eq "/s" && $rightop =~/[\/i]s/) ||
                         ($op eq "-m" && $rightop =~/[\-n]m/) ||
                         ($op eq "-v" && $rightop =~/[\-n]v/)) && $axioms =~/Flipright/) {
        $transform .= "stm$stmnum Flipright ${path} ";
        $newop = $op;
        $newop =~s/\-/\+/;
        $newop =~s/\//\*/;
        if (! $rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."l");
        }
        if ($op eq $rightop) {
            $newright= GenerateStmBfromStmA("( $op $rightright $rightleft )",$stmnum,$path."r");
        } else {
            $newright= GenerateStmBfromStmA("$rightleft",$stmnum,$path."r");
        }
        if ($rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."l");
        }
        return "( $newop $newleft $newright )";
    }
    if (rand() < 0.1 && $op eq "*m" && $axioms =~/Transpose/) {
        $transform .= "stm$stmnum Transpose ${path} ";
        if ($rightFirst) {
            # Scalar values and array constants are allowed, but they don't transpose
            if (($left =~ /^m\d/) || ($left =~ /^\( .m/)) {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lrl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lr");
            }
        }
        if (($right =~ /^m\d/) || ($right =~ /^\( .m/)) {
            $newleft = GenerateStmBfromStmA("$right",$stmnum,$path."lll");
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenerateStmBfromStmA("$right",$stmnum,$path."ll");
        }
        if (! $rightFirst) {
            if (($left =~ /^m\d/) || ($left =~ /^\( .m/)) {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lrl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lr");
            }
        }
        return "( tm ( *m $newleft $newright ) )";
    }
    if (rand() < 0.1 && (($op eq "-m") || ($op eq "+m")) && $axioms =~/Transpose/) {
        $transform .= "stm$stmnum Transpose ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$right",$stmnum,$path."lrl");
        }
        $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."lll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$right",$stmnum,$path."lrl");
        }
        return "( tm ( $op ( tm $newleft ) ( tm $newright ) ) )";
    }
    if (rand() < 0.1 && ($op eq "tm") && ($leftop eq "*m") && $axioms =~/Transpose/) {
        $transform .= "stm$stmnum Transpose ${path} ";
        if ($rightFirst) {
            if (($leftleft =~ /^m\d/) || ($leftleft =~ /^\( .m/)) {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."rl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."r");
            }
        }
        if (($leftright =~ /^m\d/) || ($leftright =~ /^\( .m/)) {
            $newleft = GenerateStmBfromStmA("$leftright",$stmnum,$path."ll");
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenerateStmBfromStmA("$leftright",$stmnum,$path."l");
        }
        if (! $rightFirst) {
            if (($leftleft =~ /^m\d/) || ($leftleft =~ /^\( .m/)) {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."rl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."r");
            }
        }
        return "( *m $newleft $newright )";
    }
    if (rand() < 0.1 && ($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $axioms =~/Transpose/) {
        $transform .= "stm$stmnum Transpose ${path} ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$leftright",$stmnum,$path."rl");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$stmnum,$path."ll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$leftright",$stmnum,$path."rl");
        }
        return "( $leftop ( tm $newleft ) ( tm $newright ) )";
    }
    if ($right eq "") {
        if (rand() < 0.25 && ($leftop eq $op) && $axioms =~/Double/) {
            $transform .= "stm$stmnum Double ${path} ";
            return GenerateStmBfromStmA($leftleft,$stmnum,$path);
        } else {
            $newleft = GenerateStmBfromStmA($left,$stmnum,$path."l");
        }
        return "( $op $newleft )";
    }

    if ($op =~/-./ || $op eq "/s" || 
            ($op eq "*m" && !($leftop =~ /^.s/ || $left =~ /^([01][ms]|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01][ms]|s\d+)/)) ||
            ($op eq "*v" && !($leftop =~ /^.s/ || $left =~ /^([01]s|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01]s|s\d+)/))) {
        $dont_commute = 1;
    }
    if (rand() < 0.05 && !$dont_commute && $left ne $right && $axioms =~/Commute/) {
        $transform .= "stm$stmnum Commute ${path} ";
        if ($rightFirst) {
            $newright = GenerateStmBfromStmA($left,$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA($right,$stmnum,$path."l");
        if (! $rightFirst) {
            $newright = GenerateStmBfromStmA($left,$stmnum,$path."r");
        }
        return "( $op $newleft $newright )";
    } else {
        if ($rightFirst) {
            $newright = GenerateStmBfromStmA($right,$stmnum,$path."r");
        }
        $newleft = GenerateStmBfromStmA($left,$stmnum,$path."l");
        if (! $rightFirst) {
            $newright = GenerateStmBfromStmA($right,$stmnum,$path."r");
        }
        return "( $op $newleft $newright )";
    }
}

my $samples=0;
my %progs;
while ($samples < $numSamples) {
    $transform = "";
    # Evaluale all random settings for each sample
    foreach my $var (@rndevals) {
        eval $var;
    }
    if ($output_matrixes + $output_scalars + $output_vectors == 0) {
        $output_matrixes = 1;
    }
    # Randomize variables
    @{$nonTerm{'Matrix_id'}} = shuffle(@{$nonTerm{'Matrix_id'}});
    @{$nonTerm{'Scalar_id'}} = shuffle(@{$nonTerm{'Scalar_id'}});
    @{$nonTerm{'Vector_id'}} = shuffle(@{$nonTerm{'Vector_id'}});
    my $progA;
    my @outputs=();
    push @outputs, @{$nonTerm{'Matrix_id'}}[0..($output_matrixes-1)];
    push @outputs, @{$nonTerm{'Scalar_id'}}[0..($output_scalars-1)];
    push @outputs, @{$nonTerm{'Vector_id'}}[0..($output_vectors-1)];
    @outputs = shuffle(@outputs);
    # Leave last 3 IDs for possible temporaries
    my @scalar_avail = @{$nonTerm{'Scalar_id'}}[0..int(rand(-3 + scalar @{$nonTerm{'Scalar_id'}}))];
    my @vector_avail = @{$nonTerm{'Vector_id'}}[0..int(rand(-3 + scalar @{$nonTerm{'Vector_id'}}))];
    my @matrix_avail = @{$nonTerm{'Matrix_id'}}[0..int(rand(-3 + scalar @{$nonTerm{'Matrix_id'}}))];
    my @nxt_scalar_avail = ();
    my @nxt_vector_avail = ();
    my @nxt_matrix_avail = ();
    foreach my $out (@outputs) {
        $progA .= $out." === ";
        $progA .= CreateRHS($out,\@scalar_avail,\@vector_avail,\@matrix_avail,int($maxTokens/(6+scalar @outputs)));
    }
    foreach my $var (shuffle(@scalar_avail,@vector_avail,@matrix_avail)) {
        if ($progA =~ /=[^;]* $var /) {
            my $stmA = $var." = ";
            $stmA .= CreateRHS($var,\@scalar_avail,\@vector_avail,\@matrix_avail,int($maxTokens/(6+scalar @outputs)));
            $progA = $stmA.$progA;
        }
    }
    foreach my $var (@scalar_avail,@vector_avail,@matrix_avail) {
        my $live = $progA;
        while ($live =~ /^(.*)$var (=[^;]*);/) {
            $live = $1.$2;
        }
        if ($live =~/=[^;]* $var /) {
            $var =~ /^s(\d+)/ && (push @nxt_scalar_avail, $var);
            $var =~ /^v(\d+)/ && (push @nxt_vector_avail, $var);
            $var =~ /^m(\d+)/ && (push @nxt_matrix_avail, $var);
        }
    }
    @scalar_avail = @nxt_scalar_avail;
    @vector_avail = @nxt_vector_avail;
    @matrix_avail = @nxt_matrix_avail;
    foreach my $var (shuffle(@scalar_avail,@vector_avail,@matrix_avail)) {
        my $live = $progA;
        while ($live =~ /^(.*)$var (=[^;]*);/) {
            $live = $1.$2;
        }
        if ($live =~ /=[^;]* $var /) {
            if ($var =~ /^s(\d+)/) { 
                @nxt_scalar_avail = ();
                foreach my $v (@scalar_avail) {
                    if ($v ne $var) {
                        push (@nxt_scalar_avail,$v);
                    }
                }
            }
            if ($var =~ /^v(\d+)/) { 
                @nxt_vector_avail = ();
                foreach my $v (@vector_avail) {
                    if ($v ne $var) {
                        push (@nxt_vector_avail,$v);
                    }
                }
            }
            if ($var =~ /^m(\d+)/) { 
                @nxt_matrix_avail = ();
                foreach my $v (@matrix_avail) {
                    if ($v ne $var) {
                        push (@nxt_matrix_avail,$v);
                    }
                }
            }
            my $stmA = $var." = ";
            $stmA .= CreateRHS($var,\@nxt_scalar_avail,\@nxt_vector_avail,\@nxt_matrix_avail,int($maxTokens/(8+scalar @outputs)));
            $progA = $stmA.$progA;
        }
    }
    next if (scalar split / /,$progA) > $maxTokens;
    next if rand() < 0.5 && (scalar split / /,$progA) < int($maxTokens/3);
    next if rand() < 0.5 && (scalar split / /,$progA) < int($maxTokens/2);
    next if (scalar split /;/,$progA) > 16;
    next if $progA =~ /\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\(/;
    next if $progA =~ /\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)/;
    my $progTmp;
    next if exists $progs{$progA};
    $progs{$progA} = 1;

    my $progB = "";

    my $stmnum=1;
    if (rand() < 0.5) {
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            $progB .= "$1 $2 ";
            $stmA = $3;
            my $stmB = GenerateStmBfromStmA($stmA,$stmnum,"N");
            $progB .= "$stmB ; ";
            $stmnum+=1;
        }
    } else {
        $progB=$progA;
    }
    $progTmp = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-1], @{$nonTerm{'Vector_id'}}[-1], @{$nonTerm{'Matrix_id'}}[-1]);
    next if (scalar split /;/,$progTmp) > 26;
    $progB = "";
    $stmnum=1;
    foreach my $stmA (split /;/,$progTmp) {
        $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
        $progB .= "$1 $2 ";
        $stmA = $3;
        my $stmB = GenerateStmBfromStmA($stmA,$stmnum,"N");
        $stmB = GenerateStmBfromStmA($stmB,$stmnum,"N");
        $progB .= "$stmB ; ";
        $stmnum+=1;
    }
    $progTmp = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-2], @{$nonTerm{'Vector_id'}}[-2], @{$nonTerm{'Matrix_id'}}[-2]);
    next if (scalar split /;/,$progTmp) > 26;
    $progB = "";
    $stmnum=1;
    foreach my $stmA (split /;/,$progTmp) {
        $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
        $progB .= "$1 $2 ";
        $stmA = $3;
        my $stmB = GenerateStmBfromStmA($stmA,$stmnum,"N");
        $stmB = GenerateStmBfromStmA($stmB,$stmnum,"N");
        $progB .= "$stmB ; ";
        $stmnum+=1;
    }
    # 50% of the time, finish last steps with interaxiom (otherwise was expression)
    if (rand() < 0.5) {
        $progB = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-3], @{$nonTerm{'Vector_id'}}[-3], @{$nonTerm{'Matrix_id'}}[-3]);
    }
    next if $progB eq $progA;
    next if (scalar split / /,$progB) > $maxTokens;
    next if (scalar split /;/,$progB) > 16;
    next if $progB =~ /\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\([^)]*\(/;
    next if $progB =~ /\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)[^(]*\)/;
    print "X $progA","Y $progB","Z $transform\n";
    # $progA =~ s/;/; \n/g;
    # $progB =~ s/;/; \n/g;
    # print "progA: \n $progA\n";
    # print "progB: \n $progB\n";
    # print "transform: $transform\n";
    # print "----------------------------------------\n";
    $samples += 1;
}
