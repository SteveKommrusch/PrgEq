#!/usr/bin/perl
#
use strict;
use warnings;

# Define commonly-used subroutite that uses global $transform
# as axiom list to create a new output program

sub AllPossibleAxioms {
    my $progA = $_[0];
    my $path = $_[1];

    $progA =~s/^\( (..) // || return "";
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
    my $transform="";

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
                    if ($in > 5) {
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
                    if ($in > 5) {
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
        $progA =~s/^\s*(\S)\s*// ;
        if ($1 ne ")") {
            $right = $1;
        }
    }

    if (($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright) {
        $transform .= "${path}left Cancel ";
    }

    if (($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright) {
        $transform .= "${path}right Cancel ";
    }

    if (($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright) {
        $transform .= "${path}left Cancel ";
    }

    if (($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright) {
        $transform .= "${path}right Cancel ";
    }

    if ($op eq "*m" && (($leftleft eq $right && $leftop eq "im") ||
                        ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= "${path}Cancel ";
    }

    if ((($op eq "+s" && ($left eq "0" || $right eq "0")) ||
         ($op eq "-s" && $right eq "0") ||
         ($op =~ /\*./ && ($left eq "1" || $right eq "1")) ||
         ($op eq "/s" && $right eq "1"))) {
        $transform .= "${path}Noop ";
    }

    if ((($op eq "+m" && ($left eq "O" || $right eq "O")) ||
         ($op eq "-m" && $right eq "O"))) {
        $transform .= "${path}Noop ";
    }

    if ($op eq "*m" && (($left eq "I" && ($rightop =~ /.m/ || $right =~ /^[A-Z]/)) || ($right eq "I" && ($leftop =~ /.m/ || $left =~ /^[A-Z]/)))) {
        $transform .= "${path}Noop ";
    }

    if ((($op eq "+v" && ($left eq "o" || $right eq "o")) ||
         ($op eq "-v" && $right eq "o"))) {
        $transform .= "${path}Noop ";
    }

    if ((($op eq "*s" && ($left eq "0" || $right eq "0")) ||
                         ($op eq "/s" && $left eq "0"))) {
        $transform .= "${path}Multzero ";
    }

    if (($op eq "*m" && ($left eq "O" || $right eq "O" || $left eq "0" || $right eq "0"))) {
        $transform .= "${path}Multzero ";
    }

    if (($op eq "*v" && ($left =~/^[oO0]/ || $right =~/^[oO0]/))) {
        $transform .= "${path}Multzero ";
    }

    if (($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./)) {
        $transform .= "${path}Distribleft ";
    }

    if (($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./)) {
        $transform .= "${path}Distribright ";
    }

    if (($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./)) {
        $transform .= "${path}Distribleft ";
    }

    if (($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./)) {
        $transform .= "${path}Distribright ";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./)) {
        $transform .= "${path}Factorleft ";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./)) {
        $transform .= "${path}Factorright ";
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $rightop)) {
        $transform .= "${path}Assocleft ";
    }

    if (($op =~/\+./ || $op =~ /\*[ms]/) && ($op eq $leftop)) {
        $transform .= "${path}Assocright ";
    }
  
    if ((($op eq "nv" && $leftop eq "-v") ||
         ($op eq "ns" && $leftop eq "-s") ||
         ($op eq "is" && $leftop eq "/s") ||
         ($op eq "nm" && $leftop eq "-m"))) {
        $transform .= "${path}Flipleft ";
    }

    if ((($op eq "-s" && $rightop =~/[\-n]s/) ||
         ($op eq "/s" && $rightop =~/[\/i]s/) ||
         ($op eq "-m" && $rightop =~/[\-n]m/) ||
         ($op eq "-v" && $rightop =~/[\-n]v/))) {
        $transform .= "${path}Flipright ";
    }
    if ($op eq "*m") {
        $transform .= "${path}Transpose ";
    }
    if ((($op eq "-m") || ($op eq "+m"))) {
        $transform .= "${path}Transpose ";
    }
    if (($op eq "tm") && ($leftop eq "*m")) {
        $transform .= "${path}Transpose ";
    }
    if (($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m"))) {
        $transform .= "${path}Transpose ";
    }
    if ($right eq "") {
        if ($leftop eq $op) {
            $transform .= "${path}Double ";
        }
        return $transform.AllPossibleAxioms($left,$path."left ");
    }

    if ($left ne $right && !($op =~/-./ || $op eq "*m" || $op eq "/s")) {
            $transform .= "${path}Commute ";
    }
    return $transform.AllPossibleAxioms($left,$path."left ").AllPossibleAxioms($right,$path."right ");
}

1;
