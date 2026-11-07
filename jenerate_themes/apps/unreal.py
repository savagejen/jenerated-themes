"""Unreal Engine."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS
from ..ui import say, step
from . import App


def unreal_themes_dir():
    """Unreal Engine's folder for your own editor themes. It's the same for
    every engine version, and Unreal doesn't follow XDG_CONFIG_HOME."""
    if OS == "Darwin":
        return HOME / "Library/Application Support/Epic/UnrealEngine/Slate/Themes"
    return HOME / ".config/Epic/UnrealEngine/Slate/Themes"


def install(theme):
    file = f"jenerated-{theme.slug}.json"

    plan_link(unreal_themes_dir() / file, paths.app_themes(f"unreal-theme/{file}"))
    run_install_plan("the Unreal Engine editor theme")

    step("Done! To turn the theme on, in the Unreal Editor:")
    say("1. Open Edit -> Editor Preferences -> General -> Appearance.")
    say(f'2. Under Theme, choose "Jenerated {theme.name}" as the Active Theme. (Restart')
    say("   the editor first if it doesn't appear.)")
    say("To tweak the colors in Unreal, choose Duplicate and edit the copy, so")
    say(f"your changes aren't overwritten the next time you run {state.generate()}.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart the")
    say("editor.")


APP = App(
    id="unreal",
    label="Unreal Engine",
    category="editors",
    templates=(
        ("app-themes/unreal-theme/theme.json.tmpl",
         "app-themes/unreal-theme/jenerated-{slug}.json"),
    ),
    words=("ue5", "unreal", "editor", "game", "engine", "epic"),
    commands=("UnrealEditor", "UE4Editor"),
    mac_apps=("Epic Games Launcher",),
    install=install,
)
