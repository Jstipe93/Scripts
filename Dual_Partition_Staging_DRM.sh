#Synnex staging in aview dual partition, then moving over to Remote Manager after both partitions stage

#!/bin/sh

# wait for device to pull its config from aView.  Verify it's updated its
# firmware to match what it listed in the aView config.  Then write that
# firmware to the secondary firmware partition, so both partitions have
# the same firmware

# set as a task to run once every 10 minutes

# NOTE: this script cannot be used in conjunction with the
# reset_unit_default_passwd.sh script, as making a manual config change
# removes the /etc/config/accns.cache file.  If you want to make
# a manual configuration change, then do so in this script, but after
# the `if` statement that looks to see if the accns.cache file is present

# wait for device to pull it's config from aView before checking firmware
if [ -f '/etc/config/accns.cache' ]; then
    if [ -f '/etc/config/double_firmware_write.flag' ]; then
        accns_log w config "FW_FLASHED: Firmware $(runt get system.version) written to both partitions, moving to DigiRM"
        config set cloud.enable true
        config set cloud.service drm
        # turn off signal LEDs and flash LTE green when done
        #ledcmd -f ETH -O ONLINE -O COM -O RSS1 -O RSS2 -O RSS3 -O RSS4 -O RSS5
    else
        # re-download firmware and apply it to secondary firmware partition
        aview_firmware="$(config get firmware.version)"
        current_firmware="$(cat /etc/version | awk '{ print $3 }')"
        if [ "$aview_firmware" = "$current_firmware" ]; then
            hardware_version=$(cat /etc/version | awk '{ print $1 }') 
            base_url="$(config get firmware.base_url)"
            url=$base_url/device_firmware/$hardware_version/$aview_firmware
            request_result="$(curl -sfkLo /tmp/$aview_firmware.bin $url)"
            status=$?
            [ "$status" -ne "6" ] && [ -f "/tmp/$aview_firmware.bin" ] && netflash -b -k -U /tmp/$aview_firmware.bin >/dev/null 2>&1
            status=$?
            if [ "$status" -eq "0" ]; then
                accns_log w config "Firmware applied to both partitions.  Rebooting...."
                touch /etc/config/double_firmware_write.flag
                reboot_managed '/sbin/reboot' "Firmware update~old=$current_firmware~new=$aview_firmware"
            else
                accns_log w config "Failure to update secondary firmware partition: $status. Power cycle device and try again"
            fi
        else
            accns_log w config "Waiting for device to auto-upgrade to firmware version $aview_firmware before applying firmware to secondary partition"
        fi
    fi
fi
