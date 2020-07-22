#!/bin/sh                                                                                                    

##################################################################
#exec 2> /dev/console
#set -x
##################################################################
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

case "$1" in
start|reload)
        ;;
stop)
        exit 0
        ;;
*)
        echo "Usage: $0 {start|stop|reload}"
        exit 1
        ;;
esac

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
    if [ ! -e $NEXT_REPORT_MINUTE -o $reportInterval != "$(cat "$REPORT_INTERVAL" 2>/dev/null)" ]; then
        mkdir -p $METRICS_REPORTS_FOLDER
        set_first_report_time
        runt update metrics
        echo $reportInterval > $REPORT_INTERVAL
    else
        nextReportMinute=$(cat $NEXT_REPORT_MINUTE)
        if [ $now -gt $nextReportMinute ]; then # we generate reports with a one sample delay so any sample time jitter is n
            set_next_report_time
            schedule_report                     # we're at least one minute past due, report using previously collected data
        fi
        runt update metrics
    fi
fi
exit 1
