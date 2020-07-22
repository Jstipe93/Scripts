#!/bin/sh

wait_time=60

idx=''
while [ "$idx" = '' - a "$wait_time" -gt 0 ]; do
  idx=$(modem idx)
  [ "$idx" ] && break
  wait_time=$((wait_time - 1))
  sleep 1
done

if [ "$idx" ]; then
  case $(sim) in
  1)# Tmobile
  if !modem at '#mbimcfg?' | grep "1$"; then
    accns_log w 'modem mbimcfg needs updating to 1. doing so now'
    modem at '#mbimcfg=1'
    modem reset
  fi
  ;;
  2)# Verizon
  if !modem at '#mbimcfg?' | grep "3$"; then
    accns_log w 'modem mbimcfg needs updating to 3. doing so now'
    modem at '#mbimcfg=3'
    modem reset
  fi
  ;;
  esac
fi
