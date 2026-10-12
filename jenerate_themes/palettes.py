"""Palettes: finding them, reading and checking them, and turning them into
the values templates use."""

import re
import tomllib
import uuid
from pathlib import Path

from . import paths, state
from .colors import HEX, color_formats, contrast, scheme_of
from .errors import JenerateError

# Palettes are filed by scheme, in palettes/Dark and palettes/Light.
SCHEME_FOLDERS = {"dark": "Dark", "light": "Light"}

SCHEMES = ("dark", "light")

# Slugs become file names, so they're kept to lowercase words and dashes.
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")

# Each palette's {{uuid}} is made from its slug in this namespace.
UUID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "https://github.com/savagejen/jenerated-themes")


def is_path(arg):
    """Whether a command-line palette is a file path rather than a slug."""
    return arg.endswith(".toml") or "/" in arg


def check_slug(slug, source):
    """The slug, or JenerateError if it isn't safe to use in a file name."""
    if not SLUG.fullmatch(slug):
        raise JenerateError(f"{source}: {slug!r} is not a valid slug (use lowercase "
                 f"letters, numbers and single dashes, e.g. blue-purple)")
    return slug


def palette_folder(scheme, root=None):
    """Where palettes of a scheme ("dark" or "light") are filed: among your
    palettes (paths.PALETTES), or under root."""
    return (root or paths.PALETTES) / SCHEME_FOLDERS[scheme]


def own_palette_folders():
    """The folders your palettes are found in: palettes/Dark,
    palettes/Light, and palettes/ itself, for a palette not filed yet. In a
    clone, these are the repository's palettes."""
    return [palette_folder(scheme) for scheme in SCHEMES] + [paths.PALETTES]


def bundled_palette_folders():
    """The folders of the palettes an installed copy comes with (none in a
    clone, where they're the repository's own)."""
    if not paths.INSTALLED:
        return []
    return [palette_folder(scheme, paths.BUNDLED_PALETTES) for scheme in SCHEMES]


def palette_folders():
    """Every folder palettes are found in, yours first."""
    return own_palette_folders() + bundled_palette_folders()


def in_palettes(path):
    """Whether a file is in one of the palette folders."""
    return path.resolve().parent in [folder.resolve() for folder in palette_folders()]


def palette_files():
    """Every palette file in the palette folders, in order of file name. A
    palette of yours replaces a bundled one with the same file name."""
    found = {}
    for folder in palette_folders():
        for path in folder.glob("*-palette.toml"):
            found.setdefault(path.name, []).append(path)
    # Yours come first, so a bundled palette is only listed when you have
    # none by its name. Two of yours with one name are both listed, for
    # palette_path to stop at.
    bundled = [folder.resolve() for folder in bundled_palette_folders()]
    listed = []
    for name, found_paths in found.items():
        own = [path for path in found_paths if path.parent.resolve() not in bundled]
        listed += own or found_paths[:1]
    return sorted(listed, key=lambda path: path.name)


def palette_path(arg):
    """Turn a slug or a path into the palette file's path."""
    if is_path(arg):
        path = Path(arg)
        if not path.is_file():
            raise JenerateError(f"No palette file at {path}.")
        return path
    name = f"{check_slug(arg, 'palette')}-palette.toml"
    found = [folder / name for folder in own_palette_folders() if (folder / name).is_file()]
    if len(found) > 1:
        raise JenerateError(f"The palette {arg!r} is in more than one place: "
                 f"{', '.join(paths.shown(p) for p in found)}. "
                 f"Keep one of them.")
    # Yours, or else the bundled one.
    found = found or [folder / name for folder in bundled_palette_folders()
                      if (folder / name).is_file()]
    if not found:
        raise JenerateError(f"No palette named {arg!r} (looked for {name} in palettes/Dark, "
                 f"palettes/Light and palettes/). Run {state.list_palettes()} to see "
                 f"the available palettes.")
    return found[0]


def palette_scheme(path):
    """A palette's scheme, for listing it: as load_palette works it out, or,
    for a palette with a color problem that load_palette would stop at, from
    the folder it's filed in (dark if it isn't filed yet). A palette that
    can't be read at all still stops, naming the problem."""
    data = read_palette_file(path)
    if data.get("scheme"):
        return data["scheme"]
    colors, value, seen = data["colors"], data["colors"].get("bg"), set()
    while value in colors and value not in seen:
        seen.add(value)
        value = colors[value]
    if isinstance(value, str) and HEX.fullmatch(value):
        return scheme_of(value)
    folder = {palette_folder(scheme, root).resolve(): scheme for scheme in SCHEMES
              for root in (paths.PALETTES, paths.BUNDLED_PALETTES)}
    return folder.get(path.resolve().parent, "dark")


def filed_path(values):
    """Where a palette belongs: its scheme's folder, named after its slug."""
    return palette_folder(values["scheme"]) / f"{values['slug']}-palette.toml"


def read_palette_file(path):
    """Parse a palette file and check its `name`, `slug` and `colors`."""
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as error:
        raise JenerateError(f"{path}: not a valid palette file: {error}")

    for key in ("name", "slug"):
        if not isinstance(data.get(key), str):
            raise JenerateError(f"{path}: missing top-level `{key}` string")
    # The name is written into the themes as is, so it mustn't be able to
    # break out of a JSON string, an XML file or an INI line. It also names
    # the Obsidian theme's folder, so no slashes.
    name = data["name"]
    if any(c in '"\\/<>&' or not c.isprintable() for c in name):
        raise JenerateError(f"{path}: `name` can't contain quotes, slashes, "
                 f"backslashes, <, >, & or line breaks")
    if not name.strip() or name != name.strip():
        raise JenerateError(f"{path}: `name` can't be empty or start or end with spaces")
    slug = check_slug(data["slug"], path)
    if in_palettes(path) and path.name != f"{slug}-palette.toml":
        raise JenerateError(f"{path}: palettes in palettes/ must be named after their "
                 f"slug; rename it to {slug}-palette.toml")

    if data.get("scheme") not in (None, *SCHEMES):
        raise JenerateError(f'{path}: `scheme` must be "dark" or "light" (or left out, '
                 f"to work it out from `bg`)")

    colors = data.setdefault("colors", {})
    if not isinstance(colors, dict):
        raise JenerateError(f"{path}: `colors` must be a [colors] table")
    for key, value in colors.items():
        if not isinstance(value, str):
            raise JenerateError(f"{path}: color `{key}` must be a quoted string, like "
                     f'"#rrggbb" or "red"')
    return data


# The contrast recommended for text: WCAG's level for ordinary text. It's a
# recommendation, not a rule; see "Text contrast" in CONTRIBUTING.md.
CONTRAST_TARGET = 4.5

# The colors people read, each with the backgrounds it's read on. Colors
# meant to recede (text_faint, guides, borders, the bright terminal colors)
# aren't here.
READ_ON = [
    (("text", "text_subtle", "text_muted", "accent", "accent_soft", "accent_light",
      "accent_pale", "red", "orange", "yellow", "green", "cyan", "magenta"),
     ("bg", "bg_line_highlight")),
    (("text_bright",), ("accent",)),
    (("text_strong",), ("bg", "bg_selected")),
]


def low_contrast(values):
    """The pairs of a palette's colors (its template values) that fall short
    of CONTRAST_TARGET, as (color, background, ratio) with the ratio rounded
    down to 2 places, so a pair shown as 4.5 really reaches it."""
    return [(key, background, int(ratio * 100) / 100)
            for keys, backgrounds in READ_ON for key in keys for background in backgrounds
            if (ratio := contrast(values[key], values[background])) < CONTRAST_TARGET]


def report_contrast(names):
    """Print, for each palette (by slug or path; every palette if none are
    named), the text colors that fall short of CONTRAST_TARGET."""
    paths = [palette_path(name) for name in names] if names else palette_files()
    for path in paths:
        values = load_palette(path)
        low = low_contrast(values)
        if not low:
            print(f"{values['name']}: all text reaches {CONTRAST_TARGET}:1")
            continue
        print(f"{values['name']}: {len(low)} below the recommended {CONTRAST_TARGET}:1")
        for key, background, ratio in low:
            print(f"  {key} on {background}: {ratio:.2f}:1")


def load_palette(path):
    """Read a palette and return its template values: every color as
    #rrggbb (with references to other colors followed) and in its other
    forms (see color_formats), plus `name`, `slug`, `uuid` and `scheme`."""
    data = read_palette_file(path)
    colors = data["colors"]

    def resolve(key, chain=()):
        value = colors[key]
        chain += (key,)
        if HEX.fullmatch(value):
            return value
        if value in chain:
            raise JenerateError(f"{path}: color `{key}` refers to itself in a loop")
        if value not in colors:
            raise JenerateError(f"{path}: color `{key}` = {value!r} is not a #rrggbb "
                     f"value or the name of another color")
        return resolve(value, chain)

    values = {}
    for key in colors:
        values.update(color_formats(key, resolve(key)))
    # A color the palette defines outright wins over another's derived form.
    values.update((key, resolve(key)) for key in colors)
    values["name"] = data["name"]
    values["slug"] = data["slug"]
    values["uuid"] = str(uuid.uuid5(UUID_NAMESPACE, data["slug"]))
    values["scheme"] = data.get("scheme") or (scheme_of(values["bg"]) if "bg" in values else "dark")
    return values
