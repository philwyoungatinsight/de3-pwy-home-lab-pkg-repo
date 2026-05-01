#!/bin/bash

#N=1800 # 30 minutes
N=300 # 5 minutes

while true; do
    echo "DATE=`date`"
    ./check_amt.sh
    sleep $N
done
