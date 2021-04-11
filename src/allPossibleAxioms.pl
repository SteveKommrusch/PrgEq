#!/usr/bin/perl
#
use strict;
use warnings;

# Define commonly-used subroutine that returns all possible axioms given an input program

sub AllPossibleAxioms {
    my $progA = $_[0];
    my $stmnum = $_[1];
    my $path = $_[2];

    my $op = "";
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

    # Process statements first
    if ($progA =~/ =+ /) {
        $stmnum=1;
        my $lhsPrev = "";
        my $eqPrev = "";
        my $rhsPrev = "";

        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($eqPrev && ! ($rhsPrev =~ /$lhs/) && ! ($stmA =~ /$lhsPrev/)) {
                $transform .= "stm$stmnum Swapprev ";
            } else {
                $lhsPrev = $lhs;
                $eqPrev = $eq;
                $rhsPrev = $rhs;
            }
            $stmnum++;
        }

        my %vars;
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            foreach my $var (keys %vars) {
                if ($rhs =~ /$var/) {
                    $transform .= "stm$stmnum Inline $var ";
                }
            }
            if (! ($rhs =~/\(.*\(.*\(/) && $eq ne "===" && ! ($rhs =~/$lhs/)) {
                $vars{$lhs}=$rhs;
            } else {
                (exists $vars{$lhs}) && (delete $vars{$lhs});
            }
            $stmnum++;
        }

        %vars=();
        my $progB = $progA;
        $stmnum=1;
        while ($progB =~ s/^([^;]+); //) {
            my $stmA = $1;
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || die "Illegal statement in dead code check: $stmA\n";
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            if ($progB =~/$lhs/ || $eq eq "===") {
            } else {
                $transform .= "stm$stmnum Deletestm ";
            }
            $stmnum++;
        }

        my %expr=();
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
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S.*)$/ || next;
            $stmA = $1;
            foreach my $key (keys %expr) {
                if (0.01 < (1.0-6.0/$expr{$key})) {
                    if (! ($stmA =~/= \( \Q$key\E \) *$/) && ($stmA =~ /\( \Q$key\E \)/)) {
                        $key=~tr/[A-Z] /[a-z]_/;
                        $transform .= "stm$stmnum Newtmp path $key ";
                    }
                }
            }
            $stmnum++;
        }

        %vars=();
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $lhs = $1;
            my $eq = $2;
            my $rhs = $3;
            foreach my $var (keys %vars) {
                if ($rhs =~ s/\Q$vars{$var}\E/$var/g) {
                    $transform .= "stm$stmnum Usevar $var ";
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
            $stmnum++;
        }
   
        $stmnum=1;
        foreach my $stmA (split /;/,$progA) {
            $stmA =~/^\s*(\S+) (=+) (\S.*\S) *$/ || next;
            my $rhs = $3;
            $transform .= AllPossibleAxioms($rhs,$stmnum,"N");
            $stmnum++;
        }
        return $transform;
    }

    $progA =~s/^\( (..) // || return "";
    $op = $1;
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
        $progA =~s/^\s*(\S+)\s*// ;
        if ($1 ne ")") {
            $right = $1;
        }
    }

    if (($leftop eq "-s" || $leftop eq "/s") && $leftleft eq $leftright) {
        $transform .= "stm$stmnum Cancel ${path}l ";
    }

    if (($rightop eq "-s" || $rightop eq "/s") && $rightleft eq $rightright) {
        $transform .= "stm$stmnum Cancel ${path}r ";
    }

    if (($leftop eq "-m" || $leftop eq "-v") && $leftleft eq $leftright) {
        $transform .= "stm$stmnum Cancel ${path}l ";
    }

    if (($rightop eq "-m" || $rightop eq "-v") && $rightleft eq $rightright) {
        $transform .= "stm$stmnum Cancel ${path}r ";
    }

    if ($op eq "*m" && (($leftleft eq $right && $leftop eq "im") ||
                        ($rightleft eq $left && $rightop eq "im"))) {
        $transform .= "stm$stmnum Cancel ${path} ";
    }

    if ((($op eq "+s" && ($left eq "0s" || $right eq "0s")) ||
         ($op eq "-s" && $right eq "0s") ||
         ($op =~ /\*./ && ($left eq "1s" || $right eq "1s")) ||
         ($op eq "/s" && $right eq "1s"))) {
        $transform .= "stm$stmnum Noop ${path} ";
    }

    if ((($op eq "+m" && ($left eq "0m" || $right eq "0m")) ||
         ($op eq "-m" && $right eq "0m"))) {
        $transform .= "stm$stmnum Noop ${path} ";
    }

    if ($op eq "*m" && (($left eq "Im" && ($rightop =~ /.m/ || $right =~ /^([0I]m|m\d+)/)) || ($right eq "Im" && ($leftop =~ /.m/ || $left =~ /^([0I]m|m\d+)/)))) {
        $transform .= "stm$stmnum Noop ${path} ";
    }

    if ((($op eq "+v" && ($left eq "0v" || $right eq "0v")) ||
         ($op eq "-v" && $right eq "0v"))) {
        $transform .= "stm$stmnum Noop ${path} ";
    }

    if ((($op eq "*s" && ($left eq "0s" || $right eq "0s")) ||
                         ($op eq "/s" && $left eq "0s"))) {
        $transform .= "stm$stmnum Multzero ${path} ";
    }

    if (($op eq "*m" && ($left eq "0m" || $right eq "0m" || $left eq "0s" || $right eq "0s"))) {
        $transform .= "stm$stmnum Multzero ${path} ";
    }

    if (($op eq "*v" && ($left =~/^0[msv]/ || $right =~/^0[msv]/))) {
        $transform .= "stm$stmnum Multzero ${path} ";
    }

    if (($op eq "*m") && ($leftop =~/\+./ || $leftop =~/-./)) {
        $transform .= "stm$stmnum Distribleft ${path} ";
    }

    if (($op eq "*m") && ($rightop =~/\+./ || $rightop =~/-./)) {
        $transform .= "stm$stmnum Distribright ${path} ";
    }

    if (($op =~/\*[vs]/ || $op eq "/s") && ($leftop =~/\+./ || $leftop =~/-./)) {
        $transform .= "stm$stmnum Distribleft ${path} ";
    }

    if (($op =~/\*[vs]/) && ($rightop =~/\+./ || $rightop =~/-./)) {
        $transform .= "stm$stmnum Distribright ${path} ";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftleft eq $rightleft) && ($leftop =~/\*./)) {
        $transform .= "stm$stmnum Factorleft ${path} ";
    }

    if (($op =~/[\+\-]./) && ($leftop eq $rightop) && ($leftright eq $rightright) && ($leftop =~/[\*\/]./)) {
        $transform .= "stm$stmnum Factorright ${path} ";
    }

    if (($op =~/\*./ && $rightop =~ /\*./) ||
        ($op =~/\+./ && $rightop =~/[\-+]./) ||
        ($op =~ /\*s/ && $rightop eq "/s")) {
        $transform .= "stm$stmnum Assocleft ${path} ";
    }

    if (($op =~/\*./ && $leftop =~ /\*./) ||
        ($op =~/[\-+]./ && $leftop =~/\+./) ||
        ($op eq "/s" && $leftop =~/\*s/)) {
        $transform .= "stm$stmnum Assocright ${path} ";
    }
  
    if ((($op eq "nv" && $leftop eq "-v") ||
         ($op eq "ns" && $leftop eq "-s") ||
         ($op eq "is" && $leftop eq "/s") ||
         ($op eq "nm" && $leftop eq "-m"))) {
        $transform .= "stm$stmnum Flipleft ${path} ";
    }

    if ((($op eq "-s" && $rightop =~/[\-n]s/) ||
         ($op eq "/s" && $rightop =~/[\/i]s/) ||
         ($op eq "-m" && $rightop =~/[\-n]m/) ||
         ($op eq "-v" && $rightop =~/[\-n]v/))) {
        $transform .= "stm$stmnum Flipright ${path} ";
    }
    if ($op eq "*m") {
        $transform .= "stm$stmnum Transpose ${path} ";
    }
    if ((($op eq "-m") || ($op eq "+m"))) {
        $transform .= "stm$stmnum Transpose ${path} ";
    }
    if (($op eq "tm") && ($leftop eq "*m")) {
        $transform .= "stm$stmnum Transpose ${path} ";
    }
    if (($op eq "tm") && (($leftop eq "-m") || ($leftop eq "+m"))) {
        $transform .= "stm$stmnum Transpose ${path} ";
    }
    if ($right eq "") {
        if ($leftop eq $op) {
            $transform .= "stm$stmnum Double ${path} ";
        }
        return $transform.AllPossibleAxioms($left,$stmnum,$path."l");
    }

    my $dont_commute=0;
    if ($op =~/-./ || $op eq "/s" ||
            ($op eq "*m" && !($leftop =~ /^.s/ || $left =~ /^([01][ms]|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01][ms]|s\d+)/)) ||
            ($op eq "*v" && !($leftop =~ /^.s/ || $left =~ /^([01]s|s\d+)/ || $rightop =~ /^.s/ || $right =~ /^([01]s|s\d+)/))) {
        $dont_commute = 1;
    }
    if ($left ne $right && !$dont_commute) {
            $transform .= "stm$stmnum Commute ${path} ";
    }
    return $transform.AllPossibleAxioms($left,$stmnum,$path."l").AllPossibleAxioms($right,$stmnum,$path."r");
}

1;
