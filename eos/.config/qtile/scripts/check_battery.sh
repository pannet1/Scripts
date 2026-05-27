#!/bin/sh

#start notifier script
~/.config/qtile/scripts/low_bat_notifier.sh

#low battery level, you can modify it
low_bat=20

#Do not modify these variables
charging="fully-charged"
not_charging="discharging"
bat_now=$(cat /sys/class/power_supply/BAT0/capacity)
check=2

#I check if the battery is not charging, the script is not running and the battery
#perchantage is higher than low battery or if the battery was charging before.
#In this way the user can receive notification each time the battery level is low
#without spamming notifications

# Infinite loop to check battery status
while true; do
  check_running=$(pgrep -fl low_battery.sh)
  state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}')
  bat_now=$(cat /sys/class/power_supply/BAT0/capacity)

  if [ "$state" = "$charging" ]; then
    check=1
    sleep 30
  elif [ "$state" = "$not_charging" ] && [ -z "$check_running" ] && ([ "$bat_now" -gt "$low_bat" ] || [ "$check" -lt 2 ]); then
    # No operation needed, continue to the next iteration
    :
  else
    ~/.config/qtile/scripts/low_bat_notifier.sh
    sleep 30
  fi
done
