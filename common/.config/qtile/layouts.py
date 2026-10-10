"""Tiling layouts + floating rules. (Split from config.py.)"""

from libqtile import layout
from libqtile.config import Match

from theme import colors

# ---------------------------------------------------------------------------
# Layout theme + layout list. `layout_theme` = shared knobs (1px borders,
# 2px gaps, wallust-driven focus colors). Per-layout extras BELOW because each
# layout has its OWN single-window API: MonadTall uses single_border_width/
# single_margin, Bsp uses border_on_single/margin_on_single, Max just wants
# border 0/margin 0, Zoomy/Floating ignore single-window opts entirely
# (passing them would fail `qtile check`). `mod+Tab` cycles this list in order.
# ---------------------------------------------------------------------------
layout_theme = {
    "border_width": 1,  # focused/unfocused window outline thickness
    "margin": 2,  # gap between tiled windows (and screen edge)
    "border_focus": colors["border_focus"],  # wallust accent for active window
    "border_normal": colors["border_normal"],  # usually = bg, i.e. invisible
}

layouts = [
    # MonadTall: classic master (left, ratio=0.60 of screen) + stack (right).
    # Single window -> no border/gap (feels maximized but stays tiled).
    layout.MonadTall(
        **layout_theme, single_border_width=0, single_margin=0, ratio=0.60
    ),
    # Floating: unmanaged free windows (dialogs land here; mod+shift+f moves
    # anything here; drag with mod+left-click — see `mouse` in keys.py).
    layout.Floating(**layout_theme),
    # Max: exactly one fullscreen window, zero chrome. Best with matches
    # groups (wifi/tv/comment/book) where you flip with mod+space.
    layout.Max(
        border_width=0,
        margin=0,
        border_focus=colors["border_focus"],
        border_normal=colors["border_normal"],
    ),
    # Bsp: binary-space-partitioning fair splitter. border_on_single=False +
    # margin_on_single=0 = lone window fills the screen edgeless.
    layout.Bsp(
        **layout_theme, border_on_single=False, margin_on_single=0, fair=True
    ),
    # Zoomy: one hero window + live thumbnail column on the right
    # (columnwidth=200px). Used by gamepad/box groups.
    layout.Zoomy(**layout_theme, columnwidth=200),
]

# ---------------------------------------------------------------------------
# floating_layout: which NEW windows skip tiling and float immediately.
# Starts from Qtile's defaults (dialogs, splash, toolbars...) then adds app
# quirks below. Diagnose any window with `xprop`: click it, read WM_CLASS /
# WM_TYPE / WM_NAME, add a Match line. `coffee` group uses this same layout
# object for its manual floating workspace.
# ---------------------------------------------------------------------------
floating_layout = layout.Floating(
    **layout_theme,
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_type="utility"),
        Match(wm_type="notification"),
        Match(wm_type="toolbar"),
        Match(wm_type="splash"),
        Match(wm_type="dialog"),
        Match(wm_class="confirm"),
        Match(wm_class="dialog"),
        Match(wm_class="download"),
        Match(wm_class="error"),
        Match(wm_class="file_progress"),
        Match(wm_class="notification"),
        Match(wm_class="splash"),
        Match(wm_class="toolbar"),
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(wm_class="pomotroid"),
        Match(wm_class="cmatrixterm"),
        Match(title="Farge"),
        Match(wm_class="org.gnome.Nautilus"),
        Match(wm_class="feh"),
        Match(wm_class="plank"),
        Match(wm_class="gnome-calculator"),
        Match(wm_class="blueberry"),
        Match(wm_class="protonvpn"),
    ],
)
