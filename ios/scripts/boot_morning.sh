#!/bin/sh
# Boots a simulator in a time zone where it is 9 in the morning now, to match the 9:41 status bar.
# The demo then shows a morning greeting, wait timer and breakfast time whenever screenshots are taken.
# The simulator must be shut down first: a running one keeps its time zone.
set -e
udid="$1"
h=$(date -u +%H); h=${h#0}
n=$(( 9 - h )); [ "$n" -lt -12 ] && n=$(( n + 24 ))
# Etc/GMT counts the other way: Etc/GMT-9 is nine hours ahead of UTC.
if [ "$n" -ge 0 ]; then zone="Etc/GMT-$n"; else zone="Etc/GMT+$(( -n ))"; fi
echo "Simulator time zone: $zone"
SIMCTL_CHILD_TZ="$zone" xcrun simctl boot "$udid" || true
