#!/bin/sh

# Test the IP passthrough lan interface with a ping test.  Keep a count of failed tests.
# If this test fails for two times in a row, then bring the interface down and up 

#Find passthrough ip
iface="$(runt get network.interface.modem.device)"
passthrough_ip="$(runt get network.device.$iface.network.passthrough)"
echo $passthrough_ip

# Adjustable settings
lan_ip='192.168.210.1'  # where we perform the ping tests to
fail_count_file='/tmp/custom_lan_interface_test_fail_count.txt'
fail_count_limit=‘2’  # number of sequential failures that can occur before resetting

test_failed() {
  try=$((try+1))
  echo "$try" > "$fail_count_file"
  accns_log w config "custom: lan interface test failed ($1 - try $try)"
}

test_passed() {
  rm -f "$fail_count_file"
  try=0
  # Note: uncomment the following line if you want to log successful tests
  accns_log w config "custom: lan interface test passed"
}

try=$(cat "$fail_count_file" 2> /dev/null)
try=${try:-0}

# make sure $try is an integer. set to zero if not
case $try in
  ''|*[!0-9]*)
    try=0
    ;;
esac

# do the lan test
if ping -q -c 1 -W 10 -s 1 "$passthough_ip” > /dev/null; then
  test_passed
else
  test_failed "ping failure to IP $passthrough_ip”
fi

# reset if failed test count is greater than specified limit
if [ "$try" -ge "$fail_count_limit" ]; then
  # note, that we don't reset the fail count. If we fail next attempt, try to reset again.
  ifconfig lan down 
  echo “bringing lan interface down and sleeping for 15“
  sleep 15
  ifconfig lan up 
  echo “bringing lan interface back up“
fi
