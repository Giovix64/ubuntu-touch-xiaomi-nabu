#!/usr/bin/env python3
"""Genera installer-any-rom.html da installer.html: stesso motore di installazione,
ma con la guida dettagliata "da quale sistema posso partire" (il VNDK v30 e' incluso
nel sistema, quindi il port non dipende piu' dalla ROM installata).
uso: make-anyrom-html.py installer.html installer-any-rom.html
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()

def swap(text, a, b, new):
    i = text.index(a); j = text.index(b, i)
    return text[:i] + new + text[j:]

s = s.replace("<title>Ubuntu Touch Installer · Xiaomi Pad 5</title>",
              "<title>Ubuntu Touch Installer (any ROM) · Xiaomi Pad 5</title>")
s = s.replace("<h1>Ubuntu Touch Installer</h1>", "<h1>Ubuntu Touch Installer — from any stock ROM</h1>")
s = s.replace("</style>", """  table.compat { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: .95rem; }
  table.compat th, table.compat td { text-align: left; vertical-align: top; padding: 8px 10px; border-top: 1px solid var(--line); }
  table.compat th { color: var(--muted); font-weight: 600; border-top: 0; }
  .tag { display: inline-block; font-weight: 700; white-space: nowrap; }
  .tag.ok { color: var(--ok); } .tag.maybe { color: var(--warn); } .tag.no { color: var(--bad); }
  h3 { font-size: 1rem; margin: 18px 0 4px; }
</style>""")

card1 = """  <section class="card active" id="c1">
    <h2><span class="num">1</span>Check your tablet first</h2>
    <p>This version carries everything Ubuntu Touch needs inside its own system, so it no longer depends
       on a specific HyperOS release. What still matters is <strong>how the installer can write the hardware
       drivers</strong> (it needs the "fastbootd" mode of the system that is on the tablet now).</p>

    <h3>What is on your tablet now?</h3>
    <table class="compat">
      <tr><th>Current system</th><th>Result</th><th>What to do</th></tr>
      <tr><td>HyperOS OS1.0.6.0.TKXEUXM (EEA)</td><td><span class="tag ok">✔ Tested base</span></td>
          <td>Install normally.</td></tr>
      <tr><td>This Ubuntu Touch port, already installed</td><td><span class="tag ok">✔ Tested</span></td>
          <td>Tick <em>Reinstall</em> in step 4 (the drivers are already there).</td></tr>
      <tr><td>Any other stock HyperOS or MIUI 13 / 14 (Global, EEA, China…)</td>
          <td><span class="tag maybe">● Should work</span></td>
          <td>Install normally. Not verified on a real tablet yet: please report the result.</td></tr>
      <tr><td>Older stock MIUI 12.5 (Android 11)</td><td><span class="tag maybe">● Uncertain</span></td>
          <td>Better: update the tablet to MIUI 14 / HyperOS first, then install.</td></tr>
      <tr><td>Custom ROM (LineageOS, crDroid, ArrowOS, …)</td><td><span class="tag no">✘ Avoid</span></td>
          <td>Their recovery often cannot write the driver partitions (the installer stops at
              "Hardware drivers"). Flash a stock HyperOS fastboot ROM first.</td></tr>
      <tr><td>Tablet repartitioned for Windows or another Linux (dual boot)</td>
          <td><span class="tag no">✘ Avoid</span></td>
          <td>The partition layout is not the original one. Restore the stock layout first.</td></tr>
      <tr><td>Xiaomi Pad 5 Pro, Pad 5 Pro 5G, Pad 6, …</td><td><span class="tag no">✘ Not supported</span></td>
          <td>Only the Xiaomi Pad 5 (code name <code>nabu</code>). The installer refuses other devices.</td></tr>
    </table>

    <h3>Always required</h3>
    <ol>
      <li><strong>Unlocked bootloader</strong> (Xiaomi's Mi Unlock tool). The installer checks it and never locks it.</li>
      <li>Battery above 50%, a good USB cable, plugged directly into the computer (no hubs).</li>
    </ol>

    <h3>Things to avoid</h3>
    <ul>
      <li>Do not unplug the cable or close this page while installing.</li>
      <li>Never run Xiaomi's <code>flash_all_lock</code> script on a modified tablet: it locks the bootloader.</li>
      <li>Do not use this to "update" and keep your data: it always erases the tablet
          (for updates use the recovery zip).</li>
    </ul>

    <h3>If something goes wrong</h3>
    <p>The tablet can always be put back in FASTBOOT mode (hold Volume Down + Power). From there you can run
       this installer again, or go back to Android with Xiaomi's stock fastboot ROM and its
       <code>flash_all</code> script. If the tablet stays on the Mi logo for more than five minutes after
       installing, the drivers did not match: flash the stock HyperOS and install again.</p>

    <div class="warnbox"><strong>Everything on the tablet will be erased</strong> — photos, apps, accounts.
      Copy what you want to keep to another device first.</div>
    <p class="status">Good to know: this project was created by its author in cooperation with an AI assistant.
      It is experimental — use it at your own risk.</p>
    <label class="check"><input type="checkbox" id="agree">
      <span>I checked the table above and I understand that all data on the tablet will be erased.</span></label>
  </section>

"""
s = swap(s, '  <section class="card active" id="c1">', '  <section class="card locked" id="c2">', card1)
open(dst, "w", encoding="utf-8").write(s)
print("scritto", dst)
