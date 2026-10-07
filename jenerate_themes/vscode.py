"""The VS Code extension's package.json, which lists each generated theme."""

import json

from .errors import JenerateError
from .paths import ROOT
from .render import read_template
from .paths import VSCODE_THEME

# package.json is rebuilt from this base after every run, listing each VS Code
# theme file that exists.
VSCODE_PACKAGE_BASE = ROOT / "app-themes/vs-code-theme/package.json.tmpl"

VSCODE_PACKAGE = ROOT / "app-themes/vs-code-theme/package.json"

# A theme file's "type" -> the "uiTheme" VS Code expects in package.json.
VSCODE_UI_THEMES = {
    "dark": "vs-dark",
    "light": "vs",
    "hcDark": "hc-black",
    "hcLight": "hc-light",
}


def read_vscode_theme(path):
    """Return a generated VS Code theme's name and type, or raise
    JenerateError if the file is broken."""
    try:
        theme = json.loads(path.read_text())
        name, kind = theme["name"], theme.get("type", "dark")
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        raise JenerateError(f"{path.relative_to(ROOT)}: not a valid theme file ({error}). "
                 f"Regenerate it with ./jenerate.py, or delete it.")
    return name, kind


def write_vscode_package(slugs=None):
    """Rebuild package.json with one entry per VS Code theme file on disk, or
    only for the palettes in `slugs` (for the committed default).

    Each theme's label in the picker is the `name` inside its theme file.
    """
    package = json.loads(read_template(VSCODE_PACKAGE_BASE))
    if slugs is None:
        paths = sorted(ROOT.glob(VSCODE_THEME.format(slug="*")))
    else:
        paths = [ROOT / VSCODE_THEME.format(slug=slug) for slug in slugs]
    themes = []
    for path in paths:
        name, kind = read_vscode_theme(path)
        themes.append({
            "label": name,
            "uiTheme": VSCODE_UI_THEMES.get(kind, "vs-dark"),
            "path": f"./{path.relative_to(VSCODE_PACKAGE.parent).as_posix()}",
        })
    package["contributes"]["themes"] = themes

    content = json.dumps(package, indent=2) + "\n"
    if not VSCODE_PACKAGE.exists() or VSCODE_PACKAGE.read_text() != content:
        VSCODE_PACKAGE.write_text(content)
        print(f"Updated {VSCODE_PACKAGE.relative_to(ROOT)}")
