#!/bin/bash

if [ ! -f $1 ]; then
    echo "Usage: srcvaltest.sh name"
    echo "       Creates src-*, val-*, and tgt-* files for OpenNMT use."
    exit 0
fi
f=$1

perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 50 != 10) {$p=1} else {$p=0}}; $p && print; $last=$this' $f | shuf > all_trainval.txt
perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 50 == 10) {print}}; $last=$this' $f | head -n 10000 > all_test.txt

perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | head -n 1000000 > src-train.txt
perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | tail -n 10000 > src-val.txt
perl -ne '/^(.*) X / && print $1."\n"' all_test.txt > src-test.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | head -n 1000000 > tgt-train.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | tail -n 10000 > tgt-val.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_test.txt > tgt-test.txt

ln -s ${f/all_/raw_} raw_link
perl -e 'open($all,"<","all_test.txt"); while (<$all>) { /X (.* Y .*) Z (.*)$/ || die; $full{$1}=1; }; open($raw,"<","raw_link"); while (<$raw>) { /X (.* Y .*) Z (.*)$/ || die; if ($full{$1}) { print } }' > all_test_fullaxioms.txt

../../src/possibleAxioms.pl all_test.txt > all_test_possible.txt
perl -ne '/Y (.*) (.*) Z/ || die; $c[$1][$2] += 1; if ($. == 10000) { for ($i=0; $i< 56; $i++) { printf "%3d ",$i; for ($j=1; $j < 36; $j++) { if (!$i) { printf "%4d",$j; } else { printf "%4d",$c[$i][$j]+0 } } print "\n"; } }' all_test_possible.txt > table.txt

