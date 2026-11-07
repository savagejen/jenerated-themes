"""Godot."""

import re
import sys

from .. import paths, state
from ..install import install_link
from ..system import (HOME, OS, backup_once, folder_from_env, lines_of, make_folders, read_text,
                      succeeds, write_text)
from ..ui import ask_yes, say, step, stop
from . import App


def godot_config_dirs():
    """Where Godot keeps its editor settings: the usual place, and, if Godot
    was installed through Flatpak, the folder Flatpak gives it."""
    if OS == "Darwin":
        return [HOME / "Library/Application Support/Godot"]
    dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "godot"]
    for app in ("org.godotengine.Godot", "org.godotengine.GodotSharp"):
        if (HOME / f".var/app/{app}").is_dir():
            dirs.append(HOME / f".var/app/{app}/config/godot")
    return dirs


def version_key(text):
    """Sorts version numbers by their value, so 4.10 comes after 4.9."""
    return [(int(part), "") if part.isdigit() else (-1, part) for part in re.split(r"(\d+)", text)]


def godot_settings_file(folder):
    """The newest editor settings file in a Godot config folder, or None. Godot
    4.3 and later name it editor_settings-4.<minor>.tres; earlier 4.x
    versions, editor_settings-4.tres."""
    found = sorted(folder.glob("editor_settings-4.[0-9]*.tres"),
                   key=lambda path: version_key(path.name))
    if found:
        return found[-1]
    if (folder / "editor_settings-4.tres").is_file():
        return folder / "editor_settings-4.tres"
    return None


def godot_manual_steps(cfg):
    """Prints the settings to change by hand, from the comment in
    editor-settings.cfg."""
    say("In Godot, open Editor -> Editor Settings and set:")
    for line in lines_of(cfg):
        if line.startswith(";   "):
            say("  " + line[4:])


def apply_godot_settings(settings_path, cfg_path):
    """Sets each "key = value" line of the cfg file in Godot's editor
    settings, replacing the key's line if it's there and adding it if not.
    Returns False if it couldn't."""
    try:
        text = read_text(settings_path)
        if not re.search(r"^\[resource\]$", text, re.M):
            sys.stderr.write(f"{settings_path} does not look like Godot editor settings\n")
            return False
        for line in read_text(cfg_path).splitlines():
            if not line.strip() or line.startswith(";"):
                continue
            key = line.split(" = ", 1)[0]
            pattern = re.compile(rf"^{re.escape(key)} = .*$", re.M)
            if pattern.search(text):
                text = pattern.sub(lambda m: line, text, count=1)
            else:
                text = text.rstrip("\n") + "\n" + line + "\n"
        write_text(settings_path, text)
        return True
    except OSError as error:
        sys.stderr.write(f"{error}\n")
        return False


def install(theme):
    folder = paths.app_themes(f"godot-theme/{theme.slug}")
    editor_theme = f"Jenerated-{theme.slug}"
    cfg = folder / "editor-settings.cfg"
    applied = False
    files = []

    dirs = godot_config_dirs()

    step("Installing the Godot script editor theme")
    for folder_ in dirs:
        make_folders(folder_ / "text_editor_themes")
        install_link(folder_ / f"text_editor_themes/{editor_theme}.tet",
                     folder / f"{editor_theme}.tet")
        settings = godot_settings_file(folder_)
        if settings:
            files.append(settings)

    # The rest of the editor takes its colors from a few editor settings.
    say("")
    if not files:
        say("Godot hasn't been opened yet, so it has no editor settings to change.")
        say(f"Open it once and run {state.COMMAND} again, or set the colors by hand.")
    elif succeeds(["pgrep", "-i", "godot"]):
        say("Godot is open, and it saves its settings when it closes, which would")
        say(f"undo any change made now. Close it and run {state.COMMAND} again, or set")
        say("the colors by hand.")
    elif ask_yes(f"Set Godot's editor colors to Jenerated {theme.name}? (Your settings are "
                 "backed up first.)"):
        for settings in files:
            backup_once(settings)
            if not apply_godot_settings(settings, cfg):
                stop(f"couldn't update {settings}")
            say(f"Updated {settings}")
        applied = True

    if applied:
        step(f"Done! Open Godot: the editor and the script editor use Jenerated {theme.name}.")
        say("To go back, choose Default for Color Preset and Color Theme in")
        say("Editor -> Editor Settings, or restore the backup with Godot closed:")
        for settings in files:
            say(f'    cp "{settings}.before-jenerated" "{settings}"')
    else:
        step("Done! To turn the theme on:")
        godot_manual_steps(cfg)
    say(f"After changing the palette, run {state.COMMAND} again (the script editor")
    say("theme updates by itself, but the interface colors are copied).")


APP = App(
    id="godot",
    label="Godot",
    category="editors",
    templates=(
        ("app-themes/godot-theme/text-editor.tet.tmpl",
         "app-themes/godot-theme/{slug}/Jenerated-{slug}.tet"),
        ("app-themes/godot-theme/editor-settings.cfg.tmpl",
         "app-themes/godot-theme/{slug}/editor-settings.cfg"),
    ),
    words=("game", "engine", "gdscript"),
    commands=("godot", "godot4", "godot3"),
    flatpaks=("org.godotengine.Godot",),
    mac_apps=("Godot",),
    one_palette=True,
    install=install,
)
