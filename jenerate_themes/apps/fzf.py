"""fzf (fuzzy finder)."""

import os
import shutil
from pathlib import Path

from .. import paths, state
from ..install import install_link
from ..system import HOME, append_lines, folder_from_env, has_line, make_folders
from ..ui import ask_yes, say, step
from . import App


def install(theme):
    """fzf reads its colors from FZF_DEFAULT_OPTS, so the theme is a small file
    the shell loads at startup: linked to one place, so switching palettes
    just repoints the link."""
    folder = paths.app_themes(f"fzf-theme/{theme.slug}")
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    colors = config / "fzf/jenerated-colors.sh"
    line = ('[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh" ] && '
            '. "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh"')
    loaded = False

    step("Installing the fzf colors")
    make_folders(config / "fzf")
    install_link(colors, folder / f"jenerated-{theme.slug}.sh")

    # bash and zsh load it from their startup file: each one that exists, and
    # your own shell's even if it doesn't exist yet.
    shell = Path(os.environ.get("SHELL", "")).name
    rcs = [HOME / f".{rc}rc" for rc in ("bash", "zsh")
           if (HOME / f".{rc}rc").is_file() or shell == rc]
    for rc in rcs:
        if has_line(rc, line):
            loaded = True
        elif ask_yes(f"Load the colors in {rc.name}? (Adds one line at the end.)"):
            append_lines(rc, "# fzf colors from Jenerated Themes", line)
            say(f"Added the colors to {rc}")
            loaded = True

    # fish loads everything in conf.d by itself.
    if shutil.which("fish") or (config / "fish").is_dir():
        make_folders(config / "fish/conf.d")
        install_link(config / "fish/conf.d/jenerated-fzf.fish",
                     folder / f"jenerated-{theme.slug}.fish")
        loaded = True

    if loaded:
        step(f"Done! Open a new terminal to use fzf in Jenerated {theme.name}.")
    else:
        step("Done! To use the colors, add this line to your shell's startup file:")
        say(f"    {line}")
    say("Your own FZF_DEFAULT_OPTS are kept; the colors are added after them.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and open a new")
    say("terminal.")


APP = App(
    id="fzf",
    label="fzf (fuzzy finder)",
    category="terminal",
    templates=(
        ("app-themes/fzf-theme/fzf.sh.tmpl", "app-themes/fzf-theme/{slug}/jenerated-{slug}.sh"),
        ("app-themes/fzf-theme/fzf.fish.tmpl",
         "app-themes/fzf-theme/{slug}/jenerated-{slug}.fish"),
    ),
    commands=("fzf",),
    one_palette=True,
    install=install,
)
