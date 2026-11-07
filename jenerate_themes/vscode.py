"""The VS Code extension's package.json, which lists each generated theme."""

import json

from . import paths, state
from .errors import JenerateError
from .paths import VSCODE_THEME
from .render import read_template

# package.json is rebuilt from this base (read from paths.SOURCE) after every
# run, listing each VS Code theme file that exists (under paths.DATA).
VSCODE_PACKAGE_BASE = "app-themes/vs-code-theme/package.json.tmpl"

VSCODE_PACKAGE = "app-themes/vs-code-theme/package.json"

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
        raise JenerateError(f"{paths.shown(path)}: not a valid theme file ({error}). "
                 f"Regenerate it with {state.generate()}, or delete it.")
    return name, kind


def write_vscode_package(slugs=None):
    """Rebuild package.json with one entry per VS Code theme file on disk, or
    only for the palettes in `slugs` (for the committed default).

    Each theme's label in the picker is the `name` inside its theme file.
    """
    package = json.loads(read_template(paths.SOURCE / VSCODE_PACKAGE_BASE))
    target = paths.DATA / VSCODE_PACKAGE
    if slugs is None:
        files = sorted(paths.DATA.glob(VSCODE_THEME.format(slug="*")))
    else:
        files = [paths.DATA / VSCODE_THEME.format(slug=slug) for slug in slugs]
    themes = []
    for path in files:
        name, kind = read_vscode_theme(path)
        themes.append({
            "label": name,
            "uiTheme": VSCODE_UI_THEMES.get(kind, "vs-dark"),
            "path": f"./{path.relative_to(target.parent).as_posix()}",
        })
    package["contributes"]["themes"] = themes

    content = json.dumps(package, indent=2) + "\n"
    if not target.exists() or target.read_text() != content:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        print(f"Updated {paths.shown(target)}")
