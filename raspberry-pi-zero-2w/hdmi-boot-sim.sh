#!/usr/bin/env bash

TTY="/dev/tty1"

sudo sh -c "clear > $TTY"

boot_lines=(
"[    0.000000] Booting Linux on physical CPU 0x0"
"[    0.041223] Linux version 6.8.0-raspi"
"[    0.184901] Machine model: Raspberry Pi Zero W"
"[    0.430812] random: crng init done"
"[    1.102331] vc4-drm soc:gpu: bound 20902000.hdmi"
"[    1.842102] mmc0: new high speed SDHC card"
"[    2.216771] EXT4-fs (mmcblk0p2): mounted filesystem"
"[  OK  ] Started Journal Service."
"[  OK  ] Reached target Local File Systems."
"[  OK  ] Started Network Manager."
"[  OK  ] Started OpenSSH server daemon."
"[  OK  ] Reached target Multi-User System."
)

while true; do
  for line in "${boot_lines[@]}"; do
    if [[ "$line" == *"[  OK  ]"* ]]; then
      echo -e "\e[32m$line\e[0m" | sudo tee "$TTY" > /dev/null
    else
      echo -e "$line" | sudo tee "$TTY" > /dev/null
    fi
    sleep 0.15
  done

  echo "" | sudo tee "$TTY" > /dev/null
  sleep 1
done
