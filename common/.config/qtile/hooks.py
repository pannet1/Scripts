"""Lifecycle hooks. Importing this module REGISTERS them with Qtile —
config.py does `import hooks` purely for that side effect.
(Split from config.py.)
"""

import os
import subprocess

from libqtile import hook

from theme import home, wallpaper_mode, final_wallpaper


# ---------------------------------------------------------------------------
# Hooks: event-driven shell-outs.
# - startup_once: runs ONLY at first login (not on mod+ctrl+r). Launches
#   autostart.sh (tray, power manager, audio unmute...) and paints the
#   wallpaper — both async via Popen. Restarts skip this entirely: no flicker,
#   because the X root pixmap survives a Qtile restart.
# - startup: runs on EVERY restart too — only resets the X cursor. Cheap.
# ---------------------------------------------------------------------------
@hook.subscribe.startup_once
def start_once():
    subprocess.Popen([home + "/.config/qtile/autostart.sh"])
    subprocess.Popen(
        ["xwallpaper", "--" + wallpaper_mode, os.path.expanduser(final_wallpaper)]
    )


@hook.subscribe.startup
def runner():
    subprocess.Popen(["xsetroot", "-cursor_name", "left_ptr"])
