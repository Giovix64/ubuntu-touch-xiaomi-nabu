#!/usr/bin/python3
"""Touchscreen virtuale (uinput) con le stesse caratteristiche del NVT di nabu.
uso: uitouch.py tap XR YR      (coordinate della schermata RUOTATA come la vede l'utente, 2560x1600)
     uitouch.py swipe XR1 YR1 XR2 YR2
"""
import sys, time
from evdev import UInput, AbsInfo, ecodes as e
W, H = 1600, 2560
def native(xr, yr):            # schermata ruotata 90° orario -> coordinate native del pannello
    return int(yr), int(H - 1 - xr)
cap = {e.EV_KEY: [e.BTN_TOUCH],
       e.EV_ABS: [(e.ABS_MT_SLOT, AbsInfo(0, 0, 9, 0, 0, 0)),
                  (e.ABS_MT_TOUCH_MAJOR, AbsInfo(0, 0, 255, 0, 0, 0)),
                  (e.ABS_MT_POSITION_X, AbsInfo(0, 0, W - 1, 0, 0, 0)),
                  (e.ABS_MT_POSITION_Y, AbsInfo(0, 0, H - 1, 0, 0, 0)),
                  (e.ABS_MT_TRACKING_ID, AbsInfo(0, 0, 65535, 0, 0, 0)),
                  (e.ABS_MT_PRESSURE, AbsInfo(0, 0, 1000, 0, 0, 0))]}
ui = UInput(cap, name="claude-virtual-touch", input_props=[e.INPUT_PROP_DIRECT])
time.sleep(2.0)                # tempo per Mir di vedere il nuovo dispositivo
tid = [100]
def down(x, y):
    tid[0] += 1
    for t, c, v in [(e.EV_ABS, e.ABS_MT_SLOT, 0), (e.EV_ABS, e.ABS_MT_TRACKING_ID, tid[0]),
                    (e.EV_ABS, e.ABS_MT_POSITION_X, x), (e.EV_ABS, e.ABS_MT_POSITION_Y, y),
                    (e.EV_ABS, e.ABS_MT_TOUCH_MAJOR, 8), (e.EV_ABS, e.ABS_MT_PRESSURE, 300),
                    (e.EV_KEY, e.BTN_TOUCH, 1)]:
        ui.write(t, c, v)
    ui.syn()
def move(x, y):
    ui.write(e.EV_ABS, e.ABS_MT_POSITION_X, x); ui.write(e.EV_ABS, e.ABS_MT_POSITION_Y, y); ui.syn()
def up():
    ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, -1); ui.write(e.EV_KEY, e.BTN_TOUCH, 0); ui.syn()
a = sys.argv[1:]
if a[0] == "tap":
    x, y = native(float(a[1]), float(a[2])); down(x, y); time.sleep(0.08); up()
    print("tap nativo", x, y)
elif a[0] == "swipe":
    x1, y1 = native(float(a[1]), float(a[2])); x2, y2 = native(float(a[3]), float(a[4]))
    down(x1, y1)
    for i in range(1, 21):
        move(int(x1 + (x2 - x1) * i / 20), int(y1 + (y2 - y1) * i / 20)); time.sleep(0.015)
    up(); print("swipe nativo", (x1, y1), "->", (x2, y2))
time.sleep(0.5)
ui.close()
