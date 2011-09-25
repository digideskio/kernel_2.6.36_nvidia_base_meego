#!/bin/bash -e

sudo mic-image-creator --config=tablet-armv7hl-tegra2-v02-1.2.0.0.0.20110518.3.ks --arch=armv7hl --format=raw -d -v --logfile=mic-test-tablet-1.2.0.0.20110518.log --run-mode=1
