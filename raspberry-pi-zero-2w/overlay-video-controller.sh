#!/usr/bin/env bash
set -e

DISPLAY_NUM=":0"
SOCKET="/tmp/mpvsocket"
export DISPLAY="$DISPLAY_NUM"

XORG_STARTED=0

cleanup() {
  pkill -P $$ 2>/dev/null || true
  pkill -f "xterm.*boot-rain-overlay" 2>/dev/null || true
  pkill -f "mpv.*$SOCKET" 2>/dev/null || true
  pkill -f "openbox" 2>/dev/null || true
  pkill -f "xcompmgr" 2>/dev/null || true
  rm -f "$SOCKET"

  if [[ "$XORG_STARTED" == "1" ]]; then
    sudo pkill -f "Xorg $DISPLAY_NUM" 2>/dev/null || true
  fi

  exit 0
}

trap cleanup INT TERM EXIT

boot_rain() {
  services=("kernel" "systemd" "udevd" "NetworkManager" "wpa_supplicant" "vc4-drm" "mmc0" "usbcore" "ssh" "cron" "espnow-bridge" "uart-listener" "video-daemon" "gpu-render" "framebuffer" "thermal-monitor" "hdmi-audio")
  actions=("Started service" "Reached target" "Mounted filesystem" "Initialized device" "Loaded kernel module" "Detected interface" "Created socket" "Started worker" "Queued job" "Processed frame" "Received packet" "Synced buffer" "Allocated DMA buffer" "Bound HDMI pipeline" "Decoded frame" "Committed buffer")
  statuses=("[  OK  ]" "[  OK  ]" "[  OK  ]" "[ INFO ]" "[ WARN ]" "[DEBUG ]" "[FAILED]")

  clear

  while true; do
    service=${services[$RANDOM % ${#services[@]}]}
    action=${actions[$RANDOM % ${#actions[@]}]}
    status=${statuses[$RANDOM % ${#statuses[@]}]}
    pid=$((100 + RANDOM % 60000))
    cpu=$((RANDOM % 100))
    mem=$((RANDOM % 512))

    case "$status" in
      "[  OK  ]") color="\033[32m" ;;
      "[ INFO ]") color="\033[36m" ;;
      "[ WARN ]") color="\033[33m" ;;
      "[DEBUG ]") color="\033[35m" ;;
      "[FAILED]") color="\033[31m" ;;
      *) color="\033[37m" ;;
    esac

    printf "${color}%s\033[0m %s[%s]: %s cpu=%s%% mem=%sMB id=%s\n" \
      "$status" "$service" "$pid" "$action" "$cpu" "$mem" "$((100000 + RANDOM % 900000))"

    r=$((RANDOM % 100))
    if (( r < 70 )); then
      sleep "$(awk "BEGIN {printf \"%.3f\", (1 + ($RANDOM % 8)) / 1000}")"
    elif (( r < 95 )); then
      sleep "$(awk "BEGIN {printf \"%.3f\", (10 + ($RANDOM % 31)) / 1000}")"
    else
      sleep "$(awk "BEGIN {printf \"%.3f\", (120 + ($RANDOM % 581)) / 1000}")"
    fi
  done
}

mpv_cmd() {
  printf '%s\n' "$1" | socat - "$SOCKET" >/dev/null 2>&1 || true
}

play_video() {
  file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Missing file: $file"
    return
  fi

  mpv_cmd "{ \"command\": [\"loadfile\", \"$file\", \"replace\"] }"
  mpv_cmd "{ \"command\": [\"set_property\", \"loop-file\", \"inf\"] }"
}

start_x_if_needed() {
  if xdpyinfo -display "$DISPLAY_NUM" >/dev/null 2>&1; then
    return
  fi

  echo "Starting X on HDMI display $DISPLAY_NUM..."
  sudo chvt 1 || true
  sudo Xorg "$DISPLAY_NUM" vt1 -ac -noreset -nolisten tcp -s 0 -dpms &
  XORG_STARTED=1
  sleep 4

  if ! xdpyinfo -display "$DISPLAY_NUM" >/dev/null 2>&1; then
    echo "ERROR: X did not start."
    exit 1
  fi
}

command -v socat >/dev/null || sudo apt install -y socat

start_x_if_needed

xset s off -dpms s noblank || true

openbox &
sleep 1

xcompmgr -n &
sleep 0.5

rm -f "$SOCKET"

mpv \
  --idle=yes \
  --force-window=yes \
  --no-border \
  --geometry=100%x100%+0+0 \
  --loop-file=inf \
  --no-terminal \
  --input-ipc-server="$SOCKET" &

sleep 1

xterm \
  -name boot-rain-overlay \
  -title boot-rain-overlay \
  -fa Monospace \
  -fs 13 \
  -fg green \
  -bg black \
  -bd black \
  -cr green \
  +sb \
  -geometry 160x48+0+0 \
  -e bash -c "$(declare -f boot_rain); boot_rain" &

sleep 1

wmctrl -r boot-rain-overlay -b add,above
wmctrl -r boot-rain-overlay -b add,sticky
xprop -name boot-rain-overlay \
  -f _NET_WM_WINDOW_OPACITY 32c \
  -set _NET_WM_WINDOW_OPACITY 2147483648 2>/dev/null || true

play_video "test1.mp4"

echo "1-9 = play test1.mp4 ... test9.mp4"
echo "0 = stop"
echo "space = pause/resume"
echo "q = quit"

while true; do
  IFS= read -rsn1 key

  case "$key" in
    [1-9])
      play_video "test${key}.mp4"
      ;;
    0)
      mpv_cmd '{ "command": ["stop"] }'
      ;;
    " ")
      mpv_cmd '{ "command": ["cycle", "pause"] }'
      ;;
    q)
      cleanup
      ;;
    $'\e')
      cleanup
      ;;
  esac
done

