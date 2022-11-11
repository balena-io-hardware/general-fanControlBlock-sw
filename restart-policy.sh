#!/bin/bash

# This script manages restrart policy for Fan Block scrit
# This takes one argument which is the program to run, and will restart it
# when it crashes for a given amount of retries.

RETRIES=${RETRIES:-5}
LOCK=${LOCK:-1}

if [ -z $1 ]; then
  echo "Usage: $0 program_to_run"
  exit 0
fi

while [ $RETRIES -gt 0 ];do
  echo "Starting $1"
  $1
  RETRIES=$(($RETRIES - 1))
  echo "Program stopped, $RETRIES left"
done

if [ $LOCK -ne 0 ];then
  echo "Starting failed, locking"
  while : ; do
    sleep 3600
  done
fi
