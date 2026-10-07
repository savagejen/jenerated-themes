"""Spyder."""

import ast
import configparser
import io
import os
import sys
from pathlib import Path

from .. import paths, state
from ..system import HOME, OS, backup_once, folder_from_env, replace_text, succeeds
from ..ui import ask_yes, say, step, stop
from . import App


def spyder_ini_files():
    """Spyder's settings files (spyder.ini): the usual one, and, if Spyder was
    installed through Flatpak, the one in the folder Flatpak gives it."""
    if os.environ.get("SPYDER_CONFDIR"):
        files = [Path(os.environ["SPYDER_CONFDIR"]) / "config/spyder.ini"]
    elif OS == "Darwin":
        files = [HOME / ".spyder-py3/config/spyder.ini"]
    else:
        config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
        files = [config / "spyder-py3/config/spyder.ini"]
    if (HOME / ".var/app/org.spyder_ide.spyder").is_dir():
        files.append(HOME / ".var/app/org.spyder_ide.spyder/config/spyder-py3/config/spyder.ini")
    return files


def add_spyder_theme(ini_path, theme_path, select):
    """Adds the theme to spyder.ini as a custom theme: the custom-N that
    already has this name, or else the lowest free N (Spyder expects custom
    themes to be named custom-<number>). With select, also makes it the
    current theme. Returns False if it couldn't."""
    def parser():
        p = configparser.ConfigParser(interpolation=None, comment_prefixes=(";", "#"))
        p.optionxform = str
        return p

    try:
        theme = parser()
        theme.read(theme_path)
        theme = dict(theme["appearance"])
        ini = parser()
        ini.read(ini_path)
        if not ini.has_section("appearance"):
            ini.add_section("appearance")
        section = ini["appearance"]
        names = ast.literal_eval(section.get("custom_names", "[]"))
        scheme = next((n for n in names if section.get(f"{n}/name") == theme["name"]), None)
        if scheme is None:
            used = {int(n.split("-")[-1]) for n in names}
            scheme = "custom-%d" % min(set(range(len(used) + 1)) - used)
            names = sorted(names + [scheme], key=lambda n: int(n.split("-")[-1]))
        section["custom_names"] = repr(names)
        for key, value in theme.items():
            section[f"{scheme}/{key}"] = value
        if select:
            section["selected"] = scheme
        text = io.StringIO()
        ini.write(text)
        replace_text(ini_path, text.getvalue())
        return True
    except (OSError, ValueError, KeyError, SyntaxError, configparser.Error) as error:
        sys.stderr.write(f"{type(error).__name__}: {error}\n")
        return False


def install(theme):
    theme_file = paths.app_themes(f"spyder-theme/jenerated-{theme.slug}.ini")
    found = [ini for ini in spyder_ini_files() if ini.is_file()]
    select = False

    step("Adding the theme to Spyder's settings")
    if not found:
        if state.current.auto:
            stop("Spyder hasn't been opened yet, so it has no settings to add the theme to; "
                f"open it once, close it, and run {state.COMMAND} again")
        say("Spyder hasn't been opened yet, so it has no settings to add the theme to.")
        say(f"Open it once, close it, and run {state.COMMAND} again.")
        return
    # Spyder runs as a process named spyder, or as python -m spyder.
    if succeeds(["pgrep", "-ix", "spyder"]) or succeeds(["pgrep", "-f", "--", "-m spyder( |$)"]):
        if state.current.auto:
            stop("Spyder is open, and would undo the change when it closes; close it and run "
                f"{state.COMMAND} again")
        say("Spyder is open, and it saves its settings when it closes, which would")
        say(f"undo any change made now. Close it and run {state.COMMAND} again.")
        return
    if ask_yes(f"Also make Jenerated {theme.name} Spyder's current syntax theme?"):
        select = True
    for ini in found:
        backup_once(ini)
        if not add_spyder_theme(ini, theme_file, select):
            stop(f"couldn't update {ini}")
        say(f"Updated {ini}")

    step(f"Done! Open Spyder to use Jenerated {theme.name}.")
    if not select:
        say("Choose it under Tools -> Preferences -> Appearance -> Syntax")
        say("highlighting theme.")
    say("The theme is copied into Spyder's settings, so after changing the")
    say(f"palette, run {state.COMMAND} again (with Spyder closed).")


APP = App(
    id="spyder",
    label="Spyder",
    category="editors",
    templates=(
        ("app-themes/spyder-theme/scheme.ini.tmpl",
         "app-themes/spyder-theme/jenerated-{slug}.ini"),
    ),
    words=("python", "scientific", "anaconda"),
    commands=("spyder",),
    flatpaks=("org.spyder_ide.spyder",),
    mac_apps=("Spyder",),
    install=install,
)
