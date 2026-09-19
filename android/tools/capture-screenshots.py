#!/usr/bin/env python3
"""Captures Google Play screenshots (English + zh-Hans UI) on a booted emulator
and saves them under assets/screenshots/android/<profile>/{en,zh-Hans}/.

    android/tools/capture-screenshots.py [profile]   phone (default) | tablet-10 | tablet-7

Starts the profile's emulator headless if no device is connected. Sizes respect
Google Play's rules (320–3840 px per side, max 2:1 aspect): the phone AVD is
forced to 1080x2160 via `wm size`, the tablet is natively 1600x2560. SystemUI
demo mode provides the clean marketing status bar. No app or test code
changes — the app is driven through `uiautomator dump` + `input tap`.
"""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

SDK = os.environ.get("ANDROID_HOME") or os.path.expanduser("~/Library/Android/sdk")
ADB = os.path.join(SDK, "platform-tools", "adb")
EMULATOR = os.path.join(SDK, "emulator", "emulator")
PKG = "com.yilab.civics"

# Device profiles: phone shots are required by Google Play; the 7" and 10"
# tablet sets are optional but unlock the "Designed for tablets" treatment.
# All stay within Play's 320–3840 px, max 2:1 aspect rules (phone is forced
# to exactly 2:1 via wm size; the tablets are natively 1.6:1).
PROFILES = {
    "phone": {"avd": "Pixel_10", "size": (1080, 2160), "out": "phone", "delay": 1.8},
    "tablet-10": {"avd": "HP_Tablet", "size": (1600, 2560), "out": "tablet-10", "delay": 1.2},
    "tablet-7": {"avd": "Nexus_7", "size": (1200, 1920), "out": "tablet-7", "delay": 1.2},
}
_profile = PROFILES[sys.argv[1] if len(sys.argv) > 1 else "phone"]
AVD = _profile["avd"]
W, H = _profile["size"]
HIGHLIGHT_DELAY = _profile["delay"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                   "assets", "screenshots", "android", _profile["out"])
OUT = os.path.abspath(OUT)
APK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                   "..", "app", "build", "outputs", "apk", "debug", "app-debug.apk"))

LABELS = {
    "en": {
        "tabs": ["Listen", "Flashcards", "Questions", "Test", "Settings"],
        "start": "Start listening", "caption": "Speaking the question",
        "stop": "Stop", "reveal": "Tap to reveal", "mark": "Mark as known",
        "testStart": "Start practice test", "hearAnswer": "Hear the answer",
        "gotIt": "✓ I got it", "q2": "Question 2 of 20",
        "langChip": None,  # already English
    },
    "zh-Hans": {
        "tabs": ["听题", "抽认卡", "题库", "测试", "设置"],
        "start": "开始听题", "caption": "正在读题",
        "stop": "停止", "reveal": "点击显示答案", "mark": "标记为已掌握",
        "testStart": "开始模拟测试", "hearAnswer": "听答案",
        "gotIt": "✓ 答对了", "q2": "第 2 题",
        "langChip": "简体中文",
    },
}


def sh(args, check=True, capture=False):
    r = subprocess.run(args, capture_output=capture, text=False)
    if check and r.returncode != 0:
        raise RuntimeError(f"failed: {' '.join(map(str, args))}\n{r.stderr!r}")
    return r.stdout if capture else None


def adb(*args, capture=False):
    return sh([ADB] + list(args), capture=capture)


def ensure_device():
    r = subprocess.run([ADB, "devices"], capture_output=True, text=True)
    if "\tdevice" not in r.stdout:
        print(f"starting emulator {AVD} headless...")
        subprocess.Popen([EMULATOR, "-avd", AVD, "-no-window", "-no-snapshot-save",
                          "-no-boot-anim", "-gpu", "host"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    adb("wait-for-device")
    for _ in range(120):
        try:
            if adb("shell", "getprop", "sys.boot_completed", capture=True).strip() == b"1":
                return
        except RuntimeError:
            pass  # emulator still registering with adb ("no devices" yet)
        time.sleep(2)
    raise RuntimeError("emulator did not boot")


def setup_display():
    adb("shell", "wm", "size", f"{W}x{H}")
    # SystemUI demo mode: clean clock/battery/wifi, no notification icons.
    adb("shell", "settings", "put", "global", "sysui_demo_allowed", "1")
    adb("shell", "am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command", "enter")
    for extra in (["clock", "-e", "hhmm", "0941"],
                  ["battery", "-e", "level", "100", "-e", "plugged", "true"],
                  ["network", "-e", "wifi", "show", "-e", "level", "4"],
                  ["network", "-e", "mobile", "hide"],
                  ["notifications", "-e", "visible", "false"],
                  ["status", "-e", "alarm", "hide"]):
        adb("shell", "am", "broadcast", "-a", "com.android.systemui.demo",
            "-e", "command", extra[0], *extra[1:])
    adb("shell", "settings", "put", "global", "window_animation_scale", "0")
    adb("shell", "settings", "put", "global", "transition_animation_scale", "0")
    adb("shell", "settings", "put", "global", "animator_duration_scale", "0")
    adb("shell", "pm", "grant", PKG, "android.permission.POST_NOTIFICATIONS")


def dump_nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/__cap.xml")
    xml = adb("exec-out", "cat", "/sdcard/__cap.xml", capture=True)
    root = ET.fromstring(xml)
    return root.iter("node")


def find(text, desc=False, prefix=False, contains=False, clickable=False):
    for node in dump_nodes():
        attr = node.get("content-desc") if desc else node.get("text")
        if not attr:
            continue
        if clickable and node.get("clickable") != "true":
            continue
        if attr == text or (prefix and attr.startswith(text)) or (contains and text in attr):
            b = re.findall(r"\d+", node.get("bounds"))
            x = (int(b[0]) + int(b[2])) // 2
            y = (int(b[1]) + int(b[3])) // 2
            return x, y
    return None


def wait_for(text, desc=False, prefix=False, contains=False, clickable=False, timeout=30):
    for _ in range(int(timeout * 2)):
        pos = find(text, desc, prefix, contains, clickable)
        if pos:
            return pos
        time.sleep(0.5)
    raise RuntimeError(f"not found: {text!r}")


def tap(text, desc=False, prefix=False, contains=False, clickable=False, timeout=30):
    x, y = wait_for(text, desc, prefix, contains, clickable, timeout)
    adb("shell", "input", "tap", str(x), str(y))


def shot(locale, name):
    path = os.path.join(OUT, locale, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    png = adb("exec-out", "screencap", "-p", capture=True)
    with open(path, "wb") as f:
        f.write(png)
    print("saved", path, len(png), "bytes")


def launch_app():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")


def capture(locale, L):
    # Pre-mark three questions known so every screenshot shows the known state
    # (launch args can't seed DataStore like iOS UserDefaults).
    tap(L["tabs"][2])
    wait_for("Q1", prefix=True)
    for _ in range(3):
        tap(L["mark"], desc=True)
        time.sleep(0.4)
    tap(L["tabs"][0])
    wait_for(L["start"])

    # 1 — Listen, mid-question karaoke highlight.
    tap(L["start"])
    wait_for(L["caption"], prefix=True)
    time.sleep(HIGHLIGHT_DELAY)
    shot(locale, "01-listen")
    tap(L["stop"], desc=True)          # engine is shared; Test needs it idle
    time.sleep(0.7)

    # 2 — Flashcards, flipped to the answer.
    tap(L["tabs"][1])
    tap(L["reveal"])
    time.sleep(1.0)
    shot(locale, "02-flashcards")

    # 3 — Questions, known checkmarks from the pre-mark step.
    tap(L["tabs"][2])
    wait_for("Q1", prefix=True)
    time.sleep(0.5)
    shot(locale, "03-questions")

    # 4 — Practice test: grade Q1 correct, capture Q2 mid-speech with score.
    # The grade button text includes the icon ("✓ I got it"); exact match
    # avoids the look-alike awaitingGrade caption ("答对了吗？").
    tap(L["tabs"][3])
    tap(L["testStart"])
    tap(L["hearAnswer"])
    tap(L["gotIt"])
    wait_for(L["q2"], prefix=True)
    time.sleep(HIGHLIGHT_DELAY)
    shot(locale, "04-test")

    # 5 — Settings.
    tap(L["tabs"][4])
    time.sleep(1.2)
    shot(locale, "05-settings")


def ensure_app():
    # `pm path` exits non-zero with empty output when the package is absent.
    r = subprocess.run([ADB, "shell", "pm", "path", PKG], capture_output=True)
    if r.stdout.strip():
        return
    if not os.path.exists(APK):
        raise RuntimeError(f"app not installed and no APK at {APK}\n"
                           "build it first: cd android && ./gradlew assembleDebug")
    print("installing app on fresh device...")
    adb("install", "-r", "-g", APK)


def main():
    ensure_device()
    ensure_app()
    setup_display()
    adb("shell", "pm", "clear", PKG)  # fresh settings/known state for every run
    setup_display()                   # pm clear drops the notification grant
    launch_app()
    wait_for(LABELS["en"]["start"])
    time.sleep(1.0)

    capture("en", LABELS["en"])

    # Reset app data so the zh run is symmetric: known marks and the locale
    # persist in app data; the mid-test engine state does not.
    adb("shell", "pm", "clear", PKG)
    setup_display()  # pm clear drops the notification grant
    launch_app()
    wait_for(LABELS["en"]["start"])

    # Switch to Simplified Chinese via the Settings language chip.
    tap(LABELS["en"]["tabs"][4])
    tap(LABELS["zh-Hans"]["langChip"])
    wait_for(LABELS["zh-Hans"]["tabs"][0])  # activity recreated in Chinese
    time.sleep(1.0)
    tap(LABELS["zh-Hans"]["tabs"][0])
    capture("zh-Hans", LABELS["zh-Hans"])

    adb("shell", "am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command", "exit")
    adb("shell", "wm", "size", "reset")
    print("done")


if __name__ == "__main__":
    main()
