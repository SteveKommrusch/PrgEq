#! /bin/bash

if [ ! -f $OpenNMT_py/train.py ]; then
    echo "OpenNMT_py environment variable should be set"
    exit 1
fi
if [ ! -d tr_$1 ]; then
    echo "tr_$1 must be a directory"
    exit 1
fi
d=$1
rm -f tr_$d/xlatechk.out
hostname
hostname > tr_$d/train.out
onmt_train --config eq_$d.yaml >> tr_$d/train.out 2>&1 &
sleep 10
while jobs | grep -q Running; do
  w=`who`
  if [[ $w == *`date +"%m-%_d"`* || $w == *`date --date="4 hours ago" +"%m-%_d"`* ]] ; then
    echo Pause job at `date`
    kill -STOP %1
    while [[ $w == *`date +"%m-%_d"`* || $w == *`date --date="4 hours ago" +"%m-%_d"`* ]] ; do
      sleep 20
      w=`who`
    done
    echo Continue job at `date`
    kill -CONT %1
  fi
  sleep 10
done
echo "onmt_train complete" >> tr_$d/train.out
w=`who`
while [[ $w == *`date +"%m-%_d"`* || $w == *`date --date="4 hours ago" +"%m-%_d"`* ]] ; do
  sleep 20
  w=`who`
done
onmt_translate -model tr_$d/model_step_100000.pt -src src-test.txt -output tr_$d/xlate.txt -gpu 0 -replace_unk -beam_size 5 -n_best 5 -batch_size 4 -verbose > tr_$d/xlate.out 2>&1
cd tr_$d
../../../src/xlatechk.pl -v > xlatechk.out
