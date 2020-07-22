##Synnex made it into remote manager script

#flash party lights (LTE LED white/yellow and cylon signal bars) to indicate success
cycle_leds() {
  count='86400' #pattern below takes 2 seconds to complete, so run the pattern for 24 hours
  while [ "$count" -gt '0' ]; do
    count="$((count-1))"
    for p in \
            "o o o o O O O O" "o o o o o O O O" "o o o O o o O O" "o o o O O o o O" "o o o O O O o o" \
      "o o o O O O O o" "o o o O O O O O" "o O o O O O O o" "o O o O O O o o" "o O o O O o o O" \
      "o O o O o o O O" "o O o o o O O O" "o O o o O O O O" "o O o O O O O O"; do
         set $p
     ledcmd -$4 RSS1 -$5 RSS2 -$6 RSS3 -$7 RSS4 -$8 RSS5
     usleep 100000
    done
  done
}

### DO THE SIM STUFF HERE

cycle_leds
