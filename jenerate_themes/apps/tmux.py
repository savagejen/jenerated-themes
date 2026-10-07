"""tmux."""

import re
import shutil

from .. import paths, state
from ..install import install_link, load_colors_from
from ..system import HOME, folder_from_env, make_folders, status_of, succeeds
from ..ui import ask_yes, say, step
from . import App


def install(theme):
    folder = paths.app_themes(f"tmux-theme/{theme.slug}")
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    colors = config / "tmux/jenerated-colors.conf"

    step("Installing the tmux colors")
    make_folders(colors.parent)
    install_link(colors, folder / f"jenerated-{theme.slug}.conf")

    # tmux reads ~/.tmux.conf if there is one, and otherwise its file in the
    # config folder (tmux 3.1 and later). Use whichever it reads, or start a
    # ~/.tmux.conf, which every version reads.
    if (HOME / ".tmux.conf").is_file():
        conf = HOME / ".tmux.conf"
    elif (config / "tmux/tmux.conf").is_file():
        conf = config / "tmux/tmux.conf"
    else:
        conf = HOME / ".tmux.conf"
    # tmux expands ~ in an unquoted path; -q skips the file if it's gone.
    if colors.is_relative_to(HOME) and not re.search(r"\s", str(colors.relative_to(HOME))):
        path = f"~/{colors.relative_to(HOME)}"
    else:
        path = f'"{colors}"'
    line = f"source-file -q {path}"

    load_colors_from(conf, line, "# tmux settings. The line below loads the Jenerated colors.")

    # A running tmux only reads its settings when it starts, unless told to.
    if (shutil.which("tmux") and succeeds(["tmux", "list-sessions"])
            and ask_yes("tmux is running. Load the colors into it now?")):
        if status_of(["tmux", "source-file", colors]) == 0:
            step(f"Done! tmux uses Jenerated {theme.name} now.")
    else:
        step(f"Done! tmux will use Jenerated {theme.name} the next time it starts.")
        say(f"To load it into a running tmux: tmux source-file {path}")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and load it again.")


APP = App(
    id="tmux",
    label="tmux",
    category="terminal",
    templates=(
        ("app-themes/tmux-theme/colors.conf.tmpl",
         "app-themes/tmux-theme/{slug}/jenerated-{slug}.conf"),
    ),
    commands=("tmux",),
    one_palette=True,
    install=install,
)
