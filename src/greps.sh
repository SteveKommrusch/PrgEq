#!/bin/bash
if [ ! -f $1 ]; then
    echo "Usage: greps.sh name"
    echo "       Reports number of samples with decreasing proof lengths."
    exit 0
fi

perl -e '$maxax=0; while(<>) { /Z (stm.*[A-Z])/; $numax=scalar split /stm/,$1; $maxax= $numax if $numax > $maxax; $axioms[$numax]++; $n++ }; for ($i=1; $i <=$maxax; $i++) { print "$i axioms: $axioms[$i]\n" }; print "Total: $n\n"' $1

 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm.*stm"
 grep -v "Z.*stm.*stm.*stm" $1 | grep -c "Z.*stm.*stm"
 grep -v "Z.*stm.*stm" $1 | grep -c "Z.*stm"
