#Offline_Connectivity_Test

#!/bin/sh

# Minimum firmware version: 17.5.108.6
# Test the cellular connection with a ping test.  Keep a count of failed tests.
# If this test fails for four times in a row, then reset the modem.

# Adjustable settings
ping_server1='128.136.167.120'                          # where we perform the ping tests to
ping_server2='8.8.8.8'                                  # where we perform the ping tests to
test_server1='firmware.accns.com'                       # where we perform the HTTP tests to
test_server2='google.com'                               # where we perform the HTTP tests to
fail_count_file='/tmp/custom_cell_test_fail_count.txt'  # local file that stores the number of consecutive failed tests
fail_count_limit='3'                                    # number of concurrent failures that can occur before resetting
fail_count_limit2='6'                                  # number of concurrent failures that can occur before rebooting device

test_failed() {
  try=$((try+1))
  echo "$try" > "$fail_count_file"
  accns_log w config "custom: cell test failed ($1 - try $try)"
}

test_passed() {
  rm -f "$fail_count_file"
  try=0
  # Note: uncomment the following line if you want to log successful tests
  accns_log w config "custom: cell test to $1 passed"
}

try=$(cat "$fail_count_file" 2> /dev/null)
try=${try:-0}

# make sure $try is an integer. set to zero if not
case $try in
  ''|*[!0-9]*)
    try=0
    ;;
esac

# do the connectivity test
if ! modem cli 2>&1 | grep -q "connected"; then
  test_failed "Modem does not have cell connection"
elif ping -q -c 1 -W 10 -s 1 "$ping_server1" > /dev/null; then
  test_passed "$ping_server1"
elif ping -q -c 1 -W 10 -s 1 "$ping_server2" > /dev/null; then
  test_passed "$ping_server2"
elif curl -sfkLm 60 "https://$test_server1" > /dev/null; then
  test_passed "$test_server1"
elif curl -sfkLm 60 "https://$test_server2" > /dev/null; then
  test_passed "$test_server2"
else
  test_failed "ping failure to $ping_server1,$ping_server2 and HTTP failure to $test_server1,$test_server2"
fi

# reset if failed test count is greater than specified limit
if [ "$try" -ge "$fail_count_limit" ]; then
  # note, that we don't reset the fail count. If we fail next attempt, try to reset again.
  modem reset
fi

#power off/on modem if failed test count is greater than specified limit2
if [ "$try" -ge "$fail_count_limit2" ]; then
  # note, that we don't reset the fail count. If we fail next attempt, try to reset again.
sbin/reboot
fi
