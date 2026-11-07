"""Krita (painting)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS, folder_from_env
from ..ui import say, step
from . import App


def krita_scheme_dirs():
    """Where Krita looks for color themes: the color-schemes folder in its
    resources folder, for a regular install and for the Flatpak."""
    if OS == "Darwin":
        dirs = [HOME / "Library/Application Support/krita/color-schemes"]
    else:
        dirs = [folder_from_env("XDG_DATA_HOME", HOME / ".local/share") / "krita/color-schemes"]
    if (HOME / ".var/app/org.kde.krita").is_dir():
        dirs.append(HOME / ".var/app/org.kde.krita/data/krita/color-schemes")
    return dirs


def install(theme):
    """Krita reads KDE color schemes, so it uses the KDE theme's .colors
    file."""
    file = f"Jenerated-{theme.slug}.colors"

    for folder in krita_scheme_dirs():
        plan_link(folder / file, paths.app_themes(f"kde-theme/{theme.slug}/{file}"))
    run_install_plan("the Krita color theme")

    step("Done! To turn the theme on:")
    say("1. Restart Krita if it's open; it reads its themes when it starts.")
    say(f'2. Choose Settings -> Themes -> "Jenerated {theme.name}".')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart Krita.")


APP = App(
    id="krita",
    label="Krita (painting)",
    category="art",
    words=("paint", "painting", "drawing", "illustration", "art"),
    commands=("krita",),
    flatpaks=("org.kde.krita",),
    mac_apps=("krita",),
    install=install,
)
