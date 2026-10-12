"""Templates: filling in a palette's values, and generating, removing and
listing each palette's themes. Templates are read from paths.SOURCE, and
themes written under paths.DATA."""

import re
import shutil
from pathlib import Path

from .colors import HEX, blend
from .errors import JenerateError
from . import paths
from .palettes import (SCHEME_FOLDERS, SCHEMES, check_slug, is_path, load_palette,
                       palette_files, palette_path, palette_scheme, read_palette_file)
from .targets import TARGETS

# The palette whose themes an installed copy comes with, pre-made.
BLUE_PURPLE = "blue-purple"

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
        if paths.INSTALLED:
            raise JenerateError(f"{path}: template not found. Reinstall jenerate-themes "
                                "to restore it.")
        shown = path.relative_to(paths.SOURCE)
        raise JenerateError(f"{shown}: template not found. Restore it "
                 f"(git checkout -- {shown}), or remove it "
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
        raise JenerateError(f"{paths.shown(template_path)}: the palette has no "
                 f"color named {', '.join(sorted(missing))}")
    return result


def template_path(template, values):
    """A template's file, with {scheme} in its path filled in."""
    return paths.SOURCE / template.format(scheme=values["scheme"])


def output_path(output, slug, root=None):
    """Where a palette's generated file goes: under paths.DATA, or under
    root (paths.SOURCE, for the pre-made Blue Purple an installed copy
    comes with)."""
    return (root or paths.DATA) / output.format(slug=slug)


def slug_folders(slug):
    """The folders made just for this palette's files, like
    app-themes/obsidian-theme/sunset, deepest first (so each is empty by the
    time its parent is removed)."""
    folders = set()
    for _, output in TARGETS:
        folder = Path(output).parent
        while "{slug}" in str(folder):
            folders.add(paths.DATA / str(folder).format(slug=slug))
            folder = folder.parent
    return sorted(folders, key=lambda f: len(f.parts), reverse=True)


def is_bundled_blue_purple(path):
    """Whether a palette file is the Blue Purple an installed copy comes with
    (not a palette of your own with its slug)."""
    return (paths.INSTALLED and path.resolve().parent.parent == paths.BUNDLED_PALETTES.resolve()
            and path.name == f"{BLUE_PURPLE}-palette.toml")


def copy_blue_purple():
    """Copies the pre-made Blue Purple themes an installed copy comes with
    into the data folder, where they're missing or different (as after an
    upgrade). Returns True if any file changed."""
    changed = False
    for _, output in TARGETS:
        source, target = output_path(output, BLUE_PURPLE, paths.SOURCE), \
            output_path(output, BLUE_PURPLE)
        if target.is_file() and target.read_bytes() == source.read_bytes():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        changed = True
    return changed


def refresh_blue_purple():
    """In an installed copy where Blue Purple was set up before, and not
    replaced by a palette of your own, brings its themes up to date with the
    ones this version comes with. Returns True if any file changed."""
    if not paths.INSTALLED:
        return False
    if not any(output_path(output, BLUE_PURPLE).exists() for _, output in TARGETS):
        return False
    try:
        if not is_bundled_blue_purple(palette_path(BLUE_PURPLE)):
            return False
    except JenerateError:
        return False
    return copy_blue_purple()


def add(names):
    """Generate every app's theme for each palette. An installed copy's own
    Blue Purple comes pre-made: its themes are copied, not generated."""
    for name in names:
        path = palette_path(name)
        if is_bundled_blue_purple(path):
            copy_blue_purple()
            data = read_palette_file(path)
            print(f"Generated {data['name']} ({data['slug']})")
            continue
        values = load_palette(path)
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
            print(f"Removed {paths.shown(path)}")
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
