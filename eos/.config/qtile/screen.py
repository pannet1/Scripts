from libqtile.config import Screen
from libqtile import bar, widget, qtile
import os

terminal = "kitty"
font = "Cantarell"

colors = [
    ["#282c34", "#282c34"],  # panel background
    ["#3d3f4b", "#434758"],  # background for current screen tab
    ["#ffffff", "#ffffff"],  # font color for group names
    ["#ff5555", "#ff5555"],  # border line color for current tab
    [
        "#74438f",
        "#74438f",
    ],  # border line color for 'other tabs' and color for 'odd widgets'
    ["#4f76c7", "#4f76c7"],  # color for the 'even widgets'
    ["#e1acff", "#e1acff"],  # window name
    ["#ecbbfb", "#ecbbfb"],  # backbround for inactive screens
]

screens = [
    Screen(
        top=bar.Bar(
            [
                widget.Sep(padding=5, linewidth=0, background="#2f343f"),
                widget.Image(
                    filename="~/.config/qtile/eos-c.png",
                    margin=3,
                    background="#2f343f",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn("rofi -show drun")
                    },
                ),
                widget.Sep(padding=5, linewidth=0, background="#2f343f"),
                widget.GroupBox(
                    highlight_method="line",
                    this_screen_border="#5294e2",
                    this_current_screen_border="#5294e2",
                    active="#ffffff",
                    inactive="#848e96",
                    background="#2f343f",
                    font=font,
                    fontsize=16,
                    padding=4,
                    margin_y=4,
                ),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.Sep(padding=4, linewidth=0),
                widget.WindowName(
                    foreground="#99c0de",
                    fmt="{}",
                    font=font,
                    fontsize=13,
                    padding=3,
                ),
                widget.CurrentLayoutIcon(scale=0.70),
                widget.Sep(padding=4, linewidth=0),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.CheckUpdates(
                    update_interval=1800,
                    distro="Arch_yay",
                    display_format="{updates} Updates",
                    foreground="#ffffff",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn(terminal + " -e yay -Syu")
                    },
                    background="#2f343f",
                    font=font,
                    fontsize=15,
                    padding=8,
                ),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.Battery(),
                widget.Systray(icon_size=20),
                widget.Sep(padding=5, linewidth=0),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.Volume(
                    fontsize=16,
                    padding=3,
                    foreground=colors[4],
                    background="#2f343f",
                    mouse_callbacks={"Button1": lambda: qtile.cmd_spawn("pavucontrol")},
                    font=font,
                ),
                widget.Volume(
                    fontsize=16,
                    padding=3,
                    foreground=colors[4],
                    background="#2f343f",
                    mouse_callbacks={"Button1": lambda: qtile.cmd_spawn("pavucontrol")},
                    font=font,
                    emoji=True,
                ),
                widget.Sep(
                    padding=0, linewidth=5, foreground="#2f343f", size_percent=100
                ),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                    font=font,
                ),
                widget.Clock(
                    format="󰥔  %Y-%m-%d %a %I:%M %p",
                    background="#2f343f",
                    foreground="#9bd689",
                    padding=8,
                    font=font,
                    fontsize=15,
                ),
                widget.TextBox(
                    text="",
                    padding=0,
                    fontsize=28,
                    foreground="#2f343f",
                ),
                widget.TextBox(
                    text="⏻",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn(
                            os.path.expanduser("~/.config/rofi/powermenu.sh")
                        )
                    },
                    foreground="#e39378",
                    font=font,
                    fontsize=20,
                    padding=3,
                ),
                widget.Sep(padding=4, linewidth=0),
            ],
            30,  # height in px
            background="#404552",  # background color
        ),
    ),
]
