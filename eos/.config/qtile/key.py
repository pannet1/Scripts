from constants import terminal, mod, browser
from libqtile.dgroups import simple_key_binder
from libqtile.config import Key, Group, ScratchPad, DropDown
from libqtile.lazy import lazy

keys = [
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    # Switch between windows
    Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),
    # custom short cuts
    Key([mod], "b", lazy.spawn(browser), desc="Launch browser"),
    Key([mod], "c", lazy.spawn("flameshot"), desc="take screenshot"),
    Key([mod], "f", lazy.spawn("thunar"), desc="Launch File Manager"),
    # layouts
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    # custom short cuts
    Key([mod], "m", lazy.spawn("betterbird"), desc="check mail"),
    # RESET ALL WINDOWS
    # Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod], "o", lazy.spawn("libreoffice"), desc="Kill focused window"),
    # n taken for normalize window
    Key([mod], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod], "r", lazy.spawn("rofi -show drun"), desc="spawn rofi"),
    Key([mod], "s", lazy.spawn("scrot"), desc="Take full screen ss using scrot"),
    Key([mod], "t", lazy.spawncmd(), desc="Spawn a command using a prompt"),
    Key(
        [mod], "w", lazy.spawn("rofi -show window"), desc="Show active windows in rofi"
    ),
    Key([mod], "x", lazy.spawn("telegram-desktop"), desc="messaging"),
    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key(
        [mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"
    ),
    Key(
        [mod, "shift"],
        "l",
        lazy.layout.shuffle_right(),
        desc="Move window to the right",
    ),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow(), desc="Grow window"),
    Key([mod, "control"], "l", lazy.layout.shrink(), desc="Shrink window"),
    # Utility
    Key([mod, "control"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    # Key([mod, "shift", "control"], "h", lazy.layout.swap_column_left()),
    Key([mod, "shift", "control"], "l", lazy.layout.swap_column_right()),
    Key(
        [mod, "shift"],
        "Return",
        lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack",
    ),
    Key([mod, "shift"], "space", lazy.layout.flip()),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("amixer set Master 3%+")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("amixer set Master 3%-")),
    Key([], "XF86AudioMute", lazy.spawn("amixer set Master toggle")),
]


####################################################
####################################################
#                                                  #
#                   Groups                         #
#                                                  #
####################################################
####################################################

groups = [Group(i) for i in "12345678"]

keys.extend(
    [
        Key([mod], "Right", lazy.screen.next_group(), desc="Switch to next group"),
        Key([mod], "Left", lazy.screen.prev_group(), desc="Switch to previous group"),
    ]
)

for i in groups:
    keys.extend(
        [
            # mod1 + number of group = switch to group
            Key(
                [mod],
                i.name,
                lazy.group[i.name].toscreen(),
                desc="Switch to group {}".format(i.name),
            ),
            # mod1 + shift + number of group = switch to & move focused window to group
            Key(
                [mod, "shift"],
                i.name,
                lazy.window.togroup(i.name, switch_group=True),
                desc="Switch to & move focused window to group {}".format(i.name),
            ),
            # Or, use below if you prefer not to switch to that group.
            # # mod1 + shift + number of group = move focused window to group
            # Key([mod, "shift"], i.name, lazy.window.togroup(i.name),
            #     desc="move focused window to group {}".format(i.name)),
        ]
    )


dgroups_key_binder = simple_key_binder(mod)
# --------------------------------------------------------
# Scratchpads
# --------------------------------------------------------

groups.append(
    ScratchPad(
        "9",
        [
            DropDown(
                "chatgpt",
                "chromium --app=https://chat.openai.com",
                x=0.3,
                y=0.1,
                width=0.40,
                height=0.4,
                on_focus_lost_hide=False,
            ),
            DropDown(
                "editor",
                "xed",
                x=0.3,
                y=0.1,
                width=0.40,
                height=0.4,
                on_focus_lost_hide=False,
            ),
            DropDown(
                "terminal",
                "kitty",
                x=0.3,
                y=0.1,
                width=0.40,
                height=0.4,
                on_focus_lost_hide=False,
            ),
            DropDown(
                "scrcpy",
                "scrcpy -d",
                x=0.8,
                y=0.05,
                width=0.15,
                height=0.6,
                on_focus_lost_hide=False,
            ),
        ],
    )
)


keys.extend(
    [
        Key([mod], "F10", lazy.group["9"].dropdown_toggle("chatgpt")),
        Key([mod], "F11", lazy.group["9"].dropdown_toggle("editor")),
        Key([mod], "F12", lazy.group["9"].dropdown_toggle("terminal")),
        Key([mod], "F9", lazy.group["9"].dropdown_toggle("scrcpy")),
    ]
)
