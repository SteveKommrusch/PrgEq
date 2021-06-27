#!/usr/bin/perl
#
use List::Util qw(shuffle);
use strict;
use warnings;
use List::Util qw(min);

if (! -f $ARGV[0]) {
  print "Usage: usetemplate.pl configFile templatefile\n";
  print "  Create input and output files for program equivalence checking.\n";
  print "  This full version generates equations with scalars, vectors and\n";
  print "  matrices, simple operators (+,-,*,/,invert,negate,transpose) and functions.\n";
  print "  Operators are typed as scalar, matrix, or vector, resulting in this list:\n";
  print "     +s -s *s /s is ns +m -m *m im nm tm +v -v *v nv\n";
  print " Example:\n";
  print "  ../src/usetemplate.pl vsf2/straightline.txt VRepair_templates.txt\n";
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
my $min_out;
my $max_out;
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
        die "No expansion rule for $expr_type";
    }
    @tmplist = @{$nonTerm{$expr_type}};
    @tmplist = split / /,($tmplist[ rand @tmplist ]);
    while ((scalar @tmplist > 1) && (rand($max_tokens) < 1.0)) {
        @tmplist = @{$nonTerm{$expr_type}};
        @tmplist = split / /,($tmplist[ rand @tmplist ]);
    }
    my $retval="";
    foreach my $expr (@tmplist) {
        if ($nonTerm{$expr}) {
            my $expand = ExpandNonTerm($expr,\@scalar_avail,\@vector_avail,\@matrix_avail,int(($max_tokens - 1)/(scalar @tmplist < 3 ? 1 : 2 )))." ";
            # Try again if we created a trivial expression
            if (rand() < 0.6 && ($expand =~ /^\( [-\/]. (\S+) \1 /)) {
                $expand = ExpandNonTerm($expr,\@scalar_avail,\@vector_avail,\@matrix_avail,int(($max_tokens - 1)/(scalar @tmplist < 3 ? 1 : 2 )))." ";
            }
            $retval .= $expand;
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
    if (rand() < 0.2 && $axioms =~/Swapprev/) {
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
    if (rand() < 0.2 && $DoInline && $axioms =~/Inline/) {
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
            foreach my $var (keys %vars) {
                if ($vars{$var} =~/$lhs/) {
                    delete $vars{$var};
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
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || die "Illegal statement in dead code check: $stmA"; 
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
            while ($stmA =~s/\( ([^()]+) \( ([^()]+) \) \( ([^()]+) \) \)//) {
                $expr{"$1 ( $2 ) ( $3 )"}+=6;
                $expr{$2}+=3;
                $expr{$3}+=3;
            }
            while ($stmA =~s/\( ([^()]+) \( ([^()]+) \) ([^()]+) \)//) {
                $expr{"$1 ( $2 ) $3"}+=5;
                $expr{$2}+=3;
            }
            while ($stmA =~s/\( ([^()]+) \( ([^()]+) \) \)//) {
                $expr{"$1 ( $2 )"}+=4;
                $expr{$2}+=3;
            }
            while ($stmA =~s/\( ([^()]+) \)//) {
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
                    $key =~/^\S+s/ && ($var=$tmpscalar);
                    $key =~/^\S+v/ && ($var=$tmpvector);
                    $key =~/^\S+m/ && ($var=$tmpmatrix);
                    if ((!($stmA =~/= \( \Q$key\E \) *$/) || (rand() < 0.2)) && ($stmA =~ s/\( \Q$key\E \)/$var/g)) {
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
    } elsif (rand() < 0.1 && $axioms =~/Rename/) {
        # Possibly rename a variable
        my $var="";
        my $rename="";
        $progB = "";
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if (!$rename && $eq eq "=" && rand() < 0.03 + ($stmnum*0.003)) {
                $lhs =~/^s/ && ($var=$tmpscalar);
                $lhs =~/^v/ && ($var=$tmpvector);
                $lhs =~/^m/ && ($var=$tmpmatrix);
                $transform .= "stm$stmnum Rename $var ";
                $rename=$lhs;
                $lhs = $var;
            } elsif ($rename && $var) {
                $rhs=~s/$rename/$var/g;
                if ($lhs eq $rename) {
                    # Stop replacement after variable seen again
                    $var="";
                }
            }
            $progB .= "$lhs $eq $rhs ; ";
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

    if (rand() < 0.0015 && $axioms =~/Multone/) {
        $transform .= "stm$stmnum Multone ${path} ";
        if ($progA =~/^s\d/ || $progA=~/^\ds/ || $progA=~/^\( \S+s /) {
            $progA="( *s 1s $progA )";
        } elsif ($progA =~/^v\d/ || $progA=~/^\dv/ || $progA=~/^\( \S+v /) {
            $progA="( *v 1s $progA )";
        } elsif ($progA =~/^m\d/ || $progA=~/^\dm/ || $progA=~/^\( \S+m /) {
            $progA="( *m 1s $progA )";
        }
    }
    if (rand() < 0.001 && $axioms =~/Addzero/) {
        $transform .= "stm$stmnum Addzero ${path} ";
        if ($progA =~/^s\d/ || $progA=~/^\ds/ || $progA=~/^\( \S+s /) {
            $progA="( +s 0s $progA )";
        } elsif ($progA =~/^v\d/ || $progA=~/^\dv/ || $progA=~/^\( \S+v /) {
            $progA="( +v 0v $progA )";
        } elsif ($progA =~/^m\d/ || $progA=~/^\dm/ || $progA=~/^\( \S+m /) {
            $progA="( +m 0m $progA )";
        }
    }
    if (rand() < 0.0005 && $axioms =~/Divone/) {
        if ($progA =~/^s\d/ || $progA=~/^\ds/ || $progA=~/^\( \S+s /) {
            $transform .= "stm$stmnum Divone ${path} ";
            $progA="( /s $progA 1s )";
        }
    }
    if (rand() < 0.0005 && $axioms =~/Subzero/) {
        $transform .= "stm$stmnum Subzero ${path} ";
        if ($progA =~/^s\d/ || $progA=~/^\ds/ || $progA=~/^\( \S+s /) {
            $progA="( -s $progA 0s )";
        } elsif ($progA =~/^v\d/ || $progA=~/^\dv/ || $progA=~/^\( \S+v /) {
            $progA="( -v $progA 0v )";
        } elsif ($progA =~/^m\d/ || $progA=~/^\dm/ || $progA=~/^\( \S+m /) {
            $progA="( -m $progA 0m )";
        }
    }
    $progA =~s/^\( (\S+) // || return $progA;
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

    if ($progA =~s/^\( (\S+) //) {
        $in=1;
        $left = "( ".$1." ";
        $leftop = $1;
        my $leftdone=0;
        my $loopcnt = 0;
        while ($in >0) {
            $loopcnt++ > 100 && die "Infinite loop with $_[0], transform = $transform";
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

    if ($progA =~s/^\s*\( (\S+) //) {
        $in=1;
        $right = "( ".$1." ";
        $rightop = $1;
        my $leftdone=0;
        my $loopcnt = 0;
        while ($in >0) {
            $loopcnt++ > 100 && die "Infinite loop with $_[0], transform = $transform";
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

    if (rand() < 0.25 && ($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $axioms =~/Cancel/) {
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

    if (rand() < 0.25 && ($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}r ";
        if ($rightop eq "-s") {
            return GenerateStmBfromStmA("( $op $left 0s )",$stmnum,$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 1s )",$stmnum,$path);
        }
    }

    if (rand() < 0.25 && ($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $axioms =~/Cancel/) {
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

    if (rand() < 0.25 && ($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $axioms =~/Cancel/) {
        $transform .= "stm$stmnum Cancel ${path}r ";
        if ($rightop eq "-m") {
            return GenerateStmBfromStmA("( $op $left 0m )",$stmnum,$path);
        } else {
            return GenerateStmBfromStmA("( $op $left 0v )",$stmnum,$path);
        }
    }

    if (rand() < 0.25 && $op eq "*m" && $axioms =~/Cancel/ && 
                     (($leftleft eq $right && $leftop eq "im") ||
                      ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= "stm$stmnum Cancel ${path} ";
        return "Im";
    }

    if (rand() < 0.10 && (($op eq "+s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "-s" && $right eq "0s")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "0s") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.10 && (($op =~ /\*./ && ($left eq "1s" || $right eq "1s")) ||
                         ($op =~ "/s" && $right eq "1s")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "1s") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.10 && (($op eq "+m" && ($left eq "0m" || $right eq "0m")) ||
                         ($op eq "-m" && $right eq "0m")) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "0m") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.10 && $op eq "*m" && (($left eq "Im" && ($rightop =~ /m$/ || $right =~ /^([0I]m|m\d+)/)) || ($right eq "Im" && ($leftop =~ /m$/ || $left =~ /^([0I]m|m\d+)/))) && $axioms =~/Noop/) {
        $transform .= "stm$stmnum Noop ${path} ";
        if ($left eq "Im") {
            return GenerateStmBfromStmA($right,$stmnum,$path);
        } else {
            return GenerateStmBfromStmA($left,$stmnum,$path);
        }
    }

    if (rand() < 0.10 && (($op eq "+v" && ($left eq "0v" || $right eq "0v")) ||
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

    if (rand() < 0.2 && ($op eq "*m") && ($leftop =~/\+/ || $leftop =~/-/) && $axioms =~/Distribleft/) {
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

    if (rand() < 0.2 && ($op eq "*m") && ($rightop =~/\+/ || $rightop =~/-/) && $axioms =~/Distribright/) {
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

    if (rand() < 0.2 && ($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+/ || $leftop =~/-/) && $axioms =~/Distribleft/) {
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

    if (rand() < 0.2 && ($op =~/\*[vs]/) && ($rightop =~/\+/ || $rightop =~/-/) && $axioms =~/Distribright/) {
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

    if (rand() < 0.3 && ($op =~/[\+\-]/) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*/) && $axioms =~/Factorleft/) {
        my $typematch=0;
        if (($rightright =~/^\( \S+s / || $rightright =~/^([01]s|s\d+)/) &&
            ($leftright =~/^\( \S+s / || $leftright =~/^([01]s|s\d+)/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightright =~/^\( \S+m / || $rightright =~/^([0I]m|m\d+)/) &&
            ($leftright =~/^\( \S+m / || $leftright =~/^([0I]m|m\d+)/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightright =~/^\( \S+v / || $rightright =~/^(0v|v\d+)/) &&
            ($leftright =~/^\( \S+v / || $leftright =~/^(0v|v\d+)/)) {
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

    if (rand() < 0.3 && ($op =~/[\+\-]/) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]/) && $axioms =~/Factorright/) {
        my $typematch=0;
        if (($rightleft =~/^\( \S+s / || $rightleft =~/^([01]s|s\d+)/) &&
            ($leftleft =~/^\( \S+s / || $leftleft =~/^([01]s|s\d+)/)) {
            $typematch=1;
            $op =~s/.$/s/;
        } elsif (($rightleft =~/^\( \S+m / || $rightleft =~/^([0I]m|m\d+)/) &&
            ($leftleft =~/^\( \S+m / || $leftleft =~/^([0I]m|m\d+)/)) {
            $typematch=1;
            $op =~s/.$/m/;
        } elsif (($rightleft =~/^\( \S+v / || $rightleft =~/^(0v|v\d+)/) &&
            ($leftleft =~/^\( \S+v / || $leftleft =~/^(0v|v\d+)/)) {
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

    if (rand() < 0.15 && $op =~/\*/ && $rightop =~ /\*/ && $axioms =~/Assocleft/) {
        $transform .= "stm$stmnum Assocleft ${path} ";
        if (($leftop =~ /.s/ || $left =~/^([01]s|s\d+)/) && ($rightleft =~/^. \S+s/ || $rightleft =~/^([01]s|s\d+)/)) {
          $leftop = "*s";
        } elsif ($leftop =~ /.v/ || $left =~/^(0v|v\d+)/ || $rightleft =~/^. \S+v/ || $rightleft =~/^(0v|v\d+)/) {
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

    if (rand() < 0.15 && 
             (($op =~/\+/ && $rightop =~/[\-+]/) || 
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

    if (rand() < 0.15 && $op =~/\*/ && $leftop =~ /\*/ && $axioms =~/Assocright/) {
        $transform .= "stm$stmnum Assocright ${path} ";
        if (($rightop =~ /.s/ || $right =~/^([01]s|s\d+)/) && ($leftright =~/^. \S+s/ || $leftright =~/^([01]s|s\d+)/)) {
          $rightop = "*s";
        } elsif ($rightop =~ /.v/ || $right =~/^(0v|v\d+)/ || $leftright =~/^. \S+v/ || $leftright =~/^(0v|v\d+)/) {
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
  
    if (rand() < 0.15 && 
             (($op =~/[\-+]/ && $leftop =~/\+/) || 
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

    if (rand() < 0.25 && (($op eq "-s") ||
                         ($op eq "/s") ||
                         ($op eq "-m") ||
                         ($op eq "-v")) && ($rightop eq $op) && $axioms =~/Flipright/) {
        $transform .= "stm$stmnum Flipright ${path} ";
        $newop = $op;
        $newop =~tr#\-+*/#+\-/*#;
        if (! $rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."l");
        }
        $newright= GenerateStmBfromStmA("( $op $rightright $rightleft )",$stmnum,$path."r");
        if ($rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."l");
        }
        return "( $newop $newleft $newright )";
    }

    if (rand() < 0.01 && (($op eq "+s") ||
                         ($op eq "*s") ||
                         ($op eq "+m") ||
                         ($op eq "+v") ||
             (($rightop ne $op) && (($op eq "-s") ||
                                     ($op eq "/s") ||
                                     ($op eq "-m") ||
                                     ($op eq "-v")))) && $axioms =~/Flipright/) {
        $transform .= "stm$stmnum Flipright ${path} ";
        $newop = $op;
        $newop =~tr#\-+*/#+\-/*#;
        if (! $rightFirst) {
            $newleft = GenerateStmBfromStmA("$left",$stmnum,$path."l");
        }
        if (($rightop =~/(nv|nm)/) ||
            (($op=~/[+\-]s/) && ($rightop eq "ns")) ||
            (($op=~/[*\/]s/) && ($rightop eq "is"))) {
            $newright= GenerateStmBfromStmA("$rightleft",$stmnum,$path."r");
        } else {
            if (($op eq "+s") || ($op eq "-s")) { $newright = "( ns $right )" }
            if (($op eq "*s") || ($op eq "/s")) { $newright = "( is $right )" }
            if (($op eq "+v") || ($op eq "-v")) { $newright = "( nv $right )" }
            if (($op eq "+m") || ($op eq "-m")) { $newright = "( nm $right )" }
            $newright= GenerateStmBfromStmA("$newright",$stmnum,$path."r");
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
            if (($left =~ /^m\d/) || ($left =~ /^\( \S+m/)) {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lrl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$left",$stmnum,$path."lr");
            }
        }
        if (($right =~ /^m\d/) || ($right =~ /^\( \S+m/)) {
            $newleft = GenerateStmBfromStmA("$right",$stmnum,$path."lll");
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenerateStmBfromStmA("$right",$stmnum,$path."ll");
        }
        if (! $rightFirst) {
            if (($left =~ /^m\d/) || ($left =~ /^\( \S+m/)) {
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
            if (($leftleft =~ /^m\d/) || ($leftleft =~ /^\( \S+m/)) {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."rl");
                $newright = "( tm $newright )";
            } else {
                $newright= GenerateStmBfromStmA("$leftleft",$stmnum,$path."r");
            }
        }
        if (($leftright =~ /^m\d/) || ($leftright =~ /^\( \S+m/)) {
            $newleft = GenerateStmBfromStmA("$leftright",$stmnum,$path."ll");
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenerateStmBfromStmA("$leftright",$stmnum,$path."l");
        }
        if (! $rightFirst) {
            if (($leftleft =~ /^m\d/) || ($leftleft =~ /^\( \S+m/)) {
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

    if ($op =~/^[\-fghuv]/ || $op eq "/s" || 
            ($op eq "*m" && !($leftop =~ /.s/ || $left =~ /^([01][ms]|s\d+)/ || $rightop =~ /.s/ || $right =~ /^([01][ms]|s\d+)/)) ||
            ($op eq "*v" && !($leftop =~ /.s/ || $left =~ /^([01]s|s\d+)/ || $rightop =~ /.s/ || $right =~ /^([01]s|s\d+)/))) {
        $dont_commute = 1;
    }
    if (rand() < 0.03 && !$dont_commute && $left ne $right && $axioms =~/Commute/) {
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

sub NextArgs {
    # Input is remainder of line after "fn ( " was processed
    my $line = $_[0];

    my $in=1;
    my $arg1="";
    if ($line=~s/^([^(), fu]+) ([),]) //) {
      $arg1=$1;
      if ($2 eq ")") {
        return ($arg1,"",$line);
      }
      $in=0;
    }
    while ($in > 0) {
      if ($line=~s/^\( //) {
        $arg1 .= "( ";
        $in++;
      }
      if ($line=~s/^([^(),]+ )//) {
        $arg1 .= $1;
      }
      if ($line=~s/^\) //) {
        $in--;
        if ($in > 0) {
          $arg1 .= ") ";
        } else {
          $arg1 =~s/ $//;
          return ($arg1,"",$line);
        }
      } elsif ($line=~s/^, //) {
        if ($in > 1) {
          $arg1 .= ", ";
        } else {
          $in=0;
        }
      }
    }
    $arg1 =~s/ $//;
    my $arg2="";
    $in=1;
    if ($line=~s/^([^(), fu]+) ([),]) //) {
      $arg2=$1;
      $in=0;
    }
    while ($in > 0) {
      if ($line=~s/^\( //) {
        $arg2 .= "( ";
        $in++;
      }
      if ($line=~s/^([^()]+ )//) {
        $arg2 .= $1;
      }
      if ($line=~s/^[\)] //) {
        $in--;
        if ($in > 0) {
          $arg2 .= ") ";
        }
      }
    }
    $arg2 =~s/ $//;

    return ($arg1,$arg2,$line);
}

sub NextExpr {
    my $line = $_[0];

    if ($line=~s/^([^( fu]+) //) {
      return ($1,$line);
    } 
    ($line=~s/^([fu]*\S*\s*\( )//) || die "BADSYNTAX, expected '(':",$line;
    my $expr="$1";
    my $in=1;
    while ($in > 0) {
      if ($line=~s/^\( //) {
        $expr .= "( ";
        $in++;
      }
      if ($line=~s/^([^()]+ )//) {
        $expr .= $1;
      }
      if ($line=~s/^\) //) {
        $expr .= ") ";
        $in--;
      }
    }
    $expr =~s/ $//;

    return ($expr,$line);
}

sub PrevExpr {
    my $line = $_[0];

    if ($line=~s/ ([^) ]+)$//) {
      return ($1,$line);
    } 
    ($line=~s/ \)$//) || die "BADSYNTAX, expected ')':",$line;
    my $in=1;
    my $expr=" )";
    while ($in > 0) {
      if ($line=~s/ \)$//) {
        $expr = " )".$expr;
        $in++;
      }
      if ($line=~s/( [^()]+)$//) {
        $expr = $1.$expr;
      }
      if ($line=~s/ \($//) {
        $expr = " (".$expr;
        $in--;
      }
    }
    $expr =~s/^ //;

    return ($expr,$line);
}

open(my $templates,"<",$ARGV[1]);
while (<$templates>) {
    # Create multiple samples from each template
    my $template=$_;
    chop($template);
    my $samples="";
    my $template_renamed="";
    my $cse_renamed="";
    my $str_renamed="";
    my $template_reuse="";
    my $cse_reuse="";
    my $str_reuse="";
    my $template_axioms="";
    my $str_axioms="";
    # Check for bad syntax
    $template=~s/~/-/g;
    $template=~s/!/-/g;
    $template=~s/\^/\+/g;
    $template=~s/( [=\+\-\*\/,(]) \+/$1/g;
    $template=~s/\^/\+/g;
    $template=~s/ (o\d+ [^;]+) ; t\d+ [^o]+(; *)$/ $1 $2/;
    next if $template=~/ [\+\-][\+\-] /;
    next if $template=~/ [fu]\S+ [^(]/;
    next if $template=~/ [=\*\-\+\/,;] [=,\);\*\/]/;
    next if $template=~/ [ito]\S+ [ito(]/;
    next if $template=~/ , \([^)]+\([^)]+\([^()]+\)[^(]+\)[^(]+\) [;(]/;
    next if $template=~/ , \([^)]+\([^()]+\)[^(]+\) [;(]/;
    next if $template=~/ , \([^()]+\) [;(]/;
    next if $template=~/ , [^()]+ ;/;
    next if $template=~/ \( \) /;
    next if $template=~/ = [^();,]*\(*[^();,]*\)[^();,]*\)/;
    next if $template=~/ = [^();,]*\([^();,]*\([^();,]*\)*[^();,]*;/;
    next if ! ($template=~/o. = /);

    print "DBG: TEMPLATE LINE $.=$template.\n";

    # Process 'pow' functions
    while ($template=~/^(.*) pow \( (.*)$/) {
      $template=$1;
      my @pow=NextArgs($2);
      if ($pow[0] =~/[^(]+ \S/) {
        $pow[0] = "( $pow[0] )";
      }
      $pow[1] || die "$template;$pow[0];$pow[2] failed pow arg check";
      if ($pow[1] eq "1s") {
        $template.=" $pow[0] $pow[2]";
      } elsif ($pow[1] eq "2s") {
        $template.=" ( $pow[0] * $pow[0] ) $pow[2]";
      } elsif ($pow[1] eq "3s") {
        $template.=" ( $pow[0] * $pow[0] * $pow[0] ) $pow[2]";
      } elsif ($pow[1] eq "4s") {
        $template.=" ( $pow[0] * $pow[0] * $pow[0] * $pow[0] ) $pow[2]";
      } elsif ($pow[1] eq "0s") {
        $template.=" 1s $pow[2]";
      } else {
        # Default everything else to 'square' function
        $template.=" ( $pow[0] * $pow[0] ) $pow[2]";
      }
    }
    ($template=~/ = [^;] o\d/) && die "Output used in other variable";
    # Collapse down to 2 outputs
    while ($template=~s/ o(\d+) (=.*?; o\d+ =.*?; o\d+ =)/ p$1 $2 p$1 +/) {} 

    my $lcl=1;
    # Attempt to prevent deep expression trees
    while (($template=~/^(.* )(\S+ = [^;]*?\([^;]*\([^;]*\([^;]* [^fu ]+ )(\([^();,]*\([^();,]*\)[^();,]*\([^();,]*\)[^();,]*\))(.*)$/) 
        || ($template=~/^(.* )(\S+ = [^;]*? [^fu ]+ )(\([^();,]*\([^();,]*\)[^();,]*\([^();,]*\)[^();,]*\))([^;]*\)[^;]*\)[^;]*\).*)$/)
        || ($template=~/^(.* )(\S+ = [^;]*?\([^;]*\([^;]*\([^;]* [^fu ]+ )(\([^();,]*\([^();,]*\)[^();,]*\))(.*)$/) 
        || ($template=~/^(.* )(\S+ = [^;]*? [^fu ]+ )(\([^();,]*\([^();,]*\)[^();,]*\))([^;]*\)[^;]*\)[^;]*\).*)$/)) {
      $template="$1l$lcl = $3 ; $2l$lcl$4";
      # Use new variable wherever possible in program
      while ($template=~s/ l$lcl = ([^;]+) ; (.*[\(\+=,] )\1/ l$lcl = $1 ; $2l$lcl/) {} 
      $lcl++;
    }
    print "DBG: prevent depth:$template.\n";
    # Attempt Common Subexpression Removal
    my $cse=";".$template;
    # Use then delete simple variable assigns
    while ($cse=~s/ (\S+) = (\S+) ; (.*)\1 / $1 = $2 ; $3$2 /) {} 
    $cse=~s/ ([tlp]\d+) = (\S+) ;//;
    while ($cse=~s/ ([tlp]\d+) = (\([^;]+\)) ; (.*)\2 / $1 = $2 ; $3$1 /) {} 
    while ($cse=~s/ ([tlp]\d+) = ([^-][^;]+) ; (.*[\+\=\*\/\-] )\( \2 \) / $1 = $2 ; $3$1 /) {} 
    # Process * and / CSEs then handle + and - to find first use of an expression that occurs twice
    # Search for 7 patterns of parens (not a full search) with consideration of order of operations
    while (($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]*\([^()]*\( [^()]* \)[^()]*\) [^()\+\-\/;]*[\/\*] \([^()]*\( [^()]* \)[^()]*\))( .*[\(\+\-\*=,] )\3( .*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]*\( [^()]* \) [^()\+\-\/;]*[\/\*] \([^()]*\( [^()]* \)[^()]*\))( .*[\(\+\-\*=,] )\3( .*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]*\([^()]*\( [^()]* \)[^()]*\) [^()\+\-\/;]*[\/\*] \( [^()]* \))( .*[\(\+\-\*=,] )\3( .*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]*\( [^()]* \) [^()\+\-\/;]*[\/\*] \( [^()]* \))( .*[\(\+\-\*=,] )\3( .*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]*\( [^()]* \) [^()\+\-\/;]*[\/\*] [^()\+\-\*\/;f,]*)( .*[\(\+\-\*=,] )\3( .*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]* [\/\*] \( [^()]* \))( .*[\(\+\-\*=,] )\3( .*)/)
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*=,] )([^()\+\-\/;]* [\/\*] [^()\+\-\*\/;f,]*)( .*[\(\+\-\*=,] )\3( .*)/)
        || ($cse=~/^(.*?)(;[^;]*?[\(\+\-\*\/=,] )(f\d+ \( [^()] \))( .*[\(\+\-\*\/=,] )\3( .*)/)) {
      $cse="$1; l$lcl = $3 $2l$lcl$4l$lcl$5";
      # Use new variable wherever possible in program
      while ($cse=~s/ l$lcl = ([^;]+) ; (.*[\(\+\-\*=,] )\1/ l$lcl = $1 ; $2l$lcl/) {} 
      $lcl++;
    }
    while (($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]*\([^()]*\( [^()]* \)[^()]*\) [^();]*[\+\-] \([^()]*\( [^()]* \)[^()]*\))( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]*\( [^()]* \) [^();]*[\+\-] \([^()]*\( [^()]* \)[^()]*\))( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]*\([^()]*\( [^()]* \)[^()]*\) [^();]*[\+\-] \( [^()]* \))( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]*\( [^()]* \) [^();]*[\+\-] \( [^()]* \))( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]*\( [^()]* \) [^();]*[\+\-] [^()\+\-;f]*[^()\+\-\*\/;f,])( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/) 
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]* [\+\-] \( [^()]* \))( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/)
        || ($cse=~/^(.*?)(;[^;]*?[\(\+=,] )([^();]* [\+\-] [^()\+\-;f]*[^()\+\-\*\/;f,])( [^\*\/].*[\(\+=,] )\3( [^\*\/].*)/)) {
      $cse="$1; l$lcl = $3 $2l$lcl$4l$lcl$5";
      # Use new variable wherever possible in program
      while ($cse=~s/ l$lcl = ([^;]+) ; (.*[\(\+=,] )\1/ l$lcl = $1 ; $2l$lcl/) {} 
      $lcl++;
    }
    $cse=~s/^;//;

    # Do strength reduction if possible
    my $str=";$cse";
    while (($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*\/]) (\S+)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*\/]) (\S+)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*\/]) (f*\d* *\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*\/]) (\S+)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*\( [^()]+ \)) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*\/]) (f*\d* *\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*\/]) (\S+)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*\( [^()]+ \)) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*\/]) (f*\d* *\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*\( [^()]+ \)) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*\/]) (f*\d* *\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*\( [^()]+ \)) \3 \4 ([\),\+\-;])/$1 ( $2 $6 $7 ) $3 $4$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \2 ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \3 \2 ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*) \2 \3 ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) ([a-z\d \*]*\( [^()]+ \)) \3 \2 ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*\( [^()]+ \)) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*]) ([a-z\d \*]*\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*]) ([a-z\d \*]*)( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*\( [^()]+ \)) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*) ([\*]) ([a-z\d \*]*\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*\( [^()]+ \)) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) ([a-z\d \*]*\( [^()]+ \)) ([\*]) ([a-z\d \*]*\( [^()]+ \))( | [\+\-][^();]* | [\+\-][^();]*\([^();]*\)[^();]*)([\+\-]) \2 \3 ([a-z\d \*]*\( [^()]+ \)) ([\),\+\-;])/$1 $2 $3 ( $4 $6 $7 )$5$8/) ||
           ($str=~s/([\(=,\+]) 2s ([\*]) ([iotlp\d]+) ([\),\+\-;])/$1 $3 + $3 $4/) ||
           ($str=~s/([\(=,\+]) ([iotlp\d]+) ([\*]) 2s ([\),\+\-;])/$1 $2 + $2 $4/))
       {}
    while (($str=~/^(.*?)(;[^;]*[\(\+=,] ) 2s \* ([iotlp\d]+) ([\),\+\-;])/)
        || ($str=~/^(.*?)(;[^;]*[\(\+=,] ) 2s \* ([a-z\d \*]*\( [^()]* \) [a-z\d \*]*) ([\),\+\-;])/)
        || ($str=~/^(.*?)(;[^;]*[\(\+=,] ) 2s \* ([a-z\d \*]*\( [^()]*\( [^()]* \)[^()]*\) [a-z\d \*]*) ([\),\+\-;])/)
        || ($str=~/^(.*?)(;[^;]*?[\(\+=,] ) ([iotlp\d]+) \* 2s ([\),\+\-;])/)
        || ($str=~/^(.*?)(;[^;]*?[\(\+=,] ) ([a-z\d \*]*\( [^()]* \) [a-z\d \*]*) \* 2s ([\),\+\-;])/)
        || ($str=~/^(.*?)(;[^;]*?[\(\+=,] ) ([a-z\d \*]*\( [^()]*\( [^()]* \)[^()]*\) [a-z\d \*]*) \* 2s ([\),\+\-;])/)) {
      $str="$1; l$lcl = $3 $2l$lcl + l$lcl $4";
      # Use new variable wherever possible in program
      while ($str=~s/ l$lcl = ([^;]+) ; (.*[\(\+=,] )\1/ l$lcl = $1 ; $2l$lcl/) {} 
      $lcl++;
    }
    $str=~s/^;//;

    # Rename variables
    @{$nonTerm{'Scalar_id'}} = shuffle(@{$nonTerm{'Scalar_id'}});
    @{$nonTerm{'Vector_id'}} = shuffle(@{$nonTerm{'Vector_id'}});
    my $renamed;
    my $scalarnum=0;
    my $func1in=int(rand(5));
    my $func2in=int(rand(5));
    my %mapping;
    my $lastout=0;
    my $tmp;
    for (my $i=1; $i<4; $i++) {
      $renamed="";
      if ($i==1) {
        $tmp=$template;
      } elsif ($i==2) {
        $tmp=$cse;
      } else {
        $tmp=$str;
      }
      print "DBG: i=$i,tmp=$tmp.\n";
      while ($tmp=~/^(.*?) (f\d+) \( (.*)$/) {
        $tmp=$1;
        my $func_name=$2;
        my @args=NextArgs($3);
        if ($args[1]) {
          if (! exists $mapping{$func_name}) {
            $mapping{$func_name} = sprintf "f%ds",($func2in % 5) + 1;
            $func2in++;
          }
          $tmp .= " $mapping{$func_name} ( $args[0] , $args[1] ) ";
        } else {
          if (! exists $mapping{$func_name}) {
            $mapping{$func_name} = sprintf "u%ds",($func1in % 5) + 1;
            $func1in++;
          }
          $tmp .= " $mapping{$func_name} ( $args[0] ) ";
        }
        $tmp.=$args[2];
      }
      # Process 4s, 3s, and 2s, use same lcl numbers for all 3 cases
      if ($tmp=~/^(.*?) (\S+ =[^;]* 4s .* 4s .*)$/) {
        $tmp="$1 l$lcl = 2s + 2s ; $2";
        $tmp =~ s/ 4s / l$lcl /g;
      } else {
        $tmp =~ s/ 4s / ( 2s + 2s ) /g;
      }
      if ($tmp=~/^(.*?) (\S+ =[^;]* 3s .* 3s .*)$/) {
        my $lcl_plus_1 = $lcl+1;
        $tmp="$1 l$lcl_plus_1 = 1s + 2s ; $2";
        $tmp =~ s/ 3s / l$lcl_plus_1 /g;
      } else {
        $tmp =~ s/ 3s / ( 1s + 2s ) /g;
      }
      if ($tmp=~/^(.*?) (\S+ =[^;]* 2s .* 2s .*)$/) {
        my $lcl_plus_2 = $lcl+2;
        $tmp="$1 l$lcl_plus_2 = 1s + 1s ; $2";
        $tmp =~ s/ 2s / l$lcl_plus_2 /g;
      } else {
        $tmp =~ s/ 2s / ( 1s + 1s ) /g;
      }
      while ($tmp=~s/^ (\S+)//) {
        my $tok = $1;
        if (exists $mapping{$tok}) {
          $renamed .= " $mapping{$tok}";
        } elsif ($tok=~/=/ && $lastout) {
          $renamed .= " ===";
        } elsif ($tok=~/[iotlp]\d+/) {
          if ($scalarnum+1 < scalar @{$nonTerm{'Scalar_id'}}) {
            $mapping{$tok} = @{$nonTerm{'Scalar_id'}}[$scalarnum];
            $scalarnum++;
          } elsif ($i==1 && $renamed=~s/ (\S+) = (\S+) ;//) {
            my $old=$1;
            my $new=$2;
            $renamed=~s/$old /$new /g;
            $mapping{$tok} = $old;
          } else {
            $mapping{$tok} = "OVERFLOW";
          }
          $renamed .= " $mapping{$tok}";
        } else {
          $renamed .= " $tok";
        }
        $lastout = ($tok=~/^o/);
      }
      if ($renamed =~/OVERFLOW/) {
        print "Too many scalars, skipping\n";
        last;
      }
      $renamed=~s/([\(=\+\-\*\/,]) \( (\S+) \)/$1 $2/g;
      while ($renamed=~/^(.*[\(=\+\-\*\/]) - (.*)$/) {
        my $prev=$1;
        my $next=$2;
        my @nextexp=NextExpr($next);
        $renamed="$prev ( ns $nextexp[0] ) $nextexp[1]";
      }
      $tmp=$renamed;
      $tmp=~s/^(.*) ([fu]\d+s) \(.*$/$1/;
      while ($renamed=~/^\Q$tmp\E ([fu]\d+s) \( (.*)$/) {
        my $function=$1;
        my $next=$2;
        my @args=NextArgs($next);
        if ($args[1]) {
          $renamed="$tmp ( $function $args[0] $args[1] ) $args[2]";
        } else {
          $renamed="$tmp ( $function $args[0] ) $args[2]";
        }
        $tmp=~s/^(.*) ([fu]\d+s) \(.*$/$1/;
      }
      print "DBG: ns,func:$renamed.\n";
      $renamed=~s/\( (\S+) \)/$1/g;
      while ($renamed=~/^(.*) \/ (.*)$/) {
        my $prev=$1;
        my $next=$2;
        my @prevexp=PrevExpr($prev);
        my @nextexp=NextExpr($next);
        $renamed="$prevexp[1] ( /s $prevexp[0] $nextexp[0] ) $nextexp[1]";
      }
      while ($renamed=~/^(.*) \* (.*)$/) {
        my $prev=$1;
        my $next=$2;
        my @prevexp=PrevExpr($prev);
        my @nextexp=NextExpr($next);
        $renamed="$prevexp[1] ( *s $prevexp[0] $nextexp[0] ) $nextexp[1]";
      }
      while ($renamed=~/^(.*) \- (.*)$/) {
        my $prev=$1;
        my $next=$2;
        my @prevexp=PrevExpr($prev);
        my @nextexp=NextExpr($next);
        $renamed="$prevexp[1] ( -s $prevexp[0] $nextexp[0] ) $nextexp[1]";
      }
      while ($renamed=~/^(.*) \+ (.*)$/) {
        my $prev=$1;
        my $next=$2;
        my @prevexp=PrevExpr($prev);
        my @nextexp=NextExpr($next);
        $renamed="$prevexp[1] ( +s $prevexp[0] $nextexp[0] ) $nextexp[1]";
      }
      while ($renamed=~/\( \(/) {
        $tmp = $renamed;
        $renamed="";
        while ($tmp=~s/^ (\S+)//) {
          my $tok = $1;
          if ($tok eq "(" && ($tmp=~s/^ \(/(/)) {
            my @nextexp =NextExpr($tmp);
            $renamed.=" $nextexp[0]";
            $tmp=" $nextexp[1]";
            $tmp=~s/^ \)// || die "Expected close paren in $renamed...$tmp";
          } else {
            $renamed.=" $tok";
          }
        }
      }
      print "DBG: no double parens:$renamed.\n";
      my $reuse=$renamed;
      my %progs;
      while (! exists $progs{$reuse}) {
        $progs{$reuse}=1;
        for (my $j = 0; $j < $scalarnum; $j++) {
          my $var= @{$nonTerm{'Scalar_id'}}[$j];
          # Find last use of var and see if we can reuse it
          if ($reuse=~/^(.*) (\S+) = ([^;]*$var [^;]*;)(.*)$/) {
            my $prev=$1;
            my $old=$2;
            my $expr=$3;
            my $next=$4;
            if (!($next=~/$var /) && !($next=~/$old ===/)) {
              $next=~s/$old /$var /g;
              if ($expr eq "$var ;") {
                if (! exists $progs{"$prev$next"}) {
                  $reuse="$prev$next";
                  last;
                }
              } else {
                if (! exists $progs{"$prev $var = $expr$next"}) {
                  $reuse="$prev $var = $expr$next";
                  last;
                }
              }
            }
          }
          # Find first assignment of var and see if we can replace a prior var
          if ($reuse=~/^(.*?) $var (=+) ([^;]*)(.*)$/) {
            my $prev=$1;
            my $eq=$2;
            my $expr=$3;
            my $next=$4;
            $tmp=$prev;
            # Check that var is not a reused input
            if (!($expr=~/$var /) && !($prev=~/$var /)) {
              while ($tmp=~/^(.*) (\S+) =( .*)$/) {
                my $old=$2;
                my $remain=$3;
                $tmp=$1;
                if (!($next=~/$old /) && !($tmp =~/$old /) && !($remain =~/$old /) && !($prev=~/$old ===/)) {
                  $prev=~s/$old /$var /g;
                  $expr=~s/$old /$var /g;
                  if (! exists $progs{"$prev $var $eq $expr$next"}) {
                    $reuse="$prev $var $eq $expr$next";
                    last;
                  }
                }
              }
            }
          }
        }
      }
      $renamed=~s/^ *//;
      $reuse=~s/^ *//;
      $renamed.=" ";
      $reuse.=" ";
      if ($i==1) {
        print "Template renamed: $renamed; reuse: $reuse.\n";
        $template_renamed=$renamed;
        $template_reuse=$reuse;
      } elsif ($i==2) {
        print "CSE renamed: $renamed; reuse: $reuse.\n";
        $cse_renamed=$renamed;
        $cse_reuse=$reuse;
      } else {
        print "STR reduce renamed: $renamed; reuse: $reuse.\n";
        $str_renamed=$renamed;
        $str_reuse=$reuse;
      }
    }
    next if ($renamed =~/OVERFLOW/);

    my $progA = "";
    my $progB = "";
    my $progTmp = "";

    next if (scalar split /[;() ]+/," $template_renamed ") -1 > $maxTokens;
    next if (scalar split /;/,"$template_renamed ") > 21;
    next if (scalar split /;/,"$template_renamed ") < 3;
    $progTmp=$template_renamed;
    $progTmp=~s/[^()]//g;
    while ($progTmp =~s/\)\(//g) {};
    next if length($progTmp)/2 > 5;

    next if (scalar split /[;() ]+/," $cse_renamed ") -1 > $maxTokens;
    next if (scalar split /;/,"$cse_renamed ") > 21;
    next if (scalar split /;/,"$cse_renamed ") < 3;
    $progTmp=$cse_renamed;
    $progTmp=~s/[^()]//g;
    while ($progTmp =~s/\)\(//g) {};
    next if length($progTmp)/2 > 5;

    next if (scalar split /[;() ]+/," $str_reuse ") -1 > $maxTokens;
    next if (scalar split /;/,$str_reuse) > 21;
    $progTmp=$str_reuse;
    $progTmp=~s/[^()]//g;
    while ($progTmp =~s/\)\(//g) {};
    next if length($progTmp)/2 > 5;

    $transform="";
    for (my $i=1; $i<3; $i++) {

      if ($i==1) {
        $progA = $template_renamed;
      } else {
        $progA = $str_reuse;
      }
      my $progB = "";
      my $stmnum=1;
      # 60% of the time, axioms start with intrastatement
      if (rand() < 0.6) {
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            $progB .= "$1 $2 ";
            my $stmB = $3;
            $stmB = GenerateStmBfromStmA($stmB,$stmnum,"N");
            die "Unexpected ; in $stmB" if $stmB=~/;/;
            $progB .= "$stmB ; ";
            $stmnum+=1;
        }
      } else {
        $progB=$progA;
      }
      $progTmp = InterAssignAxioms($progB, @{$nonTerm{'Scalar_id'}}[-1], @{$nonTerm{'Vector_id'}}[-1], @{$nonTerm{'Matrix_id'}}[-1]);
      next if (scalar split /;/,$progTmp) > 21;
      $progB="";
      $stmnum=1;
      if (rand() < 0.6) {
        foreach my $stmA (split /;/,$progTmp) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            $progB .= "$1 $2 ";
            my $stmB = $3;
            $stmB = GenerateStmBfromStmA($stmB,$stmnum,"N");
            $progB .= "$stmB ; ";
            $stmnum+=1;
        }
      } else {
        $progB=$progTmp;
      }
      if ($i==1) {
        $template_axioms=$progB;
      } else {
        $str_axioms=$progB;
      }
    }

    # Output equivalent programs with greppable labels
    if ($template_renamed ne $cse_renamed) {
      print "X ${template_renamed}Y ${cse_renamed}Z Template Cse \n";
    }
    if ($cse_renamed ne $str_renamed) {
      print "X ${cse_renamed}Y ${str_renamed}Z Cse Str \n";
    }
    if ($str_renamed ne $str_reuse) {
      print "X ${str_renamed}Y ${str_reuse}Z Str Reuse \n";
    }
    if (($template_renamed ne $cse_renamed) &&
        ($cse_renamed ne $str_renamed)) {
      print "X ${template_renamed}Y ${str_reuse}Z Template Cse Str Reuse \n";
    }
    if ($template_renamed ne $str_renamed) {
      print "X ${str_renamed}Y ${template_renamed}Z Str Cse Template \n";
    }
    if ($str_reuse ne $template_renamed) {
      print "X ${str_reuse}Y ${template_renamed}Z Reuse Str Cse Template \n";
    }

    # Check that axioms did not create problem programs
    next if $transform=~/ N[lr][lr][lr][lr][lr]/;
    next if (scalar split /[;() ]+/," $template_axioms ") -1 > $maxTokens;
    next if (scalar split /;/,"$template_axioms ") > 21;
    $progTmp=$template_axioms;
    $progTmp=~s/[^()]//g;
    while ($progTmp =~s/\)\(//g) {};
    next if length($progTmp)/2 > 5;
    next if (scalar split /[;() ]+/," $str_axioms ") -1 > $maxTokens;
    next if (scalar split /;/,"$str_axioms ") > 21;
    $progTmp=$str_axioms;
    $progTmp=~s/[^()]//g;
    while ($progTmp =~s/\)\(//g) {};
    next if length($progTmp)/2 > 5;
    if ($str_reuse ne $str_axioms) {
      print "X ${str_reuse}Y ${str_axioms}Z Reuse Axioms \n";
    }
    if (($template_renamed ne $cse_renamed) &&
        ($cse_renamed ne $str_renamed) &&
        ($str_reuse ne $str_axioms)) {
      print "X ${template_renamed}Y ${str_axioms}Z Template Cse Str Reuse Axioms \n";
    }
    if (($str_reuse ne $template_renamed) &&
        ($template_renamed ne $template_axioms)) {
      print "X ${str_reuse}Y ${template_axioms}Z Reuse Str Cse Template Axioms \n";
    }
}
