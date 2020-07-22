#!/bin/sh

#check for the 1st and 15th of the month
date > /tmp/test_date.tx
variable_a=$(date +%e | tr -d ' ')
if [ "$variable_a" = '1' ] || [ "$variable_a" = '15' ]; then
  server=$(config get cloud.aview.speedtest_server)
    if [ "$(expr "$server" : '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}$')" -eq 0 ]; then
      server=$(resolveip $server)
    fi
    if [ "$server" ]; then
      accns_log speed $(/bin/speedtest $server | tr '\n' '~' | sed 's/~$//')
    else
      accns_log w speed "Speed test failed: invalid server)"
    fi
fi
exit 0
