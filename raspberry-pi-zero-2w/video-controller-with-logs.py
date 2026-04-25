#!/usr/bin/env python3
import json
import os
import random
import signal
import socket
import subprocess
import sys
import termios
import threading
import time
import tty

SOCKET_PATH = "/tmp/mpvsocket"
DISPLAY = ":0"

mpv = None
running = True
log_lines = []


services = [
    "kernel", "systemd", "udevd", "NetworkManager", "wpa_supplicant",
    "vc4-drm", "mmc0", "usbcore", "ssh", "cron",
    "espnow-bridge", "uart-listener", "video-daemon", "gpu-render",
    "framebuffer", "thermal-monitor", "hdmi-audio", "scheduler"
]

actions = [
    "Started service", "Reached target", "Mounted filesystem",
    "Initialized device", "Loaded kernel module", "Detected interface",
    "Created socket", "Started worker", "Queued job",
    "Processed frame", "Received packet", "Synced buffer",
    "Allocated DMA buffer", "Bound HDMI pipeline",
    "Decoded frame", "Committed buffer", "Updated overlay",
    "Received ESP-NOW packet", "UART message parsed"
]

statuses = [
    "[  OK  ]", "[  OK  ]", "[  OK  ]", "[ INFO ]",
    "[ WARN ]", "[DEBUG ]", "[FAILED]"
]


def cleanup():
    global mpv, running
    running = False

    if mpv and mpv.poll() is None:
        mpv.terminate()
        try:
            mpv.wait(timeout=2)
        except subprocess.TimeoutExpired:
            mpv.kill()

    if os.path.exists(SOCKET_PATH):
        try:
            os.remove(SOCKET_PATH)
        except OSError:
            pass


def start_mpv():
    global mpv

    cleanup_socket_only()

    env = os.environ.copy()
    env["DISPLAY"] = DISPLAY

    mpv = subprocess.Popen(
        [
            "mpv",
            "--fs",
            "--idle=yes",
            "--force-window=yes",
            "--loop-file=inf",
            "--no-terminal",
            "--osd-font-size=22",
            "--osd-color=#FFFFFFFF",
            "--osd-border-color=#AA000000",
            "--osd-border-size=2",
            "--osd-align-x=left",
            "--osd-align-y=top",
            f"--input-ipc-server={SOCKET_PATH}",
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )

    for _ in range(80):
        if os.path.exists(SOCKET_PATH):
            return
        if mpv.poll() is not None:
            break
        time.sleep(0.1)

    print("ERROR: mpv IPC socket was not created.")
    print(f"Try manually: DISPLAY={DISPLAY} mpv --fs --idle=yes --force-window=yes --input-ipc-server={SOCKET_PATH}")
    cleanup()
    sys.exit(1)


def cleanup_socket_only():
    if os.path.exists(SOCKET_PATH):
        try:
            os.remove(SOCKET_PATH)
        except OSError:
            pass


def mpv_command(command):
    if not os.path.exists(SOCKET_PATH):
        return

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.connect(SOCKET_PATH)
            s.sendall((json.dumps({"command": command}) + "\n").encode("utf-8"))
    except Exception:
        pass


def play(filename):
    if not os.path.exists(filename):
        print(f"File not found: {filename}")
        return

    mpv_command(["loadfile", filename, "replace"])
    mpv_command(["set_property", "loop-file", "inf"])


def stop():
    mpv_command(["stop"])


def pause_resume():
    mpv_command(["cycle", "pause"])


def fake_boot_line():
    service = random.choice(services)
    action = random.choice(actions)
    status = random.choice(statuses)

    seconds = random.randint(0, 999)
    millis = random.randint(0, 999999)
    pid = random.randint(100, 60000)
    irq = random.randint(0, 255)
    cpu = random.randint(0, 100)
    mem = random.randint(0, 512)
    signal_strength = random.randint(30, 90)

    if service in ["kernel", "vc4-drm", "mmc0", "usbcore"]:
        return f"[ {seconds:4d}.{millis:06d}] {service}: {action} irq={irq} addr=0x{random.randint(0, 0xffffffff):08x}"

    if service == "systemd":
        unit = random.choice(services) + ".service"
        return f"{status} {action} {unit}"

    if service in ["NetworkManager", "wpa_supplicant"]:
        return f"{status} {service}[{pid}]: wlan0 signal=-{signal_strength}dBm tx={random.randint(1,150)}Mbps"

    return f"{status} {service}[{pid}]: {action} cpu={cpu}% mem={mem}MB id={random.randint(100000,999999)}"


def overlay_loop():
    global log_lines

    while running:
        log_lines.append(fake_boot_line())
        log_lines = log_lines[-18:]

        overlay_text = "\n".join(log_lines)

        mpv_command([
            "show-text",
            overlay_text,
            1000
        ])

        r = random.randint(0, 100)

        if r < 70:
            time.sleep(random.uniform(0.001, 0.008))
        elif r < 95:
            time.sleep(random.uniform(0.010, 0.040))
        else:
            time.sleep(random.uniform(0.120, 0.700))


def get_key():
    ch = sys.stdin.read(1)

    if ch == "\x1b":
        return "esc"
    if ch == " ":
        return "space"

    return ch


def handle_signal(signum, frame):
    cleanup()
    sys.exit(0)


def main():
    global running

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    start_mpv()

    thread = threading.Thread(target=overlay_loop, daemon=True)
    thread.start()

    old_settings = termios.tcgetattr(sys.stdin)

    try:
        tty.setcbreak(sys.stdin.fileno())

        print("smooth-video-controller with boot-log overlay")
        print("1 = play test1.mp4")
        print("2 = play test2.mp4")
        print("3 = play test3.mp4")
        print("4 = play test4.mp4")
        print("5 = play test5.mp4")
        print("6 = play test6.mp4")
        print("7 = play test7.mp4")
        print("8 = play test8.mp4")
        print("9 = play test9.mp4")
        print("0 = stop")
        print("space = pause/resume")
        print("q or esc = quit")

        while True:
            key = get_key()

            if key in [str(i) for i in range(1, 10)]:
                play(f"test{key}.mp4")

            elif key == "0":
                stop()

            elif key == "space":
                pause_resume()

            elif key in ("q", "esc"):
                break

    finally:
        running = False
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        cleanup()


if __name__ == "__main__":
    main()
