#!/usr/bin/env python3
import json
import os
import signal
import socket
import subprocess
import sys
import termios
import time
import tty

SOCKET_PATH = "/tmp/mpvsocket"
DISPLAY = ":0"

mpv = None


def cleanup():
    global mpv

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

    cleanup()

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
            f"--input-ipc-server={SOCKET_PATH}",
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    for _ in range(60):
        if os.path.exists(SOCKET_PATH):
            return
        if mpv.poll() is not None:
            break
        time.sleep(0.1)

    print("ERROR: mpv IPC socket was not created.")
    print("Try testing this manually:")
    print(f"DISPLAY={DISPLAY} mpv --fs --idle=yes --force-window=yes --input-ipc-server={SOCKET_PATH}")
    cleanup()
    sys.exit(1)


def mpv_command(command):
    if not os.path.exists(SOCKET_PATH):
        print("ERROR: mpv socket disappeared.")
        return

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(SOCKET_PATH)
        s.sendall((json.dumps({"command": command}) + "\n").encode("utf-8"))


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
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    start_mpv()

    old_settings = termios.tcgetattr(sys.stdin)

    try:
        tty.setcbreak(sys.stdin.fileno())

        print("smooth-video-controller")
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

            if key == "1":
                play("test1.mp4")
            elif key == "2":
                play("test2.mp4")
            elif key == "3":
                play("test3.mp4")
            elif key == "4":
                play("test4.mp4")
            elif key == "5":
                play("test5.mp4")
            elif key == "6":
                play("test6.mp4")
            elif key == "7":
                play("test7.mp4")
            elif key == "8":
                play("test8.mp4")
            elif key == "9":
                play("test9.mp4")
            elif key == "0":
                stop()
            elif key == "space":
                pause_resume()
            elif key in ("q", "esc"):
                break

    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        cleanup()


if __name__ == "__main__":
    main()
