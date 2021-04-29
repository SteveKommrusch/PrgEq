#!/bin/bash

if [[ ! -z $1 || ! -f "b1/tune25_2.txt" ]]; then
    echo "Usage: srcvaltest_find.sh"
    echo "       Creates src-*, val-*, and tgt-* files for OpenNMT use."
    exit 0
fi

rm -f */search_[sptr][ra]*.??t
rm -f raw_tune.txt raw_xtra.txt
for i in b1 b2 b3 b4 b5 b6 b7 b8 b9 b10; do
  cat $i/tune25_2.txt $i/tune25_20.txt | perl -ne '/^Legal axiom prop/ && ($l=1); if ($l) {if (/FOUND: (.*) with\s+(.*) Target path:\s+(.*)$/) { $t=$3; $f=$2; $p=$1; $n=scalar split /stm/,$f; s/FOUND:/X/; s/ to / Y /; s/ with\s+/ Z /; s/Target path:.*$//; if (! exists $fndsml{$p}) {print} elsif ($n < (scalar split /stm/,$t)) { $ax[$n]++; if (/stm20/ || /stm19/ || / N[lr][lr][lr]/ || / Newtmp/ || / Factor/) {print} else {$ax[$n] <= ($n*5+10) && print }}}} else {/FOUND: (.*) with/ && ($fndsml{$1}=1);}' >> raw_tune.txt

  perl -ne 'if (/FAIL.*Target.* N[lr][lr][lr][lr]/ && ! /Target.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm.*stm/) { s/FAIL:/X/; s/ to / Y /; s/ bestguess.* Target path:\s+/ Z /; print }' $i/tune25_20.txt >> raw_xtra.txt
done
cat reversed/tune10_2.txt reversed/tune10_20.txt | perl -ne '/^Legal axiom prop/ && ($l=1); if ($l) {if (/FOUND: (.*) with\s+(.*) Target path:\s+(.*)$/) { $t=$3; $f=$2; $p=$1; $n=scalar split /stm/,$f; s/FOUND:/X/; s/ to / Y /; s/ with\s+/ Z /; s/Target path:.*$//; if (! exists $fndsml{$p}) {print} else { $ax[$n]++; if (/stm20/ || /stm19/ || / N[lr][lr][lr]/ || / Newtmp/ || / Factor/) {print} else {$ax[$n] <= ($n*5+10) && print }}}} else {/FOUND: (.*) with/ && ($fndsml{$1}=1);}' >> raw_tune.txt

../../../src/pre1axiom.pl 225 raw_tune.txt > pre1axiom_tune.out
../../../src/pre1axiom.pl 225 raw_xtra.txt | grep " N[lr][lr][lr][lr]" >> pre1axiom_tune.out
shuf pre1axiom_tune.out > shuf.out

perl -ne '/X (.*) Z / && print $1."\n"' shuf.out | head -n -200 > src-traint.txt;
perl -ne '/Z (.*\S)\s*$/ && print $1."\n"' shuf.out | head -n -200 > tgt-traint.txt;
perl -ne '/X (.*) Z / && print $1."\n"' shuf.out | tail -n 200 > src-valt.txt;
perl -ne '/Z (.*\S)\s*$/ && print $1."\n"' shuf.out | tail -n 200 > tgt-valt.txt;

