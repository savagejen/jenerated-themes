"""Where the project's files are: the repository, its palettes and its app
themes. The one place that knows where data lives."""

from pathlib import Path

# The repository: the folder this package is in, with any links in its path
# followed. Files are read through it, and paths compared against it.
ROOT = Path(__file__).resolve().parent.parent

# The same folder as you named it when you ran the command (like `pwd`
# names it, keeping the links in its path), set by cli. Installed links and
# copies point here, so they show the path you know. Until it's set, ROOT.
LINK_ROOT = ROOT

PALETTES = ROOT / "palettes"

# Generated VS Code theme files, relative to the repository root. The
# extension's package.json lists them (see vscode.py).
VSCODE_THEME = "app-themes/vs-code-theme/themes/jenerated-{slug}-color-theme.json"


def app_themes(*parts):
    """A file or folder in app-themes/, where the generated themes are, by
    way of LINK_ROOT: the path installed links point to."""
    return LINK_ROOT.joinpath("app-themes", *parts)

# Where the Palette Creator keeps your work-in-progress palette (git ignores
# it, so your drafts stay yours).
DRAFTS = ROOT / "palette-creator"
