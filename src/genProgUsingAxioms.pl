#!/usr/bin/perl
#
use List::Util qw(shuffle);
use strict;
use warnings;

# Define commonly-used subroutite that uses global $transform
# as axiom list to create a new output program
#

sub GenProgUsingAxioms {
    my $progA = $_[0];
    my $path = $_[1];
    my $transform = $_[2];

    $transform || return $progA;
    my $in;
    my $stmnum=1;
    my $progB="";

    # Check for possible swaps
    if ($transform =~ /^stm(\d+) Swapprev/) {
        my $xstm=$1;
        my $lhsPrev = "";
        my $eqPrev = "";
        my $rhsPrev = "";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($eqPrev && $xstm == $stmnum && ! ($rhsPrev =~ /$lhs/) && ! ($stmA =~ /$lhsPrev/)) {
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
        return $progB;
    }

    # Possibly inline a variable
    if ($transform =~ /^stm(\d+) Inline (\S+)/) {
        my $xstm=$1;
        my $xvar=$2;
        my %vars;
        $progB = "";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            foreach my $var (shuffle(keys %vars)) {
                if ($xstm == $stmnum && $xvar eq $var) {
                    $rhs =~ s/$var/$vars{$var}/g;
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
        return $progB;
    }
    
    # Possibly delete dead code (unused variable assign)
    if ($transform =~ /^stm(\d+) Deletestm/) {
        my $xstm=$1;
        my %vars;
        $progB = "";
        while ($progA =~ s/^([^;]+); //) {
            my $stmA = $1;
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || die "Illegal statement in dead code check: $stmA\n"; 
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($progA =~/$lhs/ || $eq eq "===" || $xstm != $stmnum) {
                $progB .= "$lhs $eq $rhs ; ";
            } else {
                last;
            }
            $stmnum++;
        }
        return $progB.$progA;
    }
    
    # Check for possible new variables
    if ($transform =~ /^stm(\d+) Newtmp (\S+) (\S+)/) {
        my $xstm=$1;
        my $xpath=$2;
        my $xvar=$3;
        $progB="";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S.*\S)\s*$/ || next;
            $stmA = $1;
            if ($stmnum == $xstm) {
                $stmA =~ /^[^=]*=+ +(\S.*\S)$/;
                my $remain = $1;
                $xpath =~ s/^N// || die "Illegal Node path: $xpath";
                while ($xpath =~ s/^(\S)//) {
                    if ($1 eq "l") {
                        # Skip operator
                        $remain =~ s/^\( \S+ //;
                    } else {
                        # Skip operator
                        $remain =~ s/^\( \S+ //;
                        # Skip over left child
                        if (! ($remain =~ s/^[^() ]* +//)) {
                            my $in = 0;
                            while ($remain =~ s/^([()])[^()]* //) {
                                if ($1 eq "(") {
                                    $in++;
                                } else {
                                    $in--;
                                    if ($in == 0) {
                                        last;
                                    }
                                }
                            }
                        }
                    }
                }
                my $in = 0;
                my $expr = "";
                while ($remain =~ s/^([()] )//) {
                    $expr .= "$1";
                    if ($1 eq "( ") {
                        $remain =~ s/^([^()]+)//;
                        $expr .= "$1";
                        $in++;
                    } else {
                        $in--;
                        if ($in == 0) {
                            last;
                        }
                        if ($remain =~ s/^([^()]+)//) {
                            $expr .= "$1";
                        }
                    }
                }
                ($stmA =~ s/\Q$expr\E/$xvar /g) || die "$expr not found for $xvar in $stmA";
                $progB .= "$xvar = $expr; "; 
            }
            $progB .= $stmA." ; ";
            $stmnum++;
        }
        return $progB;
    }

    # Possibly replace statement with lexically equivalent variable
    if ($transform =~ /^stm(\d+) Usevar (\S+)/) {
        my $xstm=$1;
        my $xvar=$2;
        my %vars;
        $progB = "";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            foreach my $var (shuffle(keys %vars)) {
                if ($xstm eq $stmnum && $xvar eq $var) {
                    $rhs =~ s/\Q$vars{$var}\E/$var/g || die "$rhs does not include $vars{$var}";
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
        return $progB;
    }

    # If progA is full program, find statement for expression axiom
    if ($progA =~/= / && ($transform =~ s/^stm(\d+)\s+//)) {
        my $xstm=$1;
        $progB = "";
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
	    my $rhs = $3;
            if ($stmnum == $xstm) {
                $rhs = GenProgUsingAxioms($rhs,"N",$transform);
            }
            $progB .= "$lhs $eq $rhs ; ";
            $stmnum++;
        }
        return $progB;
    }

    # Process expression axioms
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
                    if ($in > 4) {
                        return "TOODEEP";
                    }
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
                            $leftdone=1;
                            $leftleft .= ")";
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
                    if ($in > 4) {
                        return "TOODEEP";
                    }
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

    if (($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $transform =~s/^Cancel ${path}l *$//) {
        if ($right ne "") {
            if ($leftop eq "-s") {
                return GenProgUsingAxioms("( $op 0s $right )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 1s $right )",$path,$transform);
            }
        } else {
            if ($leftop eq "-s") {
                return GenProgUsingAxioms("( $op 0s )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 1s )",$path,$transform);
            }
        }
    }

    if (($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $transform =~s/^Cancel ${path}r *$//) {
        if ($rightop eq "-s") {
            return GenProgUsingAxioms("( $op $left 0s )",$path,$transform);
        } else {
            return GenProgUsingAxioms("( $op $left 1s )",$path,$transform);
        }
    }

    if (($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $transform =~s/^Cancel ${path}l *$//) {
        if ($right ne "") {
            if ($leftop eq "-m") {
                return GenProgUsingAxioms("( $op 0m $right )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 0v $right )",$path,$transform);
            }
        } else {
            if ($leftop eq "-m") {
                return GenProgUsingAxioms("( $op 0m )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 0v )",$path,$transform);
            }
        }
    }

    if (($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $transform =~s/^Cancel ${path}r *$//) {
        if ($rightop eq "-m") {
            return GenProgUsingAxioms("( $op $left 0m )",$path,$transform);
        } else {
            return GenProgUsingAxioms("( $op $left 0v )",$path,$transform);
        }
    }

    if ($op eq "*m" && (($leftleft eq $right && $leftop eq "im") ||
                        ($rightleft eq $left && $rightop eq "im")) && $transform =~s/^Cancel $path *$//) {
        return "Im";
    }

    if ((($op eq "+s" && ($left eq "0s" || $right eq "0s")) ||
         ($op eq "-s" && $right eq "0s") ||
         ($op =~ /\*./ && ($left eq "1s" || $right eq "1s")) ||
         ($op eq "/s" && $right eq "1s")) && $transform =~s/^Noop $path *$//) {
        if ($left eq "0s" || $left eq "1s") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "+m" && ($left eq "0m" || $right eq "0m")) ||
         ($op eq "-m" && $right eq "0m")) && $transform =~s/^Noop $path *$//) {
        if ($left eq "0m") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ($op eq "*m" && (($left eq "Im" && ($rightop =~ /.m/ || $right =~ /^([0I]m|m\d+)/)) || ($right eq "Im" && ($leftop =~ /.m/ || $left =~ /^([0I]m|m\d+)/))) && $transform =~s/^Noop $path *$//) {
        if ($left eq "Im") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "+v" && ($left eq "0v" || $right eq "0v")) ||
         ($op eq "-v" && $right eq "0v")) && $transform =~s/^Noop $path *$//) {
        if ($left eq "0v") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "*s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "/s" && $left eq "0s")) && $transform =~s/^Multzero $path *$//) {
        return "0s";
    }

    if (($op eq "*m" && ($left eq "0m" || $right eq "0m" || $left eq "0s" || $right eq "0s"))
                        && $transform =~s/^Multzero $path *$//) {
        return "0m";
    }

    if (($op eq "*v" && ($left =~/^0[msv]/ || $right =~/^0[msv]/))
                        && $transform =~s/^Multzero $path *$//) {
        return "0v";
    }

    if (($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^Distribleft $path *$//) {
        $newleft = GenProgUsingAxioms("( $op $leftleft $right )",$path."l",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."r",$transform);
        $leftop =~s/.$/m/;
        return "( $leftop $newleft $newright )";
    }

    if (($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^Distribright $path *$//) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."l",$transform);
        $newright= GenProgUsingAxioms("( $op $left $rightright )",$path."r",$transform);
        $rightop =~s/.$/m/;
        return "( $rightop $newleft $newright )";
    }

    if (($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^Distribleft $path *$//) {
        $newleft = GenProgUsingAxioms("( $op $leftleft $right )",$path."l",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."r",$transform);
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "( $leftop $newleft $newright )";
    }

    if (($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^Distribright $path *$//) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."l",$transform);
        $newright= GenProgUsingAxioms("( $op $left $rightright )",$path."r",$transform);
        if ($op =~/.v/) {$rightop =~s/.$/v/}
        return "( $rightop $newleft $newright )";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./) && $transform =~s/^Factorleft $path *$//) {
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
            $newleft = GenProgUsingAxioms("$leftleft",$path."l",$transform);
            $newright= GenProgUsingAxioms("( $op $leftright $rightright )",$path."r",$transform);
            return "( $leftop $newleft $newright )";
        } else {
            return "<PROGBFAILTOMATCH>";
        }
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./) && $transform =~s/^Factorright $path *$//) {
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
            $newleft = GenProgUsingAxioms("( $op $leftleft $rightleft )",$path."l",$transform);
            $newright= GenProgUsingAxioms("$rightright",$path."r",$transform);
            return "( $leftop $newleft $newright )";
        } else {
            return "<PROGBFAILTOMATCH>";
        }
    }

    if ($op =~/\*./ && $rightop =~ /\*./ && $transform =~s/^Assocleft $path *$//) {
        if (($leftop =~ /.s/ || $left =~/^([01]s|s\d+)/) && ($rightleft =~/^. .s/ || $rightleft =~/^([01]s|s\d+)/)) {
          $leftop = "*s";
        } elsif ($leftop =~ /.v/ || $left =~/^(0v|v\d+)/ || $rightleft =~/^. .v/ || $rightleft =~/^(0v|v\d+)/) {
          $leftop = "*v";
        } else {
          $leftop = "*m";
        }
        $newleft = GenProgUsingAxioms("( $leftop $left $rightleft )",$path."l");
        $newright= GenProgUsingAxioms("$rightright",$path."r");
        return "( $op $newleft $newright )";
    }

    if ((($op =~/\+./ && $rightop =~/[\-+]./) ||
         ($op =~ /\*s/ && $rightop eq "/s")) &&
         $transform =~s/^Assocleft $path *$//) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."l",$transform);
        $newright= GenProgUsingAxioms("$rightright",$path."r",$transform);
        return "( $rightop $newleft $newright )";
    }

    if ($op =~/\*./ && $leftop =~ /\*./ && $transform =~s/^Assocright $path *$//) {
        if (($rightop =~ /.s/ || $right =~/^([01]s|s\d+)/) && ($leftright =~/^. .s/ || $leftright =~/^([01]s|s\d+)/)) {
          $rightop = "*s";
        } elsif ($rightop =~ /.v/ || $right =~/^(0v|v\d+)/ || $leftright =~/^. .v/ || $leftright =~/^(0v|v\d+)/) {
          $rightop = "*v";
        } else {
          $rightop = "*m";
        }
        $newleft = GenProgUsingAxioms("$leftleft",$path."l");
        $newright= GenProgUsingAxioms("( $rightop $leftright $right )",$path."r");
        return "( $op $newleft $newright )";
    }

    if ((($op =~/[\-+]./ && $leftop =~/\+./) ||
         ($op eq "/s" && $leftop =~/\*s/)) &&
         $transform =~s/^Assocright $path *$//) {
        $newleft = GenProgUsingAxioms("$leftleft",$path."l",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."r",$transform);
        return "( $leftop $newleft $newright )";
    }
  
    if ((($op eq "nv" && $leftop eq "-v") ||
         ($op eq "ns" && $leftop eq "-s") ||
         ($op eq "is" && $leftop eq "/s") ||
         ($op eq "nm" && $leftop eq "-m")) && $transform =~s/^Flipleft $path *$//) {
        $newleft = GenProgUsingAxioms("$leftright",$path."l",$transform);
        $newright= GenProgUsingAxioms("$leftleft",$path."r",$transform);
        return "( $leftop $newleft $newright )";
    }

    if ((($op eq "-s" && $rightop =~/[\-n]s/) ||
         ($op eq "/s" && $rightop =~/[\/i]s/) ||
         ($op eq "-m" && $rightop =~/[\-n]m/) ||
         ($op eq "-v" && $rightop =~/[\-n]v/)) && $transform =~s/^Flipright $path *$//) {
        $newop = $op;
        $newop =~s/\-/\+/;
        $newop =~s/\//\*/;
        $newleft = GenProgUsingAxioms("$left",$path."l",$transform);
        if ($op eq $rightop) {
            $newright= GenProgUsingAxioms("( $op $rightright $rightleft )",$path."r",$transform);
        } else {
            $newright= GenProgUsingAxioms("$rightleft",$path."r",$transform);
        }
        return "( $newop $newleft $newright )";
    }
    if ($op eq "*m" && $transform =~s/^Transpose $path *$//) {
        if (($right =~ /^m\d/) || ($right =~ /^\( .m/)) {
            $newleft = GenProgUsingAxioms("$right",$path."lll",$transform);
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenProgUsingAxioms("$right",$path."ll",$transform);
        }
        if (($left =~ /^m\d/) || ($left =~ /^\( .m/)) {
            $newright= GenProgUsingAxioms("$left",$path."lrl",$transform);
            $newright = "( tm $newright )";
        } else {
            $newright= GenProgUsingAxioms("$left",$path."lr",$transform);
        }
        return "( tm ( *m $newleft $newright ) )";
    }
    if ((($op eq "-m") || ($op eq "+m")) && $transform =~s/^Transpose $path *$//) {
        $newleft = GenProgUsingAxioms("$left",$path."lll",$transform);
        $newright= GenProgUsingAxioms("$right",$path."lrl",$transform);
        return "( tm ( $op ( tm $newleft ) ( tm $newright ) ) )";
    }
    if (($op eq "tm") && ($leftop eq "*m") && $transform =~s/^Transpose $path *$//) {
        # Scalar values are allowed, but they don't transpose
        if (($leftright =~ /^m\d/) || ($leftright =~ /^\( .m/)) {
            $newleft = GenProgUsingAxioms("$leftright",$path."ll",$transform);
            $newleft = "( tm $newleft )";
        } else {
            $newleft = GenProgUsingAxioms("$leftright",$path."l",$transform);
        }
        if (($leftleft =~ /^m\d/) || ($leftleft =~ /^\( .m/)) {
            $newright= GenProgUsingAxioms("$leftleft",$path."rl",$transform);
            $newright = "( tm $newright )";
        } else {
            $newright= GenProgUsingAxioms("$leftleft",$path."r",$transform);
        }
        return "( *m $newleft $newright )";
    }
    if (($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $transform =~s/^Transpose $path *$//) {
        $newleft = GenProgUsingAxioms("$leftleft",$path."ll",$transform);
        $newright= GenProgUsingAxioms("$leftright",$path."rl",$transform);
        return "( $leftop ( tm $newleft ) ( tm $newright ) )";
    }
    if ($right eq "") {
        if (($leftop eq $op) && $transform =~s/^Double $path *$//) {
            return GenProgUsingAxioms($leftleft,$path,$transform);
        } else {
            $newleft = GenProgUsingAxioms($left,$path."l",$transform);
        }
        return "( $op $newleft )";
    }

    my $dont_commute=0;
    if ($op =~/-./ || $op eq "/s" ||
            ($op eq "*m" && !($leftop =~ /^.s/ || $left =~ /^([01][ms]|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01][ms]|s\d+)/)) ||
            ($op eq "*v" && !($leftop =~ /^.s/ || $left =~ /^([01]s|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01]s|s\d+)/))) {
        $dont_commute = 1;
    }
    if ($left ne $right && !$dont_commute && $transform =~s/^Commute $path *$//) {
        $newleft = GenProgUsingAxioms($right,$path."l",$transform);
        $newright = GenProgUsingAxioms($left,$path."r",$transform);
        return "( $op $newleft $newright )";
    } else {
        $newleft = GenProgUsingAxioms($left,$path."l",$transform);
        $newright = GenProgUsingAxioms($right,$path."r",$transform);
        return "( $op $newleft $newright )";
    }
}

1;
