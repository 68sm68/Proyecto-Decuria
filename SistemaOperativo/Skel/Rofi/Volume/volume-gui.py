#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess
import re
import os

CSS = b"""
* { font-family: "Montserrat", "Sans"; font-size: 13px; }
window {
    background-color: #1e1e1e;
    border-radius: 14px;
    border: 1px solid #2a2a2a;
}
.main-box { padding: 12px 8px 16px 8px; background-color: #1e1e1e; }
.section-label {
    color: #555555; font-size: 10px; font-weight: bold;
    letter-spacing: 2px; padding: 10px 14px 4px 14px;
}
.card {
    background-color: #2a2a2a; border-radius: 10px;
    margin: 2px 8px; padding: 10px 14px; border: 1px solid #333333;
}
.card-active {
    background-color: #2a2a2a; border-radius: 10px;
    margin: 2px 8px; padding: 10px 14px; border: 1px solid #cc2222;
}
.device-name     { color: #ffffff; font-weight: bold; font-size: 13px; }
.device-name-dim { color: #999999; font-size: 13px; }
.app-name        { color: #dddddd; font-size: 13px; }
.vol-pct         { color: #888888; font-size: 12px; min-width: 44px; }
.mute-btn {
    background-color: transparent; border: none; border-radius: 6px;
    padding: 2px 6px; color: #888888; font-size: 14px;
    min-width: 30px; min-height: 24px;
}
.mute-btn:hover  { background-color: #3a3a3a; color: #ffffff; }
.mute-btn-on {
    background-color: transparent; border: none; border-radius: 6px;
    padding: 2px 6px; color: #cc2222; font-size: 14px;
    min-width: 30px; min-height: 24px;
}
.radio           { padding: 0; margin: 0; color: #cc2222; }
.close-btn {
    background-color: transparent; border: none; border-radius: 50%;
    color: #555555; font-size: 16px; min-width: 28px; min-height: 28px;
    padding: 0; margin: 4px 8px 0 0;
}
.close-btn:hover { background-color: #cc2222; color: #ffffff; }
.titlebar {
    background-color: #1a1a1a; border-radius: 14px 14px 0 0;
    padding: 6px 8px 6px 14px; border-bottom: 1px solid #2a2a2a;
}
.title-label { color: #888888; font-size: 12px; font-weight: bold; letter-spacing: 1px; }
separator    { background-color: #2a2a2a; min-height: 1px; margin: 6px 10px; }
scale trough { background-color: #3a3a3a; border-radius: 4px; min-height: 4px; }
scale highlight { background-color: #cc2222; border-radius: 4px; min-height: 4px; }
scale slider {
    background-color: #ffffff; border-radius: 50%;
    min-width: 14px; min-height: 14px; margin: -5px 0;
    box-shadow: none; border: none;
}
scale slider:hover { background-color: #cc2222; }
"""

# pactl con LC_ALL=C para forzar inglés
def run(cmd):
    try:
        env = dict(os.environ)
        env['LC_ALL'] = 'C'
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL, env=env
        ).decode().strip()
    except Exception:
        return ""

def parse_blocks(output, keyword):
    blocks = []
    current = {}
    for line in output.splitlines():
        m = re.match(rf"^{keyword} #(\d+)", line)
        if m:
            if current:
                blocks.append(current)
            current = {"index": m.group(1)}
        elif current:
            s = line.strip()
            if s.startswith("Name:") and "name" not in current:
                current["name"] = s.split("Name:")[1].strip()
            elif s.startswith("Description:") and "desc" not in current:
                current["desc"] = s.split("Description:")[1].strip()
            elif s.startswith("Mute:") and "mute" not in current:
                current["mute"] = "yes" in s
            elif "front-left" in s and "vol" not in current:
                m2 = re.search(r"(\d+)%", s)
                if m2:
                    current["vol"] = int(m2.group(1))
            elif s.startswith("application.name") and "app" not in current:
                m2 = re.search(r'"(.+)"', s)
                if m2:
                    current["app"] = m2.group(1)
    if current:
        blocks.append(current)
    return blocks

def get_sinks():
    return parse_blocks(run("pactl list sinks"), "Sink")

def get_sources():
    raw = parse_blocks(run("pactl list sources"), "Source")
    return [s for s in raw if "monitor" not in s.get("name", "").lower()]

def get_sink_inputs():
    return parse_blocks(run("pactl list sink-inputs"), "Sink Input")

def get_default_sink():   return run("pactl get-default-sink")
def get_default_source(): return run("pactl get-default-source")

def set_vol_sink(idx, v):     run(f"pactl set-sink-volume {idx} {v}%")
def set_vol_source(idx, v):   run(f"pactl set-source-volume {idx} {v}%")
def set_vol_input(idx, v):    run(f"pactl set-sink-input-volume {idx} {v}%")
def toggle_mute_sink(idx):    run(f"pactl set-sink-mute {idx} toggle")
def toggle_mute_source(idx):  run(f"pactl set-source-mute {idx} toggle")
def toggle_mute_input(idx):   run(f"pactl set-sink-input-mute {idx} toggle")
def set_default_sink(name):   run(f"pactl set-default-sink {name}")
def set_default_source(name): run(f"pactl set-default-source {name}")

# Widgets

def make_device_row(data, is_sink, is_active, radio_group, refresh_cb):
    desc  = data.get("desc", data.get("name", "Unknown"))[:36]
    vol   = data.get("vol", 0)
    muted = data.get("mute", False)
    idx   = data.get("index", "")

    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    card.get_style_context().add_class("card-active" if is_active else "card")

    radio = Gtk.RadioButton()
    if radio_group[0] is not None:
        radio.join_group(radio_group[0])
    else:
        radio_group[0] = radio
    radio.set_active(is_active)
    radio.get_style_context().add_class("radio")

    def on_radio(btn):
        if btn.get_active():
            if is_sink:
                set_default_sink(data.get("name", ""))
            else:
                set_default_source(data.get("name", ""))
            GLib.timeout_add(200, refresh_cb)

    radio.connect("toggled", on_radio)

    icon_name = "audio-speakers" if is_sink else "audio-input-microphone"
    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.SMALL_TOOLBAR)

    name_lbl = Gtk.Label(label=desc)
    name_lbl.set_xalign(0)
    name_lbl.set_hexpand(True)
    name_lbl.get_style_context().add_class(
        "device-name" if is_active else "device-name-dim"
    )

    vol_lbl = Gtk.Label(label=f"{vol}%")
    vol_lbl.set_xalign(1)
    vol_lbl.get_style_context().add_class("vol-pct")

    mute_btn = Gtk.Button(label="🔇" if muted else "🔊")
    mute_btn.get_style_context().add_class("mute-btn-on" if muted else "mute-btn")

    def on_mute(b):
        if is_sink:
            toggle_mute_sink(idx)
        else:
            toggle_mute_source(idx)
        GLib.timeout_add(200, refresh_cb)

    mute_btn.connect("clicked", on_mute)

    adj = Gtk.Adjustment(value=vol, lower=0, upper=150,
                         step_increment=1, page_increment=5)
    scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
    scale.set_draw_value(False)
    scale.set_hexpand(True)
    scale.set_size_request(160, -1)

    def on_scale(s, scroll, value):
        v = max(0, min(150, int(value)))
        if is_sink:
            set_vol_sink(idx, v)
        else:
            set_vol_source(idx, v)
        vol_lbl.set_text(f"{v}%")
        return False

    scale.connect("change-value", on_scale)

    card.pack_start(radio,    False, False, 0)
    card.pack_start(icon,     False, False, 2)
    card.pack_start(name_lbl, True,  True,  0)
    card.pack_start(mute_btn, False, False, 0)
    card.pack_start(scale,    True,  True,  0)
    card.pack_start(vol_lbl,  False, False, 4)
    return card

def make_app_row(data):
    name  = data.get("app", "Unknown")[:30]
    vol   = data.get("vol", 100)
    muted = data.get("mute", False)
    idx   = data.get("index", "")

    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    card.get_style_context().add_class("card")

    icon = Gtk.Image.new_from_icon_name(
        "applications-multimedia", Gtk.IconSize.SMALL_TOOLBAR
    )
    name_lbl = Gtk.Label(label=name)
    name_lbl.set_xalign(0)
    name_lbl.set_hexpand(True)
    name_lbl.get_style_context().add_class("app-name")

    vol_lbl = Gtk.Label(label=f"{vol}%")
    vol_lbl.set_xalign(1)
    vol_lbl.get_style_context().add_class("vol-pct")

    mute_btn = Gtk.Button(label="🔇" if muted else "🔊")
    mute_btn.get_style_context().add_class("mute-btn-on" if muted else "mute-btn")
    mute_btn.connect("clicked", lambda b: toggle_mute_input(idx))

    adj = Gtk.Adjustment(value=vol, lower=0, upper=150,
                         step_increment=1, page_increment=5)
    scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
    scale.set_draw_value(False)
    scale.set_hexpand(True)
    scale.set_size_request(160, -1)

    def on_scale(s, scroll, value):
        v = max(0, min(150, int(value)))
        set_vol_input(idx, v)
        vol_lbl.set_text(f"{v}%")
        return False

    scale.connect("change-value", on_scale)

    card.pack_start(icon,     False, False, 2)
    card.pack_start(name_lbl, True,  True,  0)
    card.pack_start(mute_btn, False, False, 0)
    card.pack_start(scale,    True,  True,  0)
    card.pack_start(vol_lbl,  False, False, 4)
    return card

def build_content(refresh_cb):
    sinks          = get_sinks()
    sources        = get_sources()
    apps           = get_sink_inputs()
    default_sink   = get_default_sink()
    default_source = get_default_source()

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    box.get_style_context().add_class("main-box")

    if sinks:
        lbl = Gtk.Label(label="OUTPUT DEVICES")
        lbl.set_xalign(0)
        lbl.get_style_context().add_class("section-label")
        box.pack_start(lbl, False, False, 0)
        rg = [None]
        for s in sinks:
            active = s.get("name", "") == default_sink
            box.pack_start(
                make_device_row(s, True, active, rg, refresh_cb),
                False, False, 0
            )

    if sources:
        box.pack_start(Gtk.Separator(), False, False, 0)
        lbl = Gtk.Label(label="INPUT DEVICES")
        lbl.set_xalign(0)
        lbl.get_style_context().add_class("section-label")
        box.pack_start(lbl, False, False, 0)
        rg = [None]
        for s in sources:
            active = s.get("name", "") == default_source
            box.pack_start(
                make_device_row(s, False, active, rg, refresh_cb),
                False, False, 0
            )

    if apps:
        box.pack_start(Gtk.Separator(), False, False, 0)
        lbl = Gtk.Label(label="APPS")
        lbl.set_xalign(0)
        lbl.get_style_context().add_class("section-label")
        box.pack_start(lbl, False, False, 0)
        for a in apps:
            box.pack_start(make_app_row(a), False, False, 0)

    box.pack_start(Gtk.Box(), False, False, 4)
    return box

# Ventana principal

class VolumeWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Audio")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(580, -1)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_keep_above(True)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self.connect("button-press-event", self._on_drag)
        self.connect("key-press-event",    self._on_key)

        self._outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        titlebar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        titlebar.get_style_context().add_class("titlebar")
        title_lbl = Gtk.Label(label="AUDIO")
        title_lbl.set_xalign(0)
        title_lbl.set_hexpand(True)
        title_lbl.get_style_context().add_class("title-label")
        close_btn = Gtk.Button(label="✕")
        close_btn.get_style_context().add_class("close-btn")
        close_btn.connect("clicked", lambda b: Gtk.main_quit())
        titlebar.pack_start(title_lbl, True,  True,  0)
        titlebar.pack_start(close_btn, False, False, 0)

        self._scroll = Gtk.ScrolledWindow()
        self._scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self._scroll.set_max_content_height(600)
        self._scroll.set_propagate_natural_height(True)

        self._outer.pack_start(titlebar,     False, False, 0)
        self._outer.pack_start(self._scroll, True,  True,  0)
        self.add(self._outer)

        self._load_content()

    def _load_content(self):
        old = self._scroll.get_child()
        if old:
            self._scroll.remove(old)
        content = build_content(self.refresh)
        self._scroll.add(content)
        self.show_all()

    def refresh(self):
        self._load_content()
        return False

    def _on_drag(self, widget, event):
        if event.button == 1:
            self.begin_move_drag(
                event.button, int(event.x_root), int(event.y_root), event.time
            )

    def _on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

if __name__ == "__main__":
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    win = VolumeWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
