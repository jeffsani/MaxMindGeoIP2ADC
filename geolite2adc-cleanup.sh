#!/bin/bash
# geolite2adc-cleanup.sh
# This script will remove old logs so they do not consume your disk
# See geoliteadc-init.sh for more information on scheduled cron task

find *.log -type f -not -name '*maxmindgeolite2adc-init.log'-delete