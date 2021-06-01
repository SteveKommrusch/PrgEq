#!/bin/bash

if [ ! -f $1 ]; then
    echo "Usage: srcvaltest.sh all_name.txt"
    echo "       Creates src-*, val-*, and tgt-* files for OpenNMT use."
    exit 0
fi
f=$1

# Train and validate include training for all axiom steps
perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 100 == 5) {$p=1} else {$p=0}}; $p && print; $last=$this' $f | shuf > all_trainval.txt
# Test cases only print the original start and end programs
perl -ne '/Y (.*) Z/; $this=$1; if ((!$last || $last ne $this)) { $n++; if ($n % 100 != 5) {print}}; $last=$this' $f | shuf | head -n 60000 > all_test.txt

perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | head -n 1000 > src-train.txt
perl -ne '/^(.*) X / && print $1."\n"' all_trainval.txt | tail -n 1000 > src-val.txt
perl -ne '/^(.*) X / && print $1."\n"' all_test.txt > src-test.txt
perl -ne '/X (.*) Z / && print $1."\n"' all_trainval.txt | head -n 1000 > src-trainx.txt
perl -ne '/X (.*) Z / && print $1."\n"' all_test.txt > src-testx.txt
perl -ne '/X (.*) Z / && print $1."\n"' all_trainval.txt | tail -n 1000 > src-valx.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | head -n 1000 > tgt-train.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_trainval.txt | tail -n 1000 > tgt-val.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' all_test.txt > tgt-test.txt

ln -sf ${f/all_/raw_} raw_link
perl -e 'open($all,"<","all_test.txt"); while (<$all>) { /X (.* Y .*) Z (.*)$/ || die; $full{$1}=1; }; open($raw,"<","raw_link"); while (<$raw>) { /X (.* Y .*) Z (.*)$/ || die; if ($full{$1}) { print } }' > all_test_fullaxioms.txt

for i in 1 2 3 4 5 6; do head -n ${i}0000 all_test_fullaxioms.txt | tail -n 10000 > tune_b${i}_fullaxioms.txt; done

grep "^X .* Y .* Z " raw_template.txt | shuf | head -n 40000 > template_fullaxioms.txt

head -n 10000 template_fullaxioms.txt | tail -n 10000 > tune_b7_fullaxioms.txt
head -n 20000 template_fullaxioms.txt | tail -n 10000 > tune_b8_fullaxioms.txt
head -n 30000 template_fullaxioms.txt | tail -n 10000 > tune_b9_fullaxioms.txt
head -n 40000 template_fullaxioms.txt | tail -n 10000 > tune_b10_fullaxioms.txt

../../src/possibleAxioms.pl all_test.txt > all_test_possible.txt
perl -ne '/Y (.*) (.*) Z/ || die; $c[int($1/5)][int($2/5)] += 1; if ($. == 60000) { for ($i=0; $i< 25; $i++) { printf "%3d ",$i*5; for ($j=1; $j < 21; $j++) { if (!$i) { printf "%4d",$j*5; } else { printf "%4d",$c[$i][$j]+0 } } print "\n"; } }' all_test_possible.txt > table.txt
