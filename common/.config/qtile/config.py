"""Qtile window-manager config — thin orchestrator (Step 7 split).

Qtile mental model in 30 seconds:
- A `Group` is a virtual workspace. Only one is visible per screen; windows
  live on exactly one group (except scratchpad windows, which float above all).
- A `layout` decides how tiled windows share the screen. `mod+Tab` cycles
  `layouts`; each group remembers its own layout.
- `Key` + `lazy` = declarative keybindings; `lazy.X` runs on keypress.
- `bar` + `widget` = the top panel. `hook` = lifecycle callbacks.

Flat modules next to this file (NOT a `config/` package: Qtile loads THIS
file itself as top-level module `config`, so a `config/` directory would
shadow it and `import config.theme` would resolve to this file). Qtile inserts
this directory into sys.path on load and auto-reloads modules under it on
`mod+ctrl+r`, so plain `import theme` etc. just works.

- theme.py: settings.json, wallust colors, wallpaper state + apply_theme()
- keys.py: mod/apps, lazy functions, keys list, mouse
- groups.py: workspaces + matches + scratchpad + mod+1..9 (appends to keys)
- layouts.py: layout_theme, layouts, floating_layout
- bar.py: pills, widgets_list, screens
- hooks.py: startup_once/startup (import registers them)

Reload after edits: `qtile check` in a terminal, then `mod+ctrl+r`.
"""

from keys import keys, mouse
from groups import groups
from layouts import layouts, floating_layout
from bar import screens, widget_defaults, extension_defaults
import hooks  # noqa: F401 — import side effect: registers startup hooks

# ---------------------------------------------------------------------------
# Window-manager behaviour flags. The ones that matter daily:
# - follow_mouse_focus: focus follows the cursor (sloppy focus).
# - bring_front_click: clicking an unfocused window brings it to front AND
#   focuses it (False would require click-to-focus then click-to-raise).
# - auto_fullscreen: apps requesting fullscreen (games, mpv -fs) actually get it.
# - focus_on_window_activation="smart": new windows (e.g. dialogs) take focus
#   only when sensible — "urgent" would instead set the urgency hint.
# - reconfigure_screens: re-detect monitors on randr changes (docking).
# - auto_minimize: minimized windows unminimize when their group is viewed.
# - dgroups_* = dynamic-group machinery, unused (static `groups` win).
# ---------------------------------------------------------------------------
dgroups_key_binder = None
dgroups_app_rules = []  # type: list
follow_mouse_focus = True
bring_front_click = True
cursor_warp = False  # True would teleport the cursor to the focused window
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True

# Java WM compatibility lie. Some Java apps (IntelliJ, etc.) check the WM name
# and break on unknown WMs; "LG3D" pretends to be an old Java-friendly one.
wmname = "LG3D"
