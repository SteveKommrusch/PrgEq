#!/bin/bash

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
