"""Where the project's files are: the templates and palettes it reads, and the
themes and palettes it writes. The one place that knows where data lives.

It runs in one of two layouts:

- A clone of the repository: everything is in the repository. Templates and
  palettes are read from it, and themes are generated next to the
  templates. SOURCE and DATA are both the repository.
- An installed copy (pipx, a .deb, .rpm or Arch package): the templates,
  the bundled palettes and Blue Purple's pre-made themes are read-only
  package data (SOURCE), and generated themes, your own palettes and the
  Palette Creator's draft go in a folder of your own (DATA), laid out like
  the repository.

Code reads templates and bundled palettes from SOURCE, and writes only under
DATA.
"""

import os
from pathlib import Path

from .system import HOME, OS, folder_from_env

# The jenerate_themes package itself.
PACKAGE = Path(__file__).resolve().parent

# A clone has app-themes/ and palettes/ next to the package; an installed
# copy has them in the package's data/ folder.
_clone = PACKAGE.parent
INSTALLED = not ((_clone / "app-themes").is_dir() and (_clone / "palettes").is_dir())


def data_folder():
    """An installed copy's folder for what it writes: in XDG_DATA_HOME (or
    ~/.local/share) on Linux, in Application Support on macOS. None without
    a home folder to put it in."""
    if OS == "Darwin":
        base = HOME / "Library/Application Support" if HOME else None
    elif os.environ.get("XDG_DATA_HOME"):
        base = folder_from_env("XDG_DATA_HOME", "")
    else:
        base = HOME / ".local/share" if HOME else None
    return base / "jenerate-themes" if base else None


# Where templates, bundled palettes and Blue Purple's pre-made themes are read
# from. Read-only when installed.
SOURCE = PACKAGE / "data" if INSTALLED else _clone

# Where generated themes, your palettes and drafts are written. In a clone,
# the repository; installed, data_folder() (None without a home folder,
# which cli stops at).
DATA = data_folder() if INSTALLED else _clone

# The data folder as you named it when you ran the command (like `pwd`
# names it, keeping the links in its path), set by cli for a clone.
# Installed links and copies point here, so they show the path you know.
# Until it's set, DATA.
LINK_ROOT = DATA

# Your palettes (in a clone, the repository's), and the ones that come with
# an installed copy. In a clone they're the same folder.
PALETTES = DATA / "palettes" if DATA else None
BUNDLED_PALETTES = SOURCE / "palettes"

# Generated VS Code theme files, relative to the data folder. The
# extension's package.json lists them (see vscode.py).
VSCODE_THEME = "app-themes/vs-code-theme/themes/jenerated-{slug}-color-theme.json"


def app_themes(*parts):
    """A file or folder in app-themes/, where the generated themes are, by
    way of LINK_ROOT: the path installed links point to."""
    return LINK_ROOT.joinpath("app-themes", *parts)

# Where the Palette Creator keeps your work-in-progress palette (in a clone,
# git ignores it, so your drafts stay yours).
DRAFTS = DATA / "palette-creator" if DATA else None


def shown(path):
    """How messages show a path: relative to the repository in a clone (like
    app-themes/tilix-theme/sunset.json), otherwise in full, with ~ for the
    home folder."""
    path = Path(path)
    if not INSTALLED:
        for root in (LINK_ROOT, DATA):
            try:
                return str(path.relative_to(root))
            except ValueError:
                pass
    return in_full(path)


def in_full(path):
    """A path in full, with ~ for the home folder."""
    path = Path(path)
    if HOME:
        try:
            return f"~/{path.relative_to(HOME)}"
        except ValueError:
            pass
    return str(path)


def copy_of(path):
    """The jenerate copy (a clone, or an installed copy's data folder) a
    path is in, from the app-themes/ in it, or None. For telling an install
    from another copy apart from one from this copy."""
    text = str(path)
    if "/app-themes/" in text:
        return Path(text.split("/app-themes/")[0])
    return None
