#!/bin/bash -e

sudo mic-image-creator --config=$1 --arch=armv7hl --format=raw -d -v --logfile=$1.log --cache=../meego-cache --tmp=/tmp --run-mode=1
