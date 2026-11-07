"""Sublime Text."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS, folder_from_env
from ..ui import say, step
from . import App


def sublime_data_dirs():
    """Sublime Text's data folders: Sublime Text 4's, and Sublime Text 3's,
    the Flatpak's and the Snap's when they exist."""
    if OS == "Darwin":
        dirs = [HOME / "Library/Application Support/Sublime Text"]
        if (HOME / "Library/Application Support/Sublime Text 3").is_dir():
            dirs.append(HOME / "Library/Application Support/Sublime Text 3")
        return dirs
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    dirs = [config / "sublime-text"]
    if (config / "sublime-text-3").is_dir():
        dirs.append(config / "sublime-text-3")
    if (HOME / ".var/app/com.sublimetext.three").is_dir():
        dirs.append(HOME / ".var/app/com.sublimetext.three/config/sublime-text")
    if (HOME / "snap/sublime-text").is_dir():
        dirs.append(HOME / "snap/sublime-text/current/.config/sublime-text")
    return dirs


def install(theme):
    file = f"jenerated-{theme.slug}.sublime-color-scheme"

    for folder in sublime_data_dirs():
        plan_link(folder / f"Packages/User/{file}", paths.app_themes(f"sublime-theme/{file}"))
    run_install_plan("the Sublime Text color scheme")

    step("Done! To turn the color scheme on, in Sublime Text:")
    say("1. Open the command palette (Ctrl+Shift+P, or Cmd+Shift+P on a Mac),")
    say(f'   choose "UI: Select Color Scheme", then "Jenerated {theme.name}".')
    say('2. For the sidebar and tabs to match, choose "UI: Select Theme" there')
    say('   too, then "Adaptive", which takes its colors from the color scheme.')
    say("Sublime Text reloads the color scheme when the palette changes and")
    say(f"{state.regenerate(theme.slug)} runs again.")


APP = App(
    id="sublime",
    label="Sublime Text",
    category="editors",
    templates=(
        ("app-themes/sublime-theme/color-scheme.tmpl",
         "app-themes/sublime-theme/jenerated-{slug}.sublime-color-scheme"),
    ),
    commands=("subl", "sublime_text"),
    flatpaks=("com.sublimetext.three",),
    mac_apps=("Sublime Text",),
    install=install,
)
