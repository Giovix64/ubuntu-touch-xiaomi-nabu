#!/bin/bash
# Double-click this file on macOS to install Ubuntu Touch on the Xiaomi Pad 5.
cd "$(dirname "$0")" || exit 1
./install.sh "$@"
echo
read -r -p "Press Enter to close this window. " _
