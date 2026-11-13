#!/usr/bin/python3
# Tasto virtuale (uinput): uikey.py power|volup|voldown
import sys, time
from evdev import UInput, ecodes as e
k = {"power": e.KEY_POWER, "volup": e.KEY_VOLUMEUP, "voldown": e.KEY_VOLUMEDOWN}[sys.argv[1]]
ui = UInput({e.EV_KEY: [e.KEY_POWER, e.KEY_VOLUMEUP, e.KEY_VOLUMEDOWN]}, name="claude-virtual-keys")
time.sleep(2.0)
ui.write(e.EV_KEY, k, 1); ui.syn(); time.sleep(0.12); ui.write(e.EV_KEY, k, 0); ui.syn()
time.sleep(0.5); ui.close(); print("premuto", sys.argv[1])
