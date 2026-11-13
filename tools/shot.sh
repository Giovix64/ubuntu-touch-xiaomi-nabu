#!/bin/sh
# Cattura lo schermo (raw RGBA 1600x2560) in /tmp/s.raw
rm -f /tmp/s.raw
GLIBC_TUNABLES=glibc.rtld.optional_static_tls=4096 LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libtls-padding.so timeout 20 mirscreencast -m /run/mir_socket -n 1 -f /tmp/s.raw >/dev/null 2>&1
chmod 644 /tmp/s.raw
