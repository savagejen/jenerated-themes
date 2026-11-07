"""zsh (syntax highlighting and suggestions)."""

import shutil
import subprocess

from .. import paths, state
from ..install import install_link
from ..system import (HOME, append_lines, folder_from_env, has_line, make_folders, output_of,
                      write_text)
from ..ui import ask_yes, say, step
from . import App


def install(theme):
    folder = paths.app_themes(f"zsh-theme/{theme.slug}")
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    zshrc = folder_from_env("ZDOTDIR", HOME) / ".zshrc"
    line = ('[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh" ] && '
            'source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh"')
    fast = False

    step("Installing the zsh colors")
    make_folders(config / "zsh", config / "fsh")
    install_link(config / "zsh/jenerated-colors.zsh", folder / f"jenerated-{theme.slug}.zsh")
    install_link(config / "fsh/jenerated-colors.ini", folder / f"jenerated-{theme.slug}.ini")

    # zsh-syntax-highlighting and zsh-autosuggestions read the colors from the
    # file ~/.zshrc loads (before or after the plugins; either works).
    if not zshrc.exists():
        write_text(zshrc, f"# zsh settings. The line below loads the Jenerated colors.\n{line}\n")
        say(f"Created {zshrc}")
    elif has_line(zshrc, line):
        pass
    elif ask_yes(f"Load the colors at the end of {zshrc}? (Your settings in it are kept.)"):
        append_lines(zshrc, "# Colors from Jenerated Themes", line)
        say(f"Added the colors to {zshrc}")
    else:
        say(f"Left {zshrc} alone; add this line to the end of it to use the colors:")
        say(f"    {line}")

    # fast-syntax-highlighting keeps its own copy of a theme, made by its
    # fast-theme command, which only exists once ~/.zshrc has loaded the
    # plugin.
    if shutil.which("zsh"):
        result = output_of(["zsh", "-ic", "if (( $+functions[fast-theme] )); then fast-theme -q "
                            "XDG:jenerated-colors && print JENERATED-FAST-THEME-DONE; fi"],
                           stdin=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result and "JENERATED-FAST-THEME-DONE" in result:
            say(f"Switched fast-syntax-highlighting to Jenerated {theme.name}.")
            fast = True

    step(f"Done! Open a new terminal to see Jenerated {theme.name} in zsh.")
    if not fast:
        say("If you use fast-syntax-highlighting, switch it to the theme with:")
        say("    fast-theme XDG:jenerated-colors")
    say(f"After changing the palette, run {state.COMMAND} again: fast-syntax-highlighting")
    say("keeps its own copy of the theme.")


APP = App(
    id="zsh",
    label="zsh (syntax highlighting and suggestions)",
    category="terminal",
    templates=(
        ("app-themes/zsh-theme/colors.zsh.tmpl",
         "app-themes/zsh-theme/{slug}/jenerated-{slug}.zsh"),
        ("app-themes/zsh-theme/fast-theme.ini.tmpl",
         "app-themes/zsh-theme/{slug}/jenerated-{slug}.ini"),
    ),
    covers="zsh-syntax-highlighting, fast-syntax-highlighting, zsh-autosuggestions",
    commands=("zsh",),
    one_palette=True,
    install=install,
)
