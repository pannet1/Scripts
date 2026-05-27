from libqtile import hook
import subprocess
import os

from key import keys
from layout import layouts, floating_layout
from mouse_action import mouse
from screen import colors, screens


@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser("~/.config/qtile/autostart.sh")
    subprocess.call([home])


@hook.subscribe.startup
def start_always():
    subprocess.Popen(["xsetroot", "-cursor_name", "left_ptr"])


"""
@qtile_extras.hook.subscribe.up_power_connected
def plugged_in():
    qtile.spawn("ffplay power_on.wav")


@qtile_extras.hook.subscribe.up_power_disconnected
def unplugged():
    qtile.spawn("ffplay power_off.wav")


@qtile_extras.hook.subscribe.up_battery_full
def battery_full(battery_name):
    send_notification(battery_name, "Battery is fully charged.")


@qtile_extras.hook.subscribe.up_battery_low
def battery_low(battery_name):
    send_notification(battery_name, "Battery is running low.")


@qtile_extras.hook.subscribe.up_battery_critical
def battery_critical(battery_name):
    send_notification(battery_name, "Battery is critically low. Plug in power supply.")

"""
