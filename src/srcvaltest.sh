#!/bin/bash

if [ ! -f $1 ]; then
    echo "Usage: srcvaltest.sh all_name.txt"
    echo "       Creates src-*, val-*, and tgt-* files for OpenNMT use."
    exit 0
fi
f=$1

# Train and validate include training for all axiom steps
perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 10 != 5) {$p=1} else {$p=0}}; $p && print; $last=$this' $f | shuf > all_trainval.txt
# Test cases only print the original start and end programs
perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 10 == 5) {print}}; $last=$this' $f | head -n 1000 > all_test.txt

perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | head -n 200000 > src-train.txt
perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | tail -n 1000 > src-val.txt
perl -ne '/^(.*) X / && print $1."\n"' all_test.txt > src-test.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | head -n 200000 > tgt-train.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | tail -n 1000 > tgt-val.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_test.txt > tgt-test.txt

ln -sf ${f/all_/raw_} raw_link
perl -e 'open($all,"<","all_test.txt"); while (<$all>) { /X (.* Y .*) Z (.*)$/ || die; $full{$1}=1; }; open($raw,"<","raw_link"); while (<$raw>) { /X (.* Y .*) Z (.*)$/ || die; if ($full{$1}) { print } }' > all_test_fullaxioms.txt

../../src/possibleAxioms.pl all_test.txt > all_test_possible.txt
perl -ne '/Y (.*) (.*) Z/ || die; $c[$1][$2] += 1; if ($. == 1000) { for ($i=0; $i< 56; $i++) { printf "%3d ",$i; for ($j=1; $j < 36; $j++) { if (!$i) { printf "%4d",$j; } else { printf "%4d",$c[$i][$j]+0 } } print "\n"; } }' all_test_possible.txt > table.txt

