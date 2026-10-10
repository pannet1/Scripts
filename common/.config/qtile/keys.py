"""Leader key, apps, custom commands, keybindings, mouse. (Split from config.py.)

`lazy.X` builds a deferred command Qtile runs on keypress — nothing executes
at import time. Always set `desc=` (shows in `qtile cmd-obj` introspection).
`groups.py` appends the mod+1..9 bindings to `keys` (imported from here).
"""

from libqtile.config import Click, Drag, Key
from libqtile.lazy import lazy
import os  # expanduser for the re-rolled wallpaper path
import subprocess  # rofi power menu
from datetime import datetime  # one-off timestamp in the mod+d notifier

from theme import (
    wallpaper,
    wallpapers_dir,
    is_random,
    random_wallpaper,
    store_wallpaper,
    apply_theme,
)


# ---------------------------------------------------------------------------
# Custom lazy functions. `@lazy.function` turns a Python function into a
# keybindable command: it receives the live `qtile` manager object, so it can
# spawn processes (`qtile.spawn`), restart/shutdown Qtile, or run blocking
# subprocess calls (rofi). Call them in Key() with trailing parens, e.g.
# `Key([mod], "w", reroll_wallpaper())`.
# ---------------------------------------------------------------------------
@lazy.function
def reroll_wallpaper(qtile):
    # The ONLY path that changes the wallpaper: pick a new file, store it,
    # apply the theme synchronously (fresh cache), then restart. The restart
    # re-imports this config and takes the fast path in theme.py.
    new_wall = (
        random_wallpaper(wallpapers_dir, wallpaper) if is_random else wallpaper
    )
    new_wall = os.path.expanduser(new_wall)
    store_wallpaper(new_wall)
    apply_theme(new_wall)
    qtile.spawn("notify-send 'Qtile: wallpaper + theme updated'")
    qtile.restart()


@lazy.function
def show_power_menu(qtile):
    # Rofi-driven power menu. Needs only `rofi` (no rofi-power-menu plugin).
    # Pipes 5 options into `rofi -dmenu`, reads the choice from stdout, acts.
    # `qtile.spawn` = run a shell command; `qtile.shutdown()` = quit Qtile
    # (logout to the display manager / startx); `qtile.restart()` = reload.
    opts = "shutdown\nreboot\nsuspend\nlogout\nrestart-qtile"
    try:
        p = subprocess.run(
            ["rofi", "-dmenu", "-p", "power", "-i"],
            input=opts,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except Exception:
        return  # rofi missing / user pressed Esc — do nothing
    choice = (p.stdout or "").strip()
    if choice == "shutdown":
        qtile.spawn("systemctl poweroff")
    elif choice == "reboot":
        qtile.spawn("systemctl reboot")
    elif choice == "suspend":
        qtile.spawn("systemctl suspend")
    elif choice == "logout":
        qtile.shutdown()
    elif choice == "restart-qtile":
        qtile.restart()


# ---------------------------------------------------------------------------
# Leader key + default apps. `mod4` = Super/Windows key. Change `terminal`
# once here and the scratchpad DropDown (groups.py) + mod+Return follow.
# ---------------------------------------------------------------------------
mod = "mod4"  # Super/Windows key — every Qtile shortcut starts with this
terminal = "kitty"  # also used by the scratchpad dropdown in groups.py
browser = "firefox"  # mod+b
file_manager = "pcmanfm"  # mod+c

# ---------------------------------------------------------------------------
# Keybindings. Each `Key(modifiers, key, command, desc=...)`:
# - modifiers: [mod], [mod,"shift"], [mod,"control"], or [] for bare media keys
# - `lazy.layout.*` acts on the CURRENT LAYOUT (no-op if that layout lacks
#   the command — e.g. shuffle_* does nothing in Max).
# - `lazy.window.*` acts on the FOCUSED WINDOW (kill/floating/fullscreen).
# - `lazy.spawn(...)` runs a shell command; `lazy.group[name]...` jumps groups.
# ---------------------------------------------------------------------------
keys = [
    # --- Focus: move keyboard focus between tiled windows (vim-style) ---
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),
    # --- Shuffle: swap the focused window with its neighbour. In Bsp this
    # --- rearranges the binary tree; in MonadTall it moves within the stack.
    # --- No-op in Max/Zoomy (single-window layouts have nothing to swap).
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
    # --- Grow: resize the focused window toward a screen edge. If the window
    # --- is already ON that edge, it shrinks instead (edge behaviour).
    Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key(
        [mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"
    ),
    Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    # --- Layout-specific: normalize (MonadTall/Bsp reset sizes), grow/shrink
    # --- (master-area ratio), maximize (fill stack). Each is a no-op where
    # --- the active layout doesn't implement it.
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod], "i", lazy.layout.grow(), desc="Grow master area"),
    Key([mod], "m", lazy.layout.shrink(), desc="Shrink master area"),
    Key([mod], "o", lazy.layout.maximize(), desc="Maximize focused window in stack"),
    # --- Window state: fullscreen removes ALL chrome (panel included);
    # --- floating takes the window out of the tiling flow (drag it with
    # --- mod+left-click, resize with mod+right-click — see `mouse` below).
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key(
        [mod, "shift"], "f", lazy.window.toggle_floating(), desc="Toggle floating"
    ),
    # --- Wallpaper: explicit re-roll (pick + theme + restart).
    Key([mod], "w", reroll_wallpaper(), desc="Re-roll random wallpaper + theme"),
    # --- Stack split (MonadTall): split = all windows visible; unsplit = one
    # --- window visible like Max but keeping the stack panes behind it.
    Key(
        [mod, "shift"],
        "Return",
        lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack",
    ),
    # --- Launchers ---
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "control"], "r", lazy.restart(), desc="Restart Qtile"),
    Key(
        [mod, "control"],
        "q",
        lazy.spawn("systemctl poweroff"),
        desc="Power off machine",
    ),
    Key(
        [mod],
        "r",
        lazy.spawn("rofi -show drun"),
        desc="Spawn a command using rofi",
    ),
    Key([mod], "t", lazy.spawncmd(), desc="Spawn a command using a prompt"),
    Key([mod], "b", lazy.spawn(browser), desc="Launch web browser"),
    Key([mod], "c", lazy.spawn(file_manager), desc="Launch File Manager"),
    Key(
        [mod], "v", lazy.spawn("rofi -show window"), desc="Show active windows in rofi"
    ),
    # --- Screenshots: flameshot GUI (region select) vs scrot (bare fullscreen
    # --- dump to CWD — consider `scrot ~/Pictures/%Y-%m-%d.png` for order).
    Key([mod, "control"], "s", lazy.spawn("flameshot gui"), desc="Open flameshot gui"),
    Key([mod], "s", lazy.spawn("scrot"), desc="Take full screen ss using scrot"),
    # --- Timestamp ping. NOTE: `datetime.now()` is evaluated at IMPORT time,
    # --- so this always notifies the Qtile START time, not press time. Fix:
    # --- wrap in @lazy.function and call datetime.now() inside the function.
    Key(
        [mod],
        "d",
        lazy.spawn(f"notify-send '{datetime.now()}'"),
        desc="Show date and time",
    ),
    # --- Volume (PipeWire via wpctl — same tool autostart.sh unmutes with).
    # --- `[]` = no modifier: these are the bare XF86 laptop media keys.
    Key(
        [],
        "XF86AudioRaiseVolume",
        lazy.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        desc="Volume up",
    ),
    Key(
        [],
        "XF86AudioLowerVolume",
        lazy.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        desc="Volume down",
    ),
    Key(
        [],
        "XF86AudioMute",
        lazy.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        desc="Mute toggle",
    ),
    # --- Brightness (needs: sudo apt install brightnessctl — now in install-debian.sh).
    Key(
        [],
        "XF86MonBrightnessUp",
        lazy.spawn("brightnessctl s +5%"),
        desc="Brightness up",
    ),
    Key(
        [],
        "XF86MonBrightnessDown",
        lazy.spawn("brightnessctl s 5%-"),
        desc="Brightness down",
    ),
    # --- Power menu (custom rofi -dmenu function above) + scratchpad toggle.
    # --- `grave` = the backtick key top-left under Esc. Scratchpad = a hidden
    # --- group whose DropDown terminal slides over ANY workspace, same spot.
    Key([mod, "shift"], "q", show_power_menu(), desc="Power menu (rofi)"),
    # --- Wifi picker: the tray icon shows the connection but no network list
    # --- under StatusNotifier, so this opens the full NM editor to switch AP.
    # --- (Right-clicking the tray icon may also show its DBus menu.)
    Key(
        [mod, "shift"], "w", lazy.spawn("nm-connection-editor"),
        desc="Wifi/network picker",
    ),
    Key(
        [mod],
        "grave",
        lazy.group["scratchpad"].dropdown_toggle("term"),
        desc="Toggle scratchpad terminal",
    ),
]

# ---------------------------------------------------------------------------
# Mouse bindings for floating windows (tiling layouts ignore dragging).
# mod+left-drag = move, mod+right-drag = resize, mod+middle-click = raise.
# `start=lazy.window.get_position()` records the grab point so motion is
# relative, not jumping. Tiled windows need mod+shift+f first to float them.
# ---------------------------------------------------------------------------
mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position(),
    ),
    Drag(
        [mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()
    ),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]
