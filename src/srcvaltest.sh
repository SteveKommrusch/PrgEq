#!/bin/bash

if [ ! -f ../../data/$1_multipass.txt ]; then
    echo "Usage: srcvaltest.sh name"
    echo "       Creates name_trainval.txt and name_test.txt files if needed"
    echo "       Createst src-* and tgt-* files for OpenNMT use"
    exit 0
fi
f=../../data/$1

if [ ! -f ${f}_trainval.txt ]; then
    perl -ne '/Y (.*) Z/ && ($this=$1); if ((!$last || $last ne $this)) { $n++; if ($n % 50 != 10) {$p=1} else {$p=0}}; $p && print; $last=$this' ${f}_multipass.txt | shuf > ${f}_trainval.txt
    perl -ne '/Y (.*) Z/ && ($this=$1); if ((!$last || $last ne $this)) { $n++; if ($n % 50 == 10) {print}}; $last=$this' ${f}_multipass.txt | head -n 10000 > ${f}_test.txt
fi

perl -ne '/^(.*) X / && print $1."\n"' ${f}_trainval.txt > src.txt
head -n 1000000 src.txt > src-train.txt
head -n 1010000 src.txt | tail -n 10000 > src-val.txt
perl -ne '/^(.*) X / && print $1."\n"' ${f}_test.txt | head -n 10000 > src-test.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' ${f}_trainval.txt > tgt.txt
head -n 1000000 tgt.txt > tgt-train.txt
head -n 1010000 tgt.txt | tail -n 10000 > tgt-val.txt
perl -ne '/Z (.*)\s*$/ && print $1."\n"' ${f}_test.txt | head -n 10000 > tgt-test.txt

