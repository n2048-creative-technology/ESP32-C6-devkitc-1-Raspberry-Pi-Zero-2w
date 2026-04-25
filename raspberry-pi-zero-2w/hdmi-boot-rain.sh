#!/usr/bin/env bash

TTY="/dev/tty1"
DELAY="${1:-0.025}"

services=(
  "kernel" "systemd" "udevd" "NetworkManager" "wpa_supplicant"
  "vc4-drm" "mmc0" "usbcore" "ssh" "cron"
  "espnow-bridge" "uart-listener" "video-daemon" "gpu-render"
)

actions=(
  "Started service" "Reached target" "Mounted filesystem"
  "Initialized device" "Loaded kernel module" "Detected interface"
  "Created socket" "Started worker" "Queued job"
  "Processed frame" "Received packet" "Synced buffer"
  "Allocated DMA buffer" "Bound HDMI pipeline"
)

statuses=(
  "[  OK  ]" "[  OK  ]" "[  OK  ]" "[  OK  ]"
  "[ INFO ]" "[ WARN ]" "[FAILED]"
)

colors() {
  sed -u \
    -e 's/\[  OK  \]/\x1b[32m[  OK  ]\x1b[0m/g' \
    -e 's/\[FAILED\]/\x1b[31m[FAILED]\x1b[0m/g' \
    -e 's/\[ WARN \]/\x1b[33m[ WARN ]\x1b[0m/g' \
    -e 's/\[ INFO \]/\x1b[36m[ INFO ]\x1b[0m/g'
}

cleanup() {
  sudo sh -c "printf '\033[0m' > $TTY"
  exit 0
}

trap cleanup INT TERM EXIT

sudo sh -c "clear > $TTY"

while true; do
  service=${services[$RANDOM % ${#services[@]}]}
  action=${actions[$RANDOM % ${#actions[@]}]}
  status=${statuses[$RANDOM % ${#statuses[@]}]}

  seconds=$((RANDOM % 999))
  millis=$(printf "%06d" $((RANDOM % 1000000)))
  pid=$((100 + RANDOM % 60000))
  dev=$((RANDOM % 9))
  addr=$(printf "0x%08x" $RANDOM$RANDOM)

  case "$service" in
    kernel|vc4-drm|mmc0|usbcore)
      line="[  ${seconds}.${millis}] $service: $action dev=$dev addr=$addr irq=$((RANDOM % 256))"
      ;;
    systemd)
      unit="${services[$RANDOM % ${#services[@]}]}.service"
      line="$status $action $unit"
      ;;
    NetworkManager|wpa_supplicant)
      line="$status $service[$pid]: wlan0 state=$((RANDOM % 5)) signal=-$((30 + RANDOM % 60))dBm tx=$((RANDOM % 150))Mbps"
      ;;
    *)
      line="$status $service[$pid]: $action id=$(cat /proc/sys/kernel/random/uuid) cpu=$((RANDOM % 100))% mem=$((RANDOM % 512))MB"
      ;;
  esac

  echo "$line" | colors | sudo tee "$TTY" > /dev/null

# Variable speed: mostly fast/very fast, with occasional short pauses
r=$((RANDOM % 100))

if (( r < 70 )); then
  # very fast: 1–8 ms
  sleep "$(awk "BEGIN {printf \"%.3f\", (1 + ($RANDOM % 8)) / 1000}")"
elif (( r < 95 )); then
  # fast: 10–40 ms
  sleep "$(awk "BEGIN {printf \"%.3f\", (10 + ($RANDOM % 31)) / 1000}")"
else
  # occasional pause: 120–700 ms
  sleep "$(awk "BEGIN {printf \"%.3f\", (120 + ($RANDOM % 581)) / 1000}")"
fi

#  sleep "$DELAY"
done
