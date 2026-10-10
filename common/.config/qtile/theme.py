"""Shared settings, colors, wallpaper state. No window-manager objects here —
just data + helpers every other module imports. (Split out of config.py.)"""

# ---------------------------------------------------------------------------
# Standard-library imports. Keep import-time work fast: Qtile re-executes the
# whole config tree on EVERY `mod+ctrl+r` restart.
# ---------------------------------------------------------------------------
import os  # path expansion for wallpapers / autostart script
import random  # picking a random wallpaper when is_random=1
import json  # reading settings.json + wallust/qtile colors
import subprocess  # wallust, kitty remote, xwallpaper

# Home dir shorthand used for autostart.sh, wallust cache, kitty colors.
home = os.path.expanduser("~")

# ---------------------------------------------------------------------------
# External JSON settings. `looks` drives panel size/opacity, fonts, wallpaper
# behaviour; `display` is reserved for future multi-monitor work (currently
# unused — `screens` in bar.py is hardcoded to one screen).
# Edit: ~/.config/qtile/config/settings.json
# ---------------------------------------------------------------------------
with open("{}/.config/qtile/config/settings.json".format(os.getenv("HOME"))) as file:
    settings = json.load(file)

looks: dict = settings["looks"]
display: dict = settings["display"]  # NOTE: loaded but not wired up yet


# ---------------------------------------------------------------------------
# Wallpaper picker. Walks `wallpapers_dir` recursively and returns a random
# image; falls back to `default_wallpaper` when the dir is empty. Only used
# when `is_random == 1` in settings.json.
# ---------------------------------------------------------------------------
def random_wallpaper(wallpapers_dir: str, default_wallpaper: str) -> str:
    image_extensions = {
        ".jpg",
        ".jpeg",
        ".png",
        ".gif",
        ".bmp",
        ".webp",
        ".tiff",
        ".svg",
    }

    image_files = []
    for root, dirs, files in os.walk(wallpapers_dir):
        for file in files:
            if os.path.splitext(file)[1].lower() in image_extensions:
                image_files.append(os.path.join(root, file))

    if image_files:
        return random.choice(image_files)
    return default_wallpaper


# Resolve wallpaper preferences for THIS config load (i.e. every restart).
wallpaper = looks["wallpaper"]  # fallback single file
wallpaper_mode = looks.get("wallpaper_mode", "zoom")  # xwallpaper flag: --zoom/--maximize/...
wallpapers_dir = os.path.expanduser(
    looks.get("wallpapers_dir", "{}/.config/qtile/wallpapers".format(home))
)
is_random = looks.get("is_random", 0) == 1

# ---------------------------------------------------------------------------
# Wallpaper state + theming. Two speeds:
# - FAST PATH (every plain `mod+ctrl+r`): the applied wallpaper is stored in
#   ~/.cache/qtile-wallpaper and the wallust scheme in ~/.cache/wallust/.
#   Import just reads both files — zero subprocesses, zero flicker.
# - SLOW PATH (first run, wiped cache, or changed wallpaper): pick the file,
#   store it, then run wallust + repaint synchronously so the colors below
#   always match the wallpaper. Only `mod+w` takes this path deliberately;
#   plain restarts never re-roll anymore.
# ---------------------------------------------------------------------------
wallpaper_state_file = "{}/.cache/qtile-wallpaper".format(home)
cache_colors = "{}/.cache/wallust/qtile-colors.json".format(home)


def read_stored_wallpaper():
    # Absolute path of the last applied wallpaper, or None.
    try:
        with open(wallpaper_state_file) as f:
            p = f.read().strip()
    except OSError:
        return None
    return p if p and os.path.isfile(os.path.expanduser(p)) else None


def store_wallpaper(path):
    try:
        with open(wallpaper_state_file, "w") as f:
            f.write(path)
    except OSError:
        pass  # cache unwritable — worst case we re-pick next restart


def apply_theme(wallpaper_path):
    # Blocking: wallust regenerates the scheme, xwallpaper repaints the root
    # window, kitty live-reloads via its unix:/tmp/kitty socket (silent no-op
    # when kitty isn't running). Called ONLY on wallpaper change, never on
    # plain restarts — that's what makes restarts instant.
    wp = os.path.expanduser(wallpaper_path)
    if subprocess.run(["which", "wallust"], capture_output=True).returncode == 0:
        subprocess.call(["wallust", "run", "-q", wp])
    if subprocess.run(["which", "xwallpaper"], capture_output=True).returncode == 0:
        subprocess.call(["xwallpaper", "--" + wallpaper_mode, wp])
    if subprocess.run(["which", "kitty"], capture_output=True).returncode == 0:
        subprocess.call(
            [
                "kitty",
                "@",
                "--to",
                "unix:/tmp/kitty",
                "set-colors",
                "-a",
                "{}/.config/kitty/colors.conf".format(home),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


stored_wallpaper = read_stored_wallpaper()
if is_random:
    final_wallpaper = os.path.expanduser(
        stored_wallpaper or random_wallpaper(wallpapers_dir, wallpaper)
    )
else:
    final_wallpaper = os.path.expanduser(wallpaper)

if stored_wallpaper != final_wallpaper or not os.path.isfile(cache_colors):
    store_wallpaper(final_wallpaper)
    apply_theme(final_wallpaper)

# ---------------------------------------------------------------------------
# Color scheme: prefer the wallust-generated file, fall back to the committed
# default. Keys used below: bg/fg (bar), active/inactive (GroupBox),
# border_focus/border_normal (window borders), groups_bg/systray/seperator
# (widget backgrounds), color1..5 + colorNfg (clock/volume blocks).
# ---------------------------------------------------------------------------
with open(
    cache_colors
    if os.path.isfile(cache_colors)
    else "{}/.config/qtile/config/colors.json".format(os.getenv("HOME"))
) as file:
    colors_json = json.load(file)

colors = colors_json
