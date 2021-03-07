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
            $stm =~ s/^\( //;
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
           @tmplist=("Om","Im");
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
    while ((scalar @tmplist > 1) && ((scalar @tmplist) > int(rand($max_tokens))+1)) {
        @tmplist = @{$nonTerm{$expr_type}};
        @tmplist = split / /,($tmplist[ rand @tmplist ]);
    }
    my $retval="";
    foreach my $expr (@tmplist) {
        if ($nonTerm{$expr}) {
            $retval .= ExpandNonTerm($expr,\@scalar_avail,\@vector_avail,\@matrix_avail,$max_tokens - scalar @tmplist)." ";
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
    $assign .= " ; \n ";
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
    if (rand() < 0.4) {
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if (rand()<0.2 && $eqPrev && ! ($rhsPrev =~ /$lhs/) && ! ($rhs =~ /$lhsPrev/)) {
                $transform .= "stm$stmnum Swapprev ";
                $progB .= "$lhs $eq $rhs ; \n ";
            } else {
                if ($lhsPrev) {
                    $progB .= "$lhsPrev $eqPrev $rhsPrev ; \n ";
                }
                $lhsPrev = $lhs;
                $eqPrev = $eq;
                $rhsPrev = $rhs;
            }
            $stmnum++;
        }
        $progB .= "$lhsPrev $eqPrev $rhsPrev ; \n ";
        $progA = $progB;
    }

    # Possibly inline a variable
    if (rand() < 0.3 && $DoInline) {
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
            $progB .= "$lhs $eq $rhs ; \n ";
            $stmnum++;
        }
        $progA = $progB;
    }
    
    # Possibly delete dead code (unused variable assign)
    if (rand() < 0.8 && $DoInline) {
        my %vars;
        $progB = "";
        $stmnum=1;
        print "DBG: $progA\n";
        while ($progA =~ s/^([^;]+); \n //) {
            my $stmA = $1;
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || die "Illegal statement in dead code check: $stmA\n"; 
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($progA =~/$lhs/ || $eq eq "===") {
                $progB .= "$lhs $eq $rhs ; \n ";
            } else {
                $transform .= "stm$stmnum Deletestm ";
                last;
            }
            $stmnum++;
        }
        $progA = $progB.$progA;
    }
    
    # Check for possible new variables
    if (rand() < 0.8 && !$DoInline) {
        my %expr;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~ s/^\s*\S+ =+ //;
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) \( ([^()]+) \) \)/ ( )/) {
                $expr{"$1 ( $2 ) ( $3 )"}+=3;
                $expr{$2}+=2;
                $expr{$3}+=2;
            }
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) ([^()]+) \)/ ( )/) {
                $expr{"$1 ( $2 ) $3"}+=3;
                $expr{$2}+=2;
            }
            while ($stmA =~s/ \( ([^()]+) \( ([^()]+) \) \)/ ( )/) {
                $expr{"$1 ( $2 )"}+=3;
                $expr{$2}+=2;
            }
            while ($stmA =~s/ \( ([^()]+) \)/ ( )/) {
                $expr{$1}+=2;
            }
        }
        my $stmnum=1;
        $progB="";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S.*)$/ || next;
            $stmA = $1;
            foreach my $key (shuffle(keys %expr)) {
                if (rand() < (0.7-2.1/$expr{$key})) {
                    my $var="";
                    $key =~/^.s / && ($var=$tmpscalar);
                    $key =~/^.v / && ($var=$tmpvector);
                    $key =~/^.m / && ($var=$tmpmatrix);
                    if (! ($stmA =~/= \( \Q$key\E \) *$/) && ($stmA =~ s/\( \Q$key\E \)/$var/g)) {
                        my $path = FindPath($stmA,$var);
                        %expr=();
                        $transform .= "stm$stmnum Newtmp N$path $var ";
                        $progB .= "$var = ( $key ) ; \n ";
                        last;
                    }
                }
            }
            $progB .= $stmA."; \n ";
            $stmnum++;
        }
        $progA = $progB;
    }

    # Possibly replace statement with lexically equivalent variable
    if (rand() < 0.8 && !$DoInline) {
        my %vars;
        $progB = "";
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            foreach my $var (shuffle(keys %vars)) {
                if (rand()<0.4 && ($rhs =~ s/\Q$vars{$var}\E/$var/g)) {
                    $transform .= "stm$stmnum Usevar $var ";
                    last;
                }
            }
            if (! ($rhs =~/\(.*\(.*\(.*\(/) && ($rhs =~/\(/) && $eq ne "===" && ! ($rhs =~/$lhs/)) {
                $vars{$lhs}=$rhs;
            } else {
                delete $vars{$lhs};
            }
            $progB .= "$lhs $eq $rhs ; \n ";
            $stmnum++;
        }
        $progA = $progB;
    }
    return $progA;
}

sub GenerateStmBfromStmA {
    my $progA = $_[0];
    my $path = $_[1];

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
        $transform .= $path."l Cancel ";
        if ($right ne "") {
            if ($leftop eq "-s") {
                return GenerateStmBfromStmA("( $op 0s $right )",$path);
            } else {
                return GenerateStmBfromStmA("( $op 1s $right )",$path);
            }
        } else {
            if ($leftop eq "-s") {
                return GenerateStmBfromStmA("( $op 0s )",$path);
            } else {
                return GenerateStmBfromStmA("( $op 1s )",$path);
            }
        }
    }

    if (rand() < 0.2 && ($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= $path."r Cancel ";
        if ($rightop eq "-s") {
            return GenerateStmBfromStmA("( $op $left 0s )",$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 1s )",$path);
        }
    }

    if (rand() < 0.2 && ($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $axioms =~/Cancel/) {
        $transform .= $path."l Cancel ";
        if ($right ne "") {
            if ($leftop eq "-m") {
                return GenerateStmBfromStmA("( $op 0m $right )",$path);
            } else {
                return GenerateStmBfromStmA("( $op 0v $right )",$path);
            }
        } else {
            if ($leftop eq "-m") {
                return GenerateStmBfromStmA("( $op 0m )",$path);
            } else {
                return GenerateStmBfromStmA("( $op 0v )",$path);
            }
        }
    }

    if (rand() < 0.2 && ($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= $path."r Cancel ";
        if ($rightop eq "-m") {
            return GenerateStmBfromStmA("( $op $left 0m )",$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 0v )",$path);
        }
    }

    if (rand() < 0.2 && $op eq "*m" && $axioms =~/Cancel/ && 
                     (($leftleft eq $right && $leftop eq "im") ||
                      ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= $path." Cancel ";
        return "I";
    }

    if (rand() < 0.2 && (($op eq "+s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "-s" && $right eq "0s") ||
                         ($op =~ /\*./ && ($left eq "1s" || $right eq "1s")) ||
                         ($op =~ "/s" && $right eq "1s")) && $axioms =~/Noop/) {
        $transform .= $path." Noop ";
        if ($left eq "0s" || $left eq "1s") {
            return GenerateStmBfromStmA($right,$path);
        } else {
            return GenerateStmBfromStmA($left,$path);
        }
    }

    if (rand() < 0.2 && (($op eq "+m" && ($left eq "0m" || $right eq "0m")) ||
                         ($op eq "-m" && $right eq "0m")) && $axioms =~/Noop/) {
        $transform .= $path." Noop ";
        if ($left eq "0m") {
            return GenerateStmBfromStmA($right,$path);
        } else {
            return GenerateStmBfromStmA($left,$path);
        }
    }

    if (rand() < 0.2 && $op eq "*m" && (($left eq "Im" && ($rightop =~ /.m/ || $right =~ /^([0I]m|m\d+)/)) || ($right eq "Im" && ($leftop =~ /.m/ || $left =~ /^([0I]m|m\d+)/))) && $axioms =~/Noop/) {
        $transform .= $path." Noop ";
        if ($left eq "Im") {
            return GenerateStmBfromStmA($right,$path);
        } else {
            return GenerateStmBfromStmA($left,$path);
        }
    }

    if (rand() < 0.2 && (($op eq "+v" && ($left eq "0v" || $right eq "0v")) ||
                         ($op eq "-v" && $right eq "0v")) && $axioms =~/Noop/) {
        $transform .= $path." Noop ";
        if ($left eq "0v") {
            return GenerateStmBfromStmA($right,$path);
        } else {
            return GenerateStmBfromStmA($left,$path);
        }
    }

    if (rand() < 0.2 && (($op eq "*s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "/s" && $left eq "0s")) && $axioms =~/Multzero/) {
        $transform .= $path." Multzero ";
        return "0s";
    }

    if (rand() < 0.2 && ($op eq "*m" && ($left eq "0m" || $right eq "0m" || $left eq "0s" || $right eq "0s"))
                        && $axioms =~/Multzero/) {
        $transform .= $path." Multzero ";
        return "0m";
    }

    if (rand() < 0.2 && ($op eq "*v" && ($left =~/^[oO0]/ || $right =~/^[oO0]/))
                        && $axioms =~/Multzero/) {
        $transform .= $path." Multzero ";
        return "0v";
    }

    if (rand() < 0.25 && ($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= $path." Distribleft ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $leftleft $right )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        $leftop =~s/.$/m/;
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.25 && ($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= $path." Distribright ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$path."r");
        }
        $rightop =~s/.$/m/;
        return "( $rightop $newleft $newright )";
    }

    if (rand() < 0.25 && ($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $axioms =~/Distribleft/) {
        $transform .= $path." Distribleft ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $leftleft $right )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.25 && ($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $axioms =~/Distribright/) {
        $transform .= $path." Distribright ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $left $rightright )",$path."r");
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
            $transform .= $path." Factorleft ";
            if ($rightFirst) {
                $newright= GenerateStmBfromStmA("( $op $leftright $rightright )",$path."r");
            }
            $newleft = GenerateStmBfromStmA("$leftleft",$path."l");
            if (! $rightFirst) {
                $newright= GenerateStmBfromStmA("( $op $leftright $rightright )",$path."r");
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
            $transform .= $path." Factorright ";
            if ($rightFirst) {
                $newright= GenerateStmBfromStmA("$rightright",$path."r");
            }
            $newleft = GenerateStmBfromStmA("( $op $leftleft $rightleft )",$path."l");
            if (! $rightFirst) {
                $newright= GenerateStmBfromStmA("$rightright",$path."r");
            }
            return "( $leftop $newleft $newright )";
        }
    }

    if (rand() < 0.25 && $op =~/\*./ && $rightop =~ /\*./ && $axioms =~/Assocleft/) {
        $transform .= $path." Assocleft ";
        if (($leftop =~ /.s/ || $left =~/^([01]s|s\d+)/) && ($rightleft =~/^. .s/ || $rightleft =~/^([01]s|s\d+)/)) {
          $leftop = "*s";
        } elsif ($leftop =~ /.v/ || $left =~/^(0v|v\d+)/ || $rightleft =~/^. .v/ || $rightleft =~/^(0v|v\d+)/) {
          $leftop = "*v";
        } else {
          $leftop = "*m";
        }
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $leftop $left $rightleft )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$path."r");
        }
        return "( $op $newleft $newright )";
    }

    if (rand() < 0.25 && 
             (($op =~/\+./ && $rightop =~/[\-+]./) || 
              ($op =~ /\*s/ && $rightop eq "/s")) &&
             $axioms =~/Assocleft/) {
        $transform .= $path." Assocleft ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$path."r");
        }
        $newleft = GenerateStmBfromStmA("( $op $left $rightleft )",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$rightright",$path."r");
        }
        return "( $rightop $newleft $newright )";
    }

    if (rand() < 0.25 && $op =~/\*./ && $leftop =~ /\*./ && $axioms =~/Assocright/) {
        $transform .= $path." Assocright ";
        if (($rightop =~ /.s/ || $right =~/^([01]s|s\d+)/) && ($leftright =~/^. .s/ || $leftright =~/^([01]s|s\d+)/)) {
          $rightop = "*s";
        } elsif ($rightop =~ /.v/ || $right =~/^(0v|v\d+)/ || $leftright =~/^. .v/ || $leftright =~/^(0v|v\d+)/) {
          $rightop = "*v";
        } else {
          $rightop = "*m";
        }
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $rightop $leftright $right )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $rightop $leftright $right )",$path."r");
        }
        return "( $op $newleft $newright )";
    }
  
    if (rand() < 0.25 && 
             (($op =~/[\-+]./ && $leftop =~/\+./) || 
              ($op eq "/s" && $leftop =~/\*s/)) &&
             $axioms =~/Assocright/) {
        $transform .= $path." Assocright ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("( $op $leftright $right )",$path."r");
        }
        return "( $leftop $newleft $newright )";
    }
  
    if (rand() < 0.25 && (($op eq "nv" && $leftop eq "-v") ||
                         ($op eq "ns" && $leftop eq "-s") ||
                         ($op eq "is" && $leftop eq "/s") ||
                         ($op eq "nm" && $leftop eq "-m")) && $axioms =~/Flipleft/) {
        $transform .= $path." Flipleft ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$path."r");
        }
        $newleft = GenerateStmBfromStmA("$leftright",$path."l");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$path."r");
        }
        return "( $leftop $newleft $newright )";
    }

    if (rand() < 0.25 && (($op eq "-s" && $rightop =~/[\-n]s/) ||
                         ($op eq "/s" && $rightop =~/[\/i]s/) ||
                         ($op eq "-m" && $rightop =~/[\-n]m/) ||
                         ($op eq "-v" && $rightop =~/[\-n]v/)) && $axioms =~/Flipright/) {
        $transform .= $path." Flipright ";
        $newop = $op;
        $newop =~s/\-/\+/;
        $newop =~s/\//\*/;
        if (! $rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$path."l");
        }
        if ($op eq $rightop) {
            $newright= GenerateStmBfromStmA("( $op $rightright $rightleft )",$path."r");
        } else {
            $newright= GenerateStmBfromStmA("$rightleft",$path."r");
        }
        if ($rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$path."l");
        }
        return "( $newop $newleft $newright )";
    }
    if (rand() < 0.1 && $op eq "*m" && $axioms =~/Transpose/) {
        $transform .= $path." Transpose ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$left",$path."lrl");
        }
        $newleft = GenerateStmBfromStmA("$right",$path."lll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$left",$path."lrl");
        }
        # Scalar values are allowed, but they don't transpose
        if (($newleft =~ /^m\d/) || ($newleft =~ /^\( .m/)) {
            $newleft = "( tm $newleft )";
        }
        if (($newright =~ /^m\d/) || ($newright =~ /^\( .m/)) {
            $newright = "( tm $newright )";
        }
        return "( tm ( *m $newleft $newright ) )";
    }
    if (rand() < 0.1 && (($op eq "-m") || ($op eq "+m")) && $axioms =~/Transpose/) {
        $transform .= $path." Transpose ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$right",$path."lrl");
        }
        $newleft = GenerateStmBfromStmA("$left",$path."lll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$right",$path."lrl");
        }
        return "( tm ( $op ( tm $newleft ) ( tm $newright ) ) )";
    }
    if (rand() < 0.25 && ($op eq "tm") && ($leftop eq "*m") && $axioms =~/Transpose/) {
        $transform .= $path." Transpose ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$path."rl");
        }
        $newleft = GenerateStmBfromStmA("$leftright",$path."ll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$leftleft",$path."rl");
        }
        # Scalar values are allowed, but they don't transpose
        if (($newleft =~ /^m\d/) || ($newleft =~ /^\( .m/)) {
            $newleft = "( tm $newleft )";
        }
        if (($newright =~ /^m\d/) || ($newright =~ /^\( .m/)) {
            $newright = "( tm $newright )";
        }
        return "( *m $newleft $newright )";
    }
    if (rand() < 0.25 && ($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $axioms =~/Transpose/) {
        $transform .= $path." Transpose ";
        if ($rightFirst) {
            $newright= GenerateStmBfromStmA("$leftright",$path."rl");
        }
        $newleft = GenerateStmBfromStmA("$leftleft",$path."ll");
        if (! $rightFirst) {
            $newright= GenerateStmBfromStmA("$leftright",$path."rl");
        }
        return "( $leftop ( tm $newleft ) ( tm $newright ) )";
    }
    if ($right eq "") {
        if (rand() < 0.25 && ($leftop eq $op) && $axioms =~/Double/) {
            $transform .= $path." Double ";
            return GenerateStmBfromStmA($leftleft,$path);
        } else {
            $newleft = GenerateStmBfromStmA($left,$path."l");
        }
        return "( $op $newleft )";
    }

    if ($op =~/-./ || $op eq "/s" || 
            ($op eq "*m" && !($leftop =~ /^.s/ || $left =~ /^([01][ms]|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01][ms]|s\d+)/)) ||
            ($op eq "*v" && !($leftop =~ /^.s/ || $left =~ /^([01]s|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01]s|s\d+)/))) {
        $dont_commute = 1;
    }
    if (rand() < 0.05 && !$dont_commute && $left ne $right && $axioms =~/Commute/) {
        $transform .= $path." Commute ";
        if ($rightFirst) {
            $newright = GenerateStmBfromStmA($left,$path."r");
        }
        $newleft = GenerateStmBfromStmA($right,$path."l");
        if (! $rightFirst) {
            $newright = GenerateStmBfromStmA($left,$path."r");
        }
        return "( $op $newleft $newright )";
    } else {
        if ($rightFirst) {
            $newright = GenerateStmBfromStmA($right,$path."r");
        }
        $newleft = GenerateStmBfromStmA($left,$path."l");
        if (! $rightFirst) {
            $newright = GenerateStmBfromStmA($right,$path."r");
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
        $progA .= CreateRHS($out,\@scalar_avail,\@vector_avail,\@matrix_avail,int($maxTokens/(4+scalar @outputs)));
    }
    foreach my $var (shuffle(@scalar_avail,@vector_avail,@matrix_avail)) {
        if ($progA =~ /=[^;]* $var /) {
            my $stmA = $var." = ";
            $stmA .= CreateRHS($var,\@scalar_avail,\@vector_avail,\@matrix_avail,int($maxTokens/(4+scalar @outputs)));
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
            $stmA .= CreateRHS($var,\@nxt_scalar_avail,\@nxt_vector_avail,\@nxt_matrix_avail,int($maxTokens/(6+scalar @outputs)));
            $progA = $stmA.$progA;
        }
    }
    my $used = scalar split /[ ()]+/,$progA;
    next if $used > $maxTokens;
    my $progTmp;
    next if exists $progs{$progA};

    my $progB = "";

    my $stmnum=1;
    foreach my $stmA (split /;/,$progA) {
        $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
        $progB .= "$1 $2 ";
        $stmA = $3;
        my $stmB = GenerateStmBfromStmA($stmA,"stm$stmnum N");
        $progB .= "$stmB ; \n ";
        $stmnum+=1;
    }
    $progTmp = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-1], @{$nonTerm{'Vector_id'}}[-1], @{$nonTerm{'Matrix_id'}}[-1]);
    $progB = "";
    $stmnum=1;
    foreach my $stmA (split /;/,$progTmp) {
        $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
        $progB .= "$1 $2 ";
        $stmA = $3;
        my $stmB = GenerateStmBfromStmA($stmA,"stm$stmnum N");
        $stmB = GenerateStmBfromStmA($stmB,"stm$stmnum N");
        $progB .= "$stmB ; \n ";
        $stmnum+=1;
    }
    $progB = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-2], @{$nonTerm{'Vector_id'}}[-2], @{$nonTerm{'Matrix_id'}}[-2]);
    next if $progB eq $progA;
    next if (scalar split /[ ()]+/,$progB) > $maxTokens;
    print "progA: \n $progA\n";
    print "progB: \n $progB\n";
    print "transform: $transform\n";
    print "----------------------------------------\n";
    $samples += 1;
}
