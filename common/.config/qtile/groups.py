"""Workspaces, app auto-assign rules, scratchpad. (Split from config.py.)

Appends the mod+1..9 number bindings to `keys` (imported from keys.py), so
this module must be imported AFTER keys — config.py imports keys first.
"""

from libqtile.config import Group, Key, Match, ScratchPad, DropDown
from libqtile.lazy import lazy

from keys import keys, mod, terminal

# ---------------------------------------------------------------------------
# Groups (virtual workspaces). Each tuple = (name, {default layout, bar icon,
# auto-assign rules}). `layout` = which layout new windows on this group use
# first (still cyclable with mod+Tab). `label` = Nerd-Font glyph in GroupBox.
# `matches` = list of `Match` rules: a newly opened window whose wm_class /
# title / role matches is SENT to that group automatically. Find a window's
# class with: `xprop | grep WM_CLASS` then click the window. Groups WITHOUT
# matches (coffee/bone) are purely manual parking spots.
# Number keys mod+1..9 are bound in the loop below (NOT by position here —
# by enumerate order, so reordering this list renumbers your shortcuts).
# ---------------------------------------------------------------------------
group_names = [
    # code: tiling dev scratch (bsp = binary-space partitions, great for terms)
    ("code", {"layout": "bsp", "label": "\uf121", "matches": [Match(wm_class="kitty")]}),
    # wifi: browser home (max = one fullscreen window, tab with mod+space)
    ("wifi", {"layout": "max", "label": "\uf1eb", "matches": [Match(wm_class="firefox")]}),
    # tv: video players fullscreen
    ("tv", {"layout": "max", "label": "\uf26c", "matches": [Match(wm_class="smplayer"), Match(wm_class="mpv"), Match(wm_class="vlc")]}),
    # comment: chat apps
    ("comment", {"layout": "max", "label": "\uf075", "matches": [Match(wm_class="Telegram"), Match(wm_class="telegram"), Match(wm_class="discord")]}),
    # gamepad: games/steam in zoomy (one big window + thumbnail strip)
    ("gamepad", {"layout": "zoomy", "label": "\uf11b", "matches": [Match(wm_class="steam")]}),
    # book: docs/PDF/office fullscreen reading
    ("book", {"layout": "max", "label": "\uf02d", "matches": [Match(wm_class="libreoffice"), Match(wm_class="evince"), Match(wm_class="zathura")]}),
    # box: file managers in zoomy preview style
    ("box", {"layout": "zoomy", "label": "\uf1b2", "matches": [Match(wm_class="pcmanfm"), Match(wm_class="org.gnome.Nautilus")]}),
    # coffee: manual overflow, floating layout (dialogs / stray windows)
    ("coffee", {"layout": "floating", "label": "\uf0f4"}),
    # bone: manual overflow, classic master/stack tiling
    ("bone", {"layout": "monadtall", "label": "\uf1b0"}),
]

# Build real Group objects from the table above...
groups = [Group(name, **kwargs) for name, kwargs in group_names]
# ...then append the hidden scratchpad. It never appears in GroupBox and has
# no number key — only mod+grave toggles its `term` dropdown. The dropdown
# spawns `kitty --class=scratchpad` so it does NOT match code's kitty rule;
# geometry is fractions of the screen (80% wide, 70% tall, offset 10%/15%).
groups.append(
    ScratchPad(
        "scratchpad",
        [
            DropDown(
                "term",
                terminal + " --class=scratchpad",
                width=0.8,
                height=0.7,
                x=0.1,
                y=0.15,
                opacity=1.0,
            )
        ],
    )
)

# Number-key bindings, generated from group_names order: mod+1..9 = view group,
# mod+shift+1..9 = send focused window there AND follow it (switch_group=True).
for i, (name, kwargs) in enumerate(group_names, 1):
    keys.append(
        Key([mod], str(i), lazy.group[name].toscreen(), desc=f"Switch to group {name}")
    )
    keys.append(
        Key(
            [mod, "shift"],
            str(i),
            lazy.window.togroup(name, switch_group=True),
            desc=f"Move window to group {name}",
        )
    )
