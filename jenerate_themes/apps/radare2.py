"""radare2 (reverse engineering)."""

import re

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import (HOME, append_lines, folder_from_env, has_line, has_match, make_folders,
                      read_text, replace_text)
from ..ui import ask_yes, say, step
from . import App


def install_r2_theme(theme, tool):
    """Links the theme into radare2's or rizin's themes folder (both keep them
    in ~/.local/share/<tool>/cons, and load one with "eco <name>"), then offers
    to load it, with 24-bit color, every time the tool starts, from its startup
    file. Switching palettes replaces the earlier Jenerated theme's line."""
    name = f"jenerated-{theme.slug}"
    themes = HOME / f".local/share/{tool}/cons"
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    if tool == "radare2":
        rc = HOME / ".radare2rc"
        if not rc.is_file() and (config / "radare2/radare2rc").is_file():
            rc = config / "radare2/radare2rc"
    else:
        rc = HOME / ".rizinrc"
        if not rc.is_file():
            rc = config / "rizin/rizinrc"
    line = f"eco {name}"
    color_line = "e scr.color=3"

    plan_link(themes / name, paths.app_themes(f"{tool}-theme/{name}"))
    run_install_plan(f"the {tool} theme")

    if rc.is_file() and has_line(rc, line):
        pass
    elif rc.is_file() and has_match(rc, r"^eco jenerated-"):
        # Another palette's theme: switch the line to this one.
        replace_text(rc, re.sub(r"^eco jenerated-.*$", line, read_text(rc), flags=re.M))
        say(f"Switched {rc} to {name}")
    elif ask_yes(f"Load the theme every time {tool} starts? (Adds two lines to {rc}.)"):
        make_folders(rc.parent)
        lines = ["# Colors from Jenerated Themes", line]
        if not has_line(rc, color_line):
            lines = ["# 24-bit color, for the Jenerated theme's exact colors", color_line, *lines]
        append_lines(rc, *lines)
        say(f"Added the theme to {rc}")
    else:
        say(f"Left {rc} alone. To load the theme, run these in {tool} (or add them to {rc}):")
        say(f"    {color_line}")
        say(f"    {line}")

    step(f"Done! {tool} uses Jenerated {theme.name} the next time it starts.")
    say(f"To try it in a running {tool}: {color_line}; {line}")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and start {tool} again.")


def install(theme):
    install_r2_theme(theme, "radare2")


APP = App(
    id="radare2",
    label="radare2 (reverse engineering)",
    category="hacking",
    templates=(
        ("app-themes/radare2-theme/theme.r2.tmpl", "app-themes/radare2-theme/jenerated-{slug}"),
    ),
    covers="Iaito",
    words=("r2", "disassembler", "debugger", "reverse", "engineering"),
    commands=("r2", "radare2"),
    one_palette=True,
    install=install,
)
