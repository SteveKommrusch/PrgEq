#!/usr/bin/perl
#
use strict;
use warnings;

# Define commonly-used subroutite that uses global $transform
# as axiom list to create a new output program

sub GenProgUsingAxioms {
    my $progA = $_[0];
    my $path = $_[1];
    my $transform = $_[2];

    $transform || return $progA;
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

    if ($progA =~s/^\( (..) //) {
        $in=1;
        $left = "( ".$1." ";
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
        $progA =~s/^(.)\s*//;
        $left = $1;
    }

    if ($progA =~s/^\s*\( (..) //) {
        $in=1;
        $right = "( ".$1." ";
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
        $progA =~s/^\s*(\S)\s*// ;
        if ($1 ne ")") {
            $right = $1;
        }
    }

    if (($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright && $transform =~s/^${path}left Cancel //) {
        if ($right ne "") {
            if ($leftop eq "-s") {
                return GenProgUsingAxioms("( $op 0 $right )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 1 $right )",$path,$transform);
            }
        } else {
            if ($leftop eq "-s") {
                return GenProgUsingAxioms("( $op 0 )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op 1 )",$path,$transform);
            }
        }
    }

    if (($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright && $transform =~s/^${path}right Cancel //) {
        if ($rightop eq "-s") {
            return GenProgUsingAxioms("( $op $left 0 )",$path,$transform);
        } else {
            return GenProgUsingAxioms("( $op $left 1 )",$path,$transform);
        }
    }

    if (($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright && $transform =~s/^${path}left Cancel //) {
        if ($right ne "") {
            if ($leftop eq "-m") {
                return GenProgUsingAxioms("( $op O $right )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op o $right )",$path,$transform);
            }
        } else {
            if ($leftop eq "-m") {
                return GenProgUsingAxioms("( $op O )",$path,$transform);
            } else {
                return GenProgUsingAxioms("( $op o )",$path,$transform);
            }
        }
    }

    if (($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright && $transform =~s/^${path}right Cancel //) {
        if ($rightop eq "-m") {
            return GenProgUsingAxioms("( $op $left O )",$path,$transform);
        } else {
            return GenProgUsingAxioms("( $op $left o )",$path,$transform);
        }
    }

    if ($op eq "*m" && (($leftleft eq $right && $leftop eq "im") ||
                        ($rightleft eq $left && $rightop eq "im")) && $transform =~s/^${path}Cancel //) {
        return "I";
    }

    if ((($op eq "+s" && ($left eq "0" || $right eq "0")) ||
         ($op eq "-s" && $right eq "0") ||
         ($op =~ /\*./ && ($left eq "1" || $right eq "1")) ||
         ($op eq "/s" && $right eq "1")) && $transform =~s/^${path}Noop //) {
        if ($left eq "0" || $left eq "1") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "+m" && ($left eq "O" || $right eq "O")) ||
         ($op eq "-m" && $right eq "O")) && $transform =~s/^${path}Noop //) {
        if ($left eq "O") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ($op eq "*m" && (($left eq "I" && ($rightop =~ /.m/ || $right =~ /^[A-Z]/)) || ($right eq "I" && ($leftop =~ /.m/ || $left =~ /^[A-Z]/))) && $transform =~s/^${path}Noop //) {
        if ($left eq "I") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "+v" && ($left eq "o" || $right eq "o")) ||
         ($op eq "-v" && $right eq "o")) && $transform =~s/^${path}Noop //) {
        if ($left eq "o") {
            return GenProgUsingAxioms($right,$path,$transform);
        } else {
            return GenProgUsingAxioms($left,$path,$transform);
        }
    }

    if ((($op eq "*s" && ($left eq "0" || $right eq "0")) ||
                         ($op eq "/s" && $left eq "0")) && $transform =~s/^${path}Multzero //) {
        return "0";
    }

    if (($op eq "*m" && ($left eq "O" || $right eq "O" || $left eq "0" || $right eq "0"))
                        && $transform =~s/^${path}Multzero //) {
        return "O";
    }

    if (($op eq "*v" && ($left =~/^[oO0]/ || $right =~/^[oO0]/))
                        && $transform =~s/^${path}Multzero //) {
        return "o";
    }

    if (($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^${path}Distribleft //) {
        $newleft = GenProgUsingAxioms("( $op $leftleft $right )",$path."left ",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."right ",$transform);
        $leftop =~s/.$/m/;
        return "( $leftop $newleft $newright )";
    }

    if (($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^${path}Distribright //) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."left ",$transform);
        $newright= GenProgUsingAxioms("( $op $left $rightright )",$path."right ",$transform);
        $rightop =~s/.$/m/;
        return "( $rightop $newleft $newright )";
    }

    if (($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./) && $transform =~s/^${path}Distribleft //) {
        $newleft = GenProgUsingAxioms("( $op $leftleft $right )",$path."left ",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."right ",$transform);
        if ($op =~/.v/) {$leftop =~s/.$/v/}
        return "( $leftop $newleft $newright )";
    }

    if (($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./) && $transform =~s/^${path}Distribright //) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."left ",$transform);
        $newright= GenProgUsingAxioms("( $op $left $rightright )",$path."right ",$transform);
        if ($op =~/.v/) {$rightop =~s/.$/v/}
        return "( $rightop $newleft $newright )";
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
            $newleft = GenProgUsingAxioms("$leftleft",$path."left ",$transform);
            $newright= GenProgUsingAxioms("( $op $leftright $rightright )",$path."right ",$transform);
            return "( $leftop $newleft $newright )";
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
            $newleft = GenProgUsingAxioms("( $op $leftleft $rightleft )",$path."left ",$transform);
            $newright= GenProgUsingAxioms("$rightright",$path."right ",$transform);
            return "( $leftop $newleft $newright )";
        } else {
            return "<PROGBFAILTOMATCH>";
        }
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $rightop) && $transform =~s/^${path}Assocleft //) {
        $newleft = GenProgUsingAxioms("( $op $left $rightleft )",$path."left ",$transform);
        $newright= GenProgUsingAxioms("$rightright",$path."right ",$transform);
        return "( $op $newleft $newright )";
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $leftop) && $transform =~s/^${path}Assocright //) {
        $newleft = GenProgUsingAxioms("$leftleft",$path."left ",$transform);
        $newright= GenProgUsingAxioms("( $op $leftright $right )",$path."right ",$transform);
        return "( $op $newleft $newright )";
    }
  
    if ((($op eq "nv" && $leftop eq "-v") ||
         ($op eq "ns" && $leftop eq "-s") ||
         ($op eq "is" && $leftop eq "/s") ||
         ($op eq "nm" && $leftop eq "-m")) && $transform =~s/^${path}Flipleft //) {
        $newleft = GenProgUsingAxioms("$leftright",$path."left ",$transform);
        $newright= GenProgUsingAxioms("$leftleft",$path."right ",$transform);
        return "( $leftop $newleft $newright )";
    }

    if ((($op eq "-s" && $rightop =~/[\-n]s/) ||
         ($op eq "/s" && $rightop =~/[\/i]s/) ||
         ($op eq "-m" && $rightop =~/[\-n]m/) ||
         ($op eq "-v" && $rightop =~/[\-n]v/)) && $transform =~s/^${path}Flipright //) {
        $newop = $op;
        $newop =~s/\-/\+/;
        $newop =~s/\//\*/;
        $newleft = GenProgUsingAxioms("$left",$path."left ",$transform);
        if ($op eq $rightop) {
            $newright= GenProgUsingAxioms("( $op $rightright $rightleft )",$path."right ",$transform);
        } else {
            $newright= GenProgUsingAxioms("$rightleft",$path."right ",$transform);
        }
        return "( $newop $newleft $newright )";
    }
    if ($op eq "*m" && $transform =~s/^${path}Transpose //) {
        $newleft = GenProgUsingAxioms("$right",$path."left left left ",$transform);
        $newright= GenProgUsingAxioms("$left",$path."left right left ",$transform);
        return "( tm ( *m ( tm $newleft ) ( tm $newright ) ) )";
    }
    if ((($op eq "-m") || ($op eq "+m")) && $transform =~s/^${path}Transpose //) {
        $newleft = GenProgUsingAxioms("$left",$path."left left left ",$transform);
        $newright= GenProgUsingAxioms("$right",$path."left right left ",$transform);
        return "( tm ( $op ( tm $newleft ) ( tm $newright ) ) )";
    }
    if (($op eq "tm") && ($leftop eq "*m") && $transform =~s/^${path}Transpose //) {
        $newleft = GenProgUsingAxioms("$leftright",$path."left left ",$transform);
        $newright= GenProgUsingAxioms("$leftleft",$path."right left ",$transform);
        return "( *m ( tm $newleft ) ( tm $newright ) )";
    }
    if (($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m")) && $transform =~s/^${path}Transpose //) {
        $newleft = GenProgUsingAxioms("$leftleft",$path."left left ",$transform);
        $newright= GenProgUsingAxioms("$leftright",$path."right left ",$transform);
        return "( $leftop ( tm $newleft ) ( tm $newright ) )";
    }
    if ($right eq "") {
        if (($leftop eq $op) && $transform =~s/^${path}Double //) {
            return GenProgUsingAxioms($leftleft,$path,$transform);
        } else {
            $newleft = GenProgUsingAxioms($left,$path."left ",$transform);
        }
        return "( $op $newleft )";
    }

    if ($left ne $right && $transform =~s/^${path}Commute //) {
        $newleft = GenProgUsingAxioms($right,$path."left ",$transform);
        $newright = GenProgUsingAxioms($left,$path."right ",$transform);
        return "( $op $newleft $newright )";
    } else {
        $newleft = GenProgUsingAxioms($left,$path."left ",$transform);
        $newright = GenProgUsingAxioms($right,$path."right ",$transform);
        return "( $op $newleft $newright )";
    }
}

1;
