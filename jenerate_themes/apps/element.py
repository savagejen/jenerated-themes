"""Element (Matrix chat)."""

import json
import sys

from .. import paths, state
from ..system import HOME, OS, backup_once, folder_from_env, make_folders, replace_text
from ..ui import say, step, stop
from . import App


def element_config_dirs():
    """Element Desktop's settings folders: the usual one, and, if Element was
    installed through Flatpak, the folder Flatpak gives it."""
    if OS == "Darwin":
        return [HOME / "Library/Application Support/Element"]
    dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "Element"]
    if (HOME / ".var/app/im.riot.Riot").is_dir():
        dirs.append(HOME / ".var/app/im.riot.Riot/config/Element")
    return dirs


def add_element_theme(config_path, theme_path):
    """Adds the theme to Element's config.json, in
    setting_defaults.custom_themes, replacing any earlier Jenerated theme and
    keeping everything else in the file. Returns False if it couldn't."""
    try:
        config = {}
        if config_path.exists():
            with open(config_path) as f:
                config = json.load(f)
        with open(theme_path) as f:
            theme = json.load(f)
        defaults = config.setdefault("setting_defaults", {})
        themes = [t for t in defaults.get("custom_themes", [])
                  if not str(t.get("name", "")).startswith("Jenerated ")]
        defaults["custom_themes"] = themes + [theme]
        replace_text(config_path, json.dumps(config, indent=4) + "\n")
        return True
    except (OSError, ValueError, AttributeError) as error:
        sys.stderr.write(f"{type(error).__name__}: {error}\n")
        return False


def install(theme):
    theme_file = paths.app_themes(f"element-theme/{theme.slug}/jenerated-{theme.slug}.json")

    dirs = element_config_dirs()

    step("Adding the theme to Element's settings")
    for folder in dirs:
        config = folder / "config.json"
        make_folders(folder)
        if config.is_file():
            backup_once(config)
        if not add_element_theme(config, theme_file):
            stop(f"couldn't update {config} (is it valid JSON?)")
        say(f"Updated {config}")

    step("Done! To turn the theme on:")
    say("1. Restart Element (it reads its settings when it starts).")
    say(f'2. Open Settings -> Appearance, and choose "Jenerated {theme.name}".')
    say("The theme is copied into Element's settings, so after changing the")
    say(f"palette, run {state.COMMAND} again and restart Element.")
    say("This works in Element Desktop; the web version at app.element.io can't")
    say("read your settings folder.")


APP = App(
    id="element",
    label="Element (Matrix chat)",
    category="communication",
    templates=(
        ("app-themes/element-theme/theme.json.tmpl",
         "app-themes/element-theme/{slug}/jenerated-{slug}.json"),
    ),
    words=("matrix", "riot", "chat", "messaging"),
    commands=("element-desktop",),
    flatpaks=("im.riot.Riot",),
    mac_apps=("Element",),
    install=install,
)
