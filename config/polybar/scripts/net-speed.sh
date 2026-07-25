#!/bin/sh
iface=${1:-wlan0}
rx1=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
sleep 1
rx2=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
bytes=$(( rx2 - rx1 ))
mb=$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")
echo "WRL ${mb} MB/s"
