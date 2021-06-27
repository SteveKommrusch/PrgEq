#!/bin/bash

if [[ ! -z $1 || ! -d "b10" ]]; then
    echo "Usage: srcvaltest_find.sh"
    echo "       Creates src-*, val-*, and tgt-* files for OpenNMT use."
    exit 0
fi

rm -f */search_[sptr][ra]*.??t
rm -f raw_tune.txt raw_xtra.txt
for i in b1 b2 b3 b4 b5 b6 b7 b8 b9 b10; do
  cat $i/tune??_2.txt $i/tune??_20.txt | perl -ne '/^Search done. Found/ && ($l=1); if (/FOUND: (.*) with\s+(.*) Target path:/) { $f=$2; $p=$1; $n=scalar split /stm\d/,$f; if ($l) {s/FOUND:/X/; s/ to / Y /; s/ with\s+/ Z /; s/Target path:.*$//; if (! exists $fndsml{$p}) {print} elsif ($n <= $fndsml{$p} - 2) { $ax[$n]++; if (/stm20/ || /stm19/ || / N[lr][lr][lr]/ || / Newtmp/ || / Factor/) {print} else {$ax[$n] <= ($n*7) && print }}} else {$fndsml{$p}=$n}}' >> raw_tune.txt

  perl -ne 'if (/^RARE:.* Z .* N[lr][lr][lr][lr]/) { s/RARE: //; print }' $i/tune??_20.txt >> raw_xtra.txt
done

cp raw_xtra.txt pre1axiom_tune.out
../../../src/pre1axiom.pl 225 raw_tune.txt >> pre1axiom_tune.out
shuf pre1axiom_tune.out > shuf.out

perl -ne '/X (.*) Z / && print $1."\n"' shuf.out | head -n -100 > src-traint.txt;
perl -ne '/Z (.*\S)\s*$/ && print $1."\n"' shuf.out | head -n -100 > tgt-traint.txt;
perl -ne '/X (.*) Z / && print $1."\n"' shuf.out | tail -n 100 > src-valt.txt;
perl -ne '/Z (.*\S)\s*$/ && print $1."\n"' shuf.out | tail -n 100 > tgt-valt.txt;

