"""Gemini CLI."""

import json

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, make_folders, replace_text
from ..ui import ask_yes, say, step
from . import App


def set_gemini_theme(path, theme):
    """Sets ui.theme in Gemini CLI's settings.json, keeping the rest. Returns
    False if the file isn't JSON it can change."""
    try:
        settings = {}
        if path.exists():
            with open(path) as f:
                settings = json.load(f)
        if not isinstance(settings, dict) or not isinstance(settings.setdefault("ui", {}), dict):
            return False
        settings["ui"]["theme"] = theme
        make_folders(path.parent)
        replace_text(path, json.dumps(settings, indent=2) + "\n")
        return True
    except (OSError, ValueError):
        return False


def install(theme):
    """Gemini CLI loads a theme from a JSON file named in ui.theme in its
    settings.json, and only from inside your home folder, so the theme is
    linked into ~/.gemini/themes and ui.theme is pointed at the link."""
    file = f"jenerated-{theme.slug}.json"
    theme_file = HOME / f".gemini/themes/{file}"
    settings = HOME / ".gemini/settings.json"

    plan_link(theme_file, paths.app_themes(f"gemini-theme/{file}"))
    run_install_plan("the Gemini CLI theme")

    if ask_yes(f"Use it in Gemini CLI? (Sets ui.theme in {settings}; your other settings "
               "are kept.)"):
        if set_gemini_theme(settings, str(theme_file)):
            step(f"Done! Gemini CLI uses Jenerated {theme.name} the next time it starts.")
            say("(With ui.theme set, /theme can't switch themes; remove it to choose")
            say("with /theme again.)")
            say(f"After changing the palette, run {state.regenerate(theme.slug)} and start "
                "Gemini CLI again.")
            return
        say(f"Couldn't read {settings} as JSON (does it have comments?), so it's unchanged.")
    step(f"To use the theme, set this in {settings}:")
    say(f'    "ui": {{ "theme": "{theme_file}" }}')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and start "
        "Gemini CLI again.")


APP = App(
    id="gemini",
    label="Gemini CLI",
    category="terminal",
    templates=(
        ("app-themes/gemini-theme/theme.json.tmpl",
         "app-themes/gemini-theme/jenerated-{slug}.json"),
    ),
    words=("ai", "assistant", "agent", "llm"),
    commands=("gemini",),
    one_palette=True,
    install=install,
)
