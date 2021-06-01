#!/bin/bash
if [ ! -f $1 ]; then
    echo "Usage: greps.sh name"
    echo "       Reports number of samples with decreasing proof lengths."
    exit 0
fi

perl -e '$maxax=0; while(<>) { s/Target path:.*$//; / (stm.*[A-Z])/; $numax=-1 + scalar split /stm\d/,$1; $maxax= $numax if $numax > $maxax; $axioms[$numax]++; $n++ }; for ($i=1; $i <=$maxax; $i++) { print "$i axioms: $axioms[$i]\n" }; print "Total: $n\n"' $1

