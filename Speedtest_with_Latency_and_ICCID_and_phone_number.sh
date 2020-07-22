#!/bin/sh

# Wait 3 minutes for device to get a cellular connection

#sleep 180

# Run speedtest

server=$(config get cloud.aview.speedtest_server)
if [ "$(expr "$server" : '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}$')" -eq 0 ]; then
  server=$(resolveip "$server")
fi
if [ "$server" ]; then
  tx_output=$(timeout 45 nuttcp -T15 -w1m -fparse "$server" 2>&1 | grep rate_Mbps)
  tx_latency=$(timeout 45 nuttcp -T15 -w1m -fparse "$server" 2>&1 | grep rtt_ms)
  rx_output=$(timeout 45 nuttcp -F -r -T15 -w1m -fparse "$server" 2>&1 | grep rate_Mbps)
  rx_latency=$(timeout 45 nuttcp -F -r -T15 -w1m -fparse "$server" 2>&1 | grep rtt_ms)
else
  exit
fi

[ "$rx_output" ] || exit
[ "$rx_latency" ] || exit
[ "$tx_output" ] || exit
[ "$tx_latency" ] || exit
eval "$tx_output"
tx=$(echo "$rate_Mbps" | cut -f1 -d '.')
eval "$tx_latency"
tx_ms=$(echo "$rtt_ms" | cut -f1 -d '.')
eval "$rx_output"
rx=$(echo "$rate_Mbps" | cut -f1 -d '.')
eval "$rx_latency"
rx_ms=$(echo "$rtt_ms" | cut -f1 -d '.')

### CSV script ###

readonly METRICS_FOLDER="/var/metrics"
readonly METRICS_REPORTS_FOLDER="$METRICS_FOLDER/reports"
readonly REPORT_GENERATOR="/bin/report_metrics"
readonly REPORT_TEMPLATE="/etc/metrics_report.cfg"
readonly LOGGER="/usr/bin/logger" &> /dev/null
readonly RUNT_UPTIME="system.uptime.seconds_total"
readonly METRICS_SAMPLE_PERIOD="metrics.sample_period"
readonly METRICS_SAMPLE_WINDOW="metrics.sample_window"
readonly METRICS_UPTIME="metrics.uptime"
readonly METRICS_CONFIG_FOLDER="/etc/config/metrics"
readonly METRICS_SAVE_FOLDER="/etc/config/metrics/saved"
readonly REPORTED_BOOT_COUNT="$METRICS_CONFIG_FOLDER/reported_boot_count"
readonly REPORT_INTERVAL="$METRICS_FOLDER/report_interval"
readonly NEXT_REPORT_MINUTE="$METRICS_FOLDER/next_report"

log()
{
   ${LOGGER} -t metrics-reports -p "user.info" "$@"
}

set_first_report_time()
{
    echo $((now + ( ( reportInterval * 2 ) - 1 - $(expr $now % $reportInterval)) )) > $NEXT_REPORT_MINUTE
}

set_next_report_time()
{
    echo $((now + ( reportInterval - $(expr $now % $reportInterval)) )) > $NEXT_REPORT_MINUTE
}

schedule_report()
{
    local reportFileName;
    local uptime
    local
    local metricsWindow
    local bootCount
    local reportedBootCount
    mkdir -p $METRICS_REPORTS_FOLDER
    metricsSamplePeriod=$(runt get $METRICS_SAMPLE_PERIOD)
    metricsWindow=$(runt get $METRICS_SAMPLE_WINDOW)
    uptime=$(($(runt get $RUNT_UPTIME) - metricsSamplePeriod))
    if [ $uptime -gt $metricsWindow ]; then
        uptime=$metricsWindow
    fi
    runt set $METRICS_UPTIME $uptime
    reportTime=$((nextReportMinute * 60))
    reportFileName=$(date -d @$reportTime '+%Y_%m_%d_%H_%M_%S')  # reported data timestamp
    reportFileName="$METRICS_REPORTS_FOLDER/$reportFileName.csv"
    # NOTE : metricsSamplePeriod is added to the metrics window because we always generate
    # reports at least one sample late
    $REPORT_GENERATOR $REPORT_TEMPLATE $((metricsWindow+metricsSamplePeriod)) $reportTime > "$reportFileName"
    log "generated report $reportFileName"
    runt set metrics.boot_count 0                   # reset after first report
    reportedBootCount=$(cat "$REPORTED_BOOT_COUNT" 2>/dev/null)
    bootCount=$(runt get system.boot_count)
    if [ "0$reportedBootCount" -ne "0$bootCount" ]; then
        echo $bootCount > "$REPORTED_BOOT_COUNT"
    fi
}

now=$(($(date +%s)/60))                     # minutes since epoch (midnight)

eval $(config start)
config load
enabled=
if [ $(config get cloud.enable) -eq 1 ]; then
	if config exists cloud service; then
		[ "$(config get cloud.service)" = drm ] && enabled=1 || enabled=
	else
		enabled=1
	fi
fi
eval $(config stop)

if [ "$enabled" ]; then
	reportInterval=$(config get monitoring.devicehealth.interval); #minutes
        nextReportMinute=$(cat $NEXT_REPORT_MINUTE)
            set_next_report_time
            schedule_report                     # we're at least one minute past due, report using previously collected data
     #   runt update metrics
fi

### END CSV script ###

# Append speed test results to CSV and upload

iccid=$(modem runtget modem.iccid)
number=$(modem runtget modem.phone)
sim_slot=$(sim)

filename="/var/metrics/reports/$(ls -1tr /var/metrics/reports/ | tail -n 1)"
[ -f "$filename" ] || exit
timestamp=$(tail -n 1 "$filename" | cut -f5 -d',')
echo "/metrics/sys/speed/tx,$tx,INTEGER,Mbps,$timestamp" >> "$filename"
echo "/metrics/sys/speed/tx_ms,$tx_ms,INTEGER,ms,$timestamp" >> "$filename"
echo "/metrics/sys/speed/rx,$rx,INTEGER,Mbps,$timestamp" >> "$filename"
echo "/metrics/sys/speed/rx_ms,$rx_ms,INTEGER,ms,$timestamp" >> "$filename"
echo "/metrics/cellular/$sim_slot/sim/iccid,$iccid,INTEGER,,$timestamp" >> "$filename"
echo "/metrics/cellular/$sim_slot/sim/number,$number,INTEGER,,$timestamp" >> "$filename"
/bin/metrics_upload.sh
