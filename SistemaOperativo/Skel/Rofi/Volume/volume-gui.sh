#!/usr/bin/env bash
systemctl --user start pipewire pipewire-pulse wireplumber 2>/dev/null
python3 ~/.config/rofi/volume/volume-gui.py
