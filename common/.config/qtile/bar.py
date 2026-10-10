"""Top bar: pill widgets, WidgetBox sensors, tray, clocks + screens.
(Split from config.py.)
"""

from libqtile import bar, widget
from libqtile.config import Screen

# qtile-extras (same uv tool venv — see keys.py header for install command).
from qtile_extras.widget.mpris2widget import Mpris2 as ExtMpris2
from qtile_extras.widget.currentlayout import CurrentLayoutIcon as ExtCurrentLayoutIcon
from qtile_extras.widget.decorations import RectDecoration

from theme import colors, looks

# ---------------------------------------------------------------------------
# Widget + bar defaults. `widget_defaults` applies to EVERY widget unless the
# widget overrides it (GroupBox overrides font/size below). `extension_defaults`
# is the same dict reused for rofi-style extensions (mod+t prompt). Fonts must
# be installed (FiraCode Nerd Font via install-debian.sh); missing fonts render
# as tofu boxes — check with `fc-list | grep -i fira`.
# ---------------------------------------------------------------------------
widget_defaults = dict(
    font="FiraCode Nerd Font Mono",
    fontsize=10,
    padding=3,
)
extension_defaults = widget_defaults.copy()


# Pill helper (qtile-extras). Draws a rounded filled rectangle behind a widget.
# Widgets sharing the SAME colour with group=True merge into one continuous
# pill; a Spacer (or any undecorated widget) between runs breaks the group.
def pill(bg, radius=10):
    return [RectDecoration(colour=bg, radius=radius, filled=True, padding_y=4, group=True)]


# Gap between pills: empty bar-background spacer (no fake colours).
def gap(padding=6):
    return widget.Sep(linewidth=0, padding=padding, background=colors["bg"])

# ---------------------------------------------------------------------------
# Top bar, left to right: [GroupBox + CurrentLayout + Prompt] pill, Spacers
# centring the WindowName title, then [sensors WidgetBox] [tray] [media]
# [volume] [date] [time] pills. Same-colour widgets with group=True merge into
# one rounded pill (see `pill()`); `gap()` = plain bar-background spacing.
# ---------------------------------------------------------------------------
widgets_list: list = [
    # --- Left pill: workspaces + layout + prompt (one merged pill) ---
    # GroupBox: the workspace switcher. highlight_method="line" underlines the
    # active group with this_current_screen_border; active/inactive tint the
    # Nerd-Font labels; other_screen_border matters only with 2+ monitors.
    widget.GroupBox(
        font=looks["caret_font"],  # icon font from settings.json (FontAwesome)
        fontsize=16,
        borderwidth=3,  # underline thickness for the active group
        active=colors["active"],
        inactive=colors["inactive"],
        rounded=False,
        highlight_method="line",
        highlight_color=colors["groups_bg"],
        this_current_screen_border=colors["current_screen_tab"],
        this_screen_border=colors["color1"],
        other_screen_border=colors["bg"],
        foreground=colors["fg"],
        background=colors["groups_bg"],
        decorations=pill(colors["groups_bg"]),
    ),
    # CurrentLayoutIcon: icon of the active layout (shipped PNGs cover all
    # five of ours: bsp/max/monadtall/zoomy/floating). Replaces the old text
    # name — glanceable on mod+Tab.
    ExtCurrentLayoutIcon(
        foreground=colors["active"],
        background=colors["groups_bg"],
        decorations=pill(colors["groups_bg"]),
    ),
    # Prompt: the `mod+t` input line (`lazy.spawncmd()`). Displays "Woof: "
    # and runs whatever you type. Rarely used now that rofi (mod+r) exists.
    widget.Prompt(
        foreground=colors["active"],
        background=colors["groups_bg"],
        font="JetBrains Mono",
        prompt="Woof: ",
        decorations=pill(colors["groups_bg"]),
    ),
    # Spacer breaks the pill group and pushes everything after it right.
    widget.Spacer(),
    # --- Middle: focused window title, flat on the bar, centred by the two
    # --- Spacers. Empty string when nothing is focused.
    widget.WindowName(
        format="{name}",
        max_chars=80,
        empty_group_string="",
        foreground=colors["fg"],
        background=colors["bg"],
    ),
    widget.Spacer(),
    # --- Sensors pill (collapsible): click the chip icon to open/close the
    # --- CPU/Memory/temp/net/GPU readout. Needs psutil (in the uv venv) +
    # --- nvidia-smi for the GPU sensor. Net tracks the wifi uplink
    # --- (wlx304a2670a691 = current default route; wired enp0s25 exists too).
    widget.WidgetBox(
        widgets=[
            widget.CPU(
                format="CPU {load_percent:.0f}%",
                foreground=colors["color4fg"],
                background=colors["color4"],
                decorations=pill(colors["color4"]),
            ),
            widget.Memory(
                format="Mem {MemPercent:.0f}%",
                foreground=colors["color4fg"],
                background=colors["color4"],
                decorations=pill(colors["color4"]),
            ),
            widget.ThermalSensor(
                tag_sensor="Package id 0",
                format="Temp {temp:.0f}{unit}",
                threshold=80,
                foreground=colors["color4fg"],
                background=colors["color4"],
                decorations=pill(colors["color4"]),
            ),
            widget.Net(
                interface="wlx304a2670a691",
                format="↓{down:.1f}{down_suffix} ↑{up:.1f}{up_suffix}",
                foreground=colors["color4fg"],
                background=colors["color4"],
                decorations=pill(colors["color4"]),
            ),
            widget.NvidiaSensors(
                format="GPU {temp}°C",
                foreground=colors["color4fg"],
                background=colors["color4"],
                decorations=pill(colors["color4"]),
            ),
        ],
        text_closed="\uf2db ",
        text_open="\uf2db ",
        foreground=colors["color4fg"],
        background=colors["color4"],
        decorations=pill(colors["color4"]),
    ),
    gap(),
    # --- Tray pill: classic XEmbed systray. (StatusNotifier was tried first,
    # --- but this nm-applet build is XEmbed-only — no --indicator flag — so
    # --- the SNI tray stayed empty. Stock Systray shows the wifi icon + menu
    # --- exactly as before. One per screen only with multi-monitor.)
    widget.Systray(
        background=colors["systray"],
        padding=10,
        decorations=pill(colors["systray"]),
    ),
    gap(),
    # --- Media pill: current track, only non-empty while a player runs. ---
    ExtMpris2(
        format="{xesam:title} - {xesam:artist}",
        max_chars=40,
        foreground=colors["color2fg"],
        background=colors["color2"],
        decorations=pill(colors["color2"]),
    ),
    gap(),
    # --- Volume pill (icon + readout, same behaviour as before) ---
    # TextBox icons: raw Nerd/FontAwesome glyphs (\uf026 = speaker). If you see
    # boxes instead of icons, the icon font in `font=` isn't installed.
    widget.TextBox(
        text="\uf026",
        font="FontAwesome",
        foreground=colors["color3fg"],
        background=colors["color3"],
        fontsize=18,
        padding=0,
        decorations=pill(colors["color3"]),
    ),
    # Volume: PipeWire-aware readout; scroll or click to change (plus XF86 keys).
    widget.Volume(
        foreground=colors["color3fg"],
        background=colors["color3"],
        decorations=pill(colors["color3"]),
    ),
    gap(),
    # --- Date pill ---
    widget.TextBox(
        foreground=colors["color1fg"],
        background=colors["color1"],
        text="\uf073",  # calendar glyph
        font="FontAwesome",
        fontsize=18,
        decorations=pill(colors["color1"]),
    ),
    # Clock format codes are strftime: %D = mm/dd/yy date...
    widget.Clock(
        foreground=colors["color1fg"],
        background=colors["color1"],
        format="%D",
        decorations=pill(colors["color1"]),
    ),
    gap(),
    # --- Time pill ---
    widget.TextBox(
        foreground=colors["color5fg"],
        background=colors["color5"],
        text="\uf017",  # clock glyph
        font="FontAwesome",
        fontsize=18,
        decorations=pill(colors["color5"]),
    ),
    # ...%A = weekday name, %H:%M = 24h time.
    widget.Clock(
        foreground=colors["color5fg"], background=colors["color5"], format="%A - %H:%M",
        decorations=pill(colors["color5"]),
    ),
]

# Gap between bar and windows. 0 = panel touches window edges; try
# [4, 8, 0, 8] for floating-pill look (N E S W).
bar_margin = 0

# ---------------------------------------------------------------------------
# Screens + bars. ONE Screen = one monitor definition; `screens = [screen]`
# means a single bar (a second monitor would mirror it — keep StatusNotifier
# on exactly one bar or tray icons duplicate). Wallpaper is painted by
# xwallpaper in hooks.py, so Qtile itself never paints it.
# Bar height = panel-size from settings.json; opacity 1.0 = solid wallust bg.
# ---------------------------------------------------------------------------
screen = Screen(
    top=bar.Bar(
        widgets_list,
        int(looks["panel-size"]),
        background=colors["bg"],
        opacity=float(looks["panel-opacity"]),
        margin=bar_margin,
    ),
)

screens = [screen]
