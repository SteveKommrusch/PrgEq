#!/bin/bash
if [ ! -f $1 ]; then
    echo "Usage: greps.sh name"
    echo "       Reports number of samples with decreasing proof lengths."
    exit 0
fi

 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z].*[A-Z]"
 grep -v "Z.*[A-Z].*[A-Z]" $1 | grep -c "Z.*[A-Z]"
