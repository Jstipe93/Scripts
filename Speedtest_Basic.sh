#!/bin/sh
# run a speed test to the given server,  server must be an IP address
server=$(config get cloud.aview.speedtest_server)
results='speedtest'
if [ "$(expr "$server" : '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}$')" -eq 0 ]; then
  server=$(resolveip $server)
 fi
if [ "$(expr "$server" : '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}$')" -eq 0 ]; then
    echo "usage: $0 <ip-address-of-test-server>" >&2
    accns_log w speed "Speed test failed: invalid server"
    exit 1
fi


tx_output=$(timeout -t 45 nuttcp -T1m -N4 -fparse $server 2>&1 | grep rate_Mbps)
rx_output=$(timeout -t 45 nuttcp -F -r -T1m -N4 -fparse $server 2>&1 | grep rate_Mbps)


eval $tx_output
results="$results~tx_avg=${rate_Mbps}Mbps"
results="$results~tx_latency=${rtt_ms}ms"


eval $rx_output
results="$results~rx_avg=${rate_Mbps}Mbps"
results="$results~rx_latency=${rtt_ms}ms"

accns_log speed "$results"

exit 0
