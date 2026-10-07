"""Templates: filling in a palette's values, and generating, removing and
listing each palette's themes."""

import re
from pathlib import Path

from .colors import HEX, blend
from .errors import JenerateError
from .palettes import (SCHEME_FOLDERS, SCHEMES, check_slug, is_path, load_palette,
                       palette_files, palette_path, palette_scheme, read_palette_file)
from .paths import ROOT
from .targets import TARGETS

# {{name}}, or {{scheme: "text for dark" | "text for light"}}.
PLACEHOLDER = re.compile(
    r'\{\{\s*(?:([A-Za-z0-9_]+)|scheme\s*:\s*"([^"]*)"\s*\|\s*"([^"]*)")\s*\}\}')

# {{green_over_bg_20}}: one color laid over another at a percentage, as
# #rrggbb, for apps that can't take a color with transparency.
BLEND = re.compile(r"([a-z0-9_]+?)_over_([a-z0-9_]+?)_(100|[1-9]?[0-9])")


def read_template(path):
    """Read a template, or raise JenerateError naming it if it's missing."""
    try:
        return path.read_text()
    except FileNotFoundError:
        raise JenerateError(f"{path.relative_to(ROOT)}: template not found. Restore it "
                 f"(git checkout -- {path.relative_to(ROOT)}), or remove it "
                 f"from its app's templates in jenerate_themes/apps/.")


def render(template_path, values):
    """Fill in a template's placeholders, or raise JenerateError naming any
    missing ones."""
    text = read_template(template_path)
    missing = set()

    def substitute(match):
        key, for_dark, for_light = match.groups()
        if key is None:
            return for_dark if values["scheme"] == "dark" else for_light
        if key not in values:
            blended = BLEND.fullmatch(key)
            colors = blended.groups()[:2] if blended else ()
            if blended and all(HEX.fullmatch(values.get(name, "")) for name in colors):
                top, bottom, percent = blended.groups()
                return blend(values[top], values[bottom], int(percent))
            missing.add(key)
            return match.group(0)
        return values[key]

    result = PLACEHOLDER.sub(substitute, text)
    if missing:
        raise JenerateError(f"{template_path.relative_to(ROOT)}: the palette has no "
                 f"color named {', '.join(sorted(missing))}")
    return result


def template_path(template, values):
    """A template's file, with {scheme} in its path filled in."""
    return ROOT / template.format(scheme=values["scheme"])


def output_path(output, slug):
    return ROOT / output.format(slug=slug)


def slug_folders(slug):
    """The folders made just for this palette's files, like
    app-themes/obsidian-theme/sunset, deepest first (so each is empty by the
    time its parent is removed)."""
    folders = set()
    for _, output in TARGETS:
        folder = Path(output).parent
        while "{slug}" in str(folder):
            folders.add(ROOT / str(folder).format(slug=slug))
            folder = folder.parent
    return sorted(folders, key=lambda f: len(f.parts), reverse=True)


def add(names):
    """Generate every app's theme for each palette."""
    for name in names:
        values = load_palette(palette_path(name))
        # Render everything before writing anything, so a bad template
        # leaves no half-generated palette behind.
        rendered = [(output_path(output, values["slug"]),
                     render(template_path(template, values), values))
                    for template, output in TARGETS]
        for path, content in rendered:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        print(f"Generated {values['name']} ({values['slug']})")


def remove(names):
    """Delete each palette's generated themes (the palette itself is kept)."""
    for name in names:
        if is_path(name):
            slug = read_palette_file(palette_path(name))["slug"]
        else:
            slug = check_slug(name, "palette")
        existing = [path for path in
                    (output_path(output, slug) for _, output in TARGETS)
                    if path.exists()]
        if not existing:
            print(f"{slug}: nothing to remove")
        for path in existing:
            path.unlink()
            print(f"Removed {path.relative_to(ROOT)}")
        for folder in slug_folders(slug):
            if folder.is_dir() and not any(folder.iterdir()):
                folder.rmdir()


def list_palettes():
    """Print the palettes, dark then light, starring those already
    generated. Each palette is listed by its scheme, wherever it's filed."""
    groups = {scheme: [] for scheme in SCHEMES}
    for path in palette_files():
        data = read_palette_file(path)
        generated = any(output_path(output, data["slug"]).exists()
                        for _, output in TARGETS)
        mark = "*" if generated else " "
        groups[palette_scheme(path)].append(f"{mark} {data['slug']:<24} {data['name']}")
    for scheme, lines in groups.items():
        if lines:
            print(f"{SCHEME_FOLDERS[scheme]} palettes:")
            print("\n".join(lines))
            print()
    print("* = generated")
