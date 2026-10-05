#!/usr/bin/env python3
"""The Jenerator: generate app themes from the palettes you choose.

Usage:
    ./jenerate.py blue-purple                 # add one palette's themes
    ./jenerate.py blue-purple,sunset          # add several at once
    ./jenerate.py path/to/my-palette.toml     # a palette file anywhere
    ./jenerate.py --remove sunset             # remove a palette's themes
    ./jenerate.py --list                      # show palettes, mark generated
    ./jenerate.py --contrast                  # check every palette's text contrast
    ./jenerate.py --contrast sunset           # just these palettes'

A palette is named by its slug (palettes/Dark/<slug>-palette.toml or
palettes/Light/<slug>-palette.toml) or given as a path to a .toml file. A
palette straight in palettes/ works too, until the screenshot script files
it. Each run adds to, or updates, the themes already generated; nothing else
is touched. Each template's {{name}} placeholders are replaced with the
palette's colors (plus its `name` and `slug`), and the result is written
next to the template. Each color is also available as RGB and HSL numbers,
for apps whose themes need them: {{accent_rgb}} is "88, 101, 243",
{{accent_rgb_csv}} is "88,101,243", {{accent_rgb_spaced}} is "88 101 243",
{{accent_rgb16}} is "22616,25957,62451" (each channel from 0 to 65535, as
Wireshark stores colors), {{accent_float}} is "0.3451, 0.3961, 0.9529" (each
channel from 0 to 1; {{accent_float_spaced}} is the same with spaces instead
of commas), {{accent_linear_r}}, {{accent_linear_g}} and {{accent_linear_b}}
are its channels in linear light (for apps that store colors that way, such
as Unreal Engine), {{accent_h}}, {{accent_s}} and {{accent_l}} are "235",
"87" and "65", {{accent_hex}} is "5865F3" (without the #), and
{{accent_int}} is "5793267" (0xrrggbb as a decimal number, as LibreOffice
stores colors).
{{green_over_bg_20}} is one color laid over another at a percentage (0 to
100), as #rrggbb: how {{green}}33 looks over {{bg}}, for apps that can't take
a color with transparency.
{{uuid}} is an ID made from the slug, the same every time, for apps that
identify themes by UUID.

Palettes can be dark or light. {{scheme}} is "dark" or "light": the palette's
optional `scheme` setting, or else worked out from its editor background
(`bg`). {{scheme: "a" | "b"}} gives "a" for dark palettes and "b" for light
ones, and {scheme} in a template's path picks a template for each.
"""

import argparse
import colorsys
import json
import re
import sys
import tomllib
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PALETTES = ROOT / "palettes"
# Palettes are filed by scheme, in palettes/Dark and palettes/Light.
SCHEME_FOLDERS = {"dark": "Dark", "light": "Light"}

# Generated VS Code theme files, relative to the repository root.
VSCODE_THEME = "app-themes/vs-code-theme/themes/jenerated-{slug}-color-theme.json"

# (template, output) pairs, relative to the repository root. {slug} in the
# output path is replaced with the palette's slug; it may name a folder, which
# is created as needed and deleted with the palette's last file. {scheme} in
# the template path is replaced with "dark" or "light", for apps whose dark
# and light themes differ too much for one template.
TARGETS = [
    ("app-themes/vs-code-theme/themes/color-theme.json.tmpl", VSCODE_THEME),
    ("app-themes/ptyxis-theme/palette.tmpl", "app-themes/ptyxis-theme/{slug}.palette"),
    ("app-themes/slack-theme/slack-theme.txt.tmpl", "app-themes/slack-theme/{slug}.txt"),
    ("app-themes/tilix-theme/scheme.json.tmpl", "app-themes/tilix-theme/{slug}.json"),
    ("app-themes/vim-theme/colorscheme.vim.tmpl", "app-themes/vim-theme/colors/jenerated-{slug}.vim"),
    ("app-themes/obsidian-theme/theme.css.tmpl", "app-themes/obsidian-theme/{slug}/theme.css"),
    ("app-themes/obsidian-theme/manifest.json.tmpl", "app-themes/obsidian-theme/{slug}/manifest.json"),
    ("app-themes/firefox-theme/manifest.json.tmpl", "app-themes/firefox-theme/{slug}/manifest.json"),
    ("app-themes/vivaldi-theme/settings.json.tmpl", "app-themes/vivaldi-theme/{slug}/settings.json"),
    ("app-themes/jetbrains-theme/plugin.xml.tmpl", "app-themes/jetbrains-theme/{slug}/META-INF/plugin.xml"),
    ("app-themes/jetbrains-theme/theme-{scheme}.json.tmpl", "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.theme.json"),
    ("app-themes/jetbrains-theme/editor-scheme.xml.tmpl", "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.xml"),
    ("app-themes/chromium-theme/manifest.json.tmpl", "app-themes/chromium-theme/{slug}/manifest.json"),
    ("app-themes/gtk3-theme/gtk.css.tmpl", "app-themes/gtk3-theme/{slug}/gtk-3.0/gtk.css"),
    ("app-themes/kde-theme/colors.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.colors"),
    ("app-themes/kde-theme/konsole.colorscheme.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.colorscheme"),
    ("app-themes/kde-theme/syntax.theme.tmpl", "app-themes/kde-theme/{slug}/Jenerated-{slug}.theme"),
    ("app-themes/gtk3-theme/index.theme.tmpl", "app-themes/gtk3-theme/{slug}/index.theme"),
    ("app-themes/decky-theme/theme.json.tmpl", "app-themes/decky-theme/{slug}/theme.json"),
    ("app-themes/decky-theme/shared.css.tmpl", "app-themes/decky-theme/{slug}/shared.css"),
    ("app-themes/godot-theme/text-editor.tet.tmpl", "app-themes/godot-theme/{slug}/Jenerated-{slug}.tet"),
    ("app-themes/godot-theme/editor-settings.cfg.tmpl", "app-themes/godot-theme/{slug}/editor-settings.cfg"),
    ("app-themes/zen-theme/userChrome.css.tmpl", "app-themes/zen-theme/{slug}/userChrome.css"),
    ("app-themes/zen-theme/userContent.css.tmpl", "app-themes/zen-theme/{slug}/userContent.css"),
    ("app-themes/gtksourceview-theme/gtksourceview-4.xml.tmpl", "app-themes/gtksourceview-theme/{slug}/gtksourceview-4/jenerated-{slug}.xml"),
    ("app-themes/gtksourceview-theme/gtksourceview-5.xml.tmpl", "app-themes/gtksourceview-theme/{slug}/gtksourceview-5/jenerated-{slug}.xml"),
    ("app-themes/gtksourceview-theme/libgedit.xml.tmpl", "app-themes/gtksourceview-theme/{slug}/libgedit-gtksourceview-300/jenerated-{slug}.xml"),
    ("app-themes/fzf-theme/fzf.sh.tmpl", "app-themes/fzf-theme/{slug}/jenerated-{slug}.sh"),
    ("app-themes/fzf-theme/fzf.fish.tmpl", "app-themes/fzf-theme/{slug}/jenerated-{slug}.fish"),
    ("app-themes/mpv-theme/colors.conf.tmpl", "app-themes/mpv-theme/{slug}/jenerated-{slug}.conf"),
    ("app-themes/tmux-theme/colors.conf.tmpl", "app-themes/tmux-theme/{slug}/jenerated-{slug}.conf"),
    ("app-themes/zsh-theme/colors.zsh.tmpl", "app-themes/zsh-theme/{slug}/jenerated-{slug}.zsh"),
    ("app-themes/zsh-theme/fast-theme.ini.tmpl", "app-themes/zsh-theme/{slug}/jenerated-{slug}.ini"),
    ("app-themes/element-theme/theme.json.tmpl", "app-themes/element-theme/{slug}/jenerated-{slug}.json"),
    ("app-themes/mattermost-theme/theme.json.tmpl", "app-themes/mattermost-theme/{slug}.json"),
    ("app-themes/insomnia-theme/package.json.tmpl", "app-themes/insomnia-theme/{slug}/insomnia-plugin-jenerated-{slug}/package.json"),
    ("app-themes/insomnia-theme/index.js.tmpl", "app-themes/insomnia-theme/{slug}/insomnia-plugin-jenerated-{slug}/index.js"),
    ("app-themes/sublime-theme/color-scheme.tmpl", "app-themes/sublime-theme/jenerated-{slug}.sublime-color-scheme"),
    ("app-themes/xcode-theme/theme.xccolortheme.tmpl", "app-themes/xcode-theme/jenerated-{slug}.xccolortheme"),
    ("app-themes/rstudio-theme/theme.rstheme.tmpl", "app-themes/rstudio-theme/jenerated-{slug}.rstheme"),
    ("app-themes/emacs-theme/theme.el.tmpl", "app-themes/emacs-theme/jenerated-{slug}-theme.el"),
    ("app-themes/qtcreator-theme/color-scheme.xml.tmpl", "app-themes/qtcreator-theme/jenerated-{slug}.xml"),
    ("app-themes/spyder-theme/scheme.ini.tmpl", "app-themes/spyder-theme/jenerated-{slug}.ini"),
    ("app-themes/unreal-theme/theme.json.tmpl", "app-themes/unreal-theme/jenerated-{slug}.json"),
    ("app-themes/obs-theme/style.ovt.tmpl", "app-themes/obs-theme/jenerated-{slug}.ovt"),
    ("app-themes/jellyfin-theme/theme.css.tmpl", "app-themes/jellyfin-theme/jenerated-{slug}.css"),
    ("app-themes/libreoffice-theme/theme.xcu.tmpl", "app-themes/libreoffice-theme/{slug}/theme.xcu"),
    ("app-themes/libreoffice-theme/description.xml.tmpl", "app-themes/libreoffice-theme/{slug}/description.xml"),
    ("app-themes/libreoffice-theme/description.txt.tmpl", "app-themes/libreoffice-theme/{slug}/description.txt"),
    ("app-themes/libreoffice-theme/manifest.xml.tmpl", "app-themes/libreoffice-theme/{slug}/META-INF/manifest.xml"),
    ("app-themes/wireshark-theme/colorfilters.tmpl", "app-themes/wireshark-theme/{slug}/colorfilters"),
    ("app-themes/ghidra-theme/theme.theme.tmpl", "app-themes/ghidra-theme/jenerated-{slug}.theme"),
    ("app-themes/caido-theme/theme.css.tmpl", "app-themes/caido-theme/jenerated-{slug}.css"),
    ("app-themes/qtct-theme/colors.conf.tmpl", "app-themes/qtct-theme/jenerated-{slug}.conf"),
    ("app-themes/radare2-theme/theme.r2.tmpl", "app-themes/radare2-theme/jenerated-{slug}"),
    ("app-themes/rizin-theme/theme.rz.tmpl", "app-themes/rizin-theme/jenerated-{slug}"),
    ("app-themes/gemini-theme/theme.json.tmpl", "app-themes/gemini-theme/jenerated-{slug}.json"),
    ("app-themes/pwsh-theme/colors.ps1.tmpl", "app-themes/pwsh-theme/jenerated-{slug}.ps1"),
    ("app-themes/quassel-theme/stylesheet.qss.tmpl", "app-themes/quassel-theme/jenerated-{slug}.qss"),
    ("app-themes/veilamp-theme/theme.json.tmpl", "app-themes/veilamp-theme/{slug}/skin.json"),
]

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

HEX = re.compile(r"#[0-9a-fA-F]{6}")
# {{name}}, or {{scheme: "text for dark" | "text for light"}}.
PLACEHOLDER = re.compile(
    r'\{\{\s*(?:([A-Za-z0-9_]+)|scheme\s*:\s*"([^"]*)"\s*\|\s*"([^"]*)")\s*\}\}')
SCHEMES = ("dark", "light")
# {{green_over_bg_20}}: one color laid over another at a percentage, as
# #rrggbb, for apps that can't take a color with transparency.
BLEND = re.compile(r"([a-z0-9_]+?)_over_([a-z0-9_]+?)_(100|[1-9]?[0-9])")
# Slugs become file names, so they're kept to lowercase words and dashes.
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# Each palette's {{uuid}} is made from its slug in this namespace.
UUID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "https://github.com/savagejen/jenerated-themes")


def is_path(arg):
    """Whether a command-line palette is a file path rather than a slug."""
    return arg.endswith(".toml") or "/" in arg


def check_slug(slug, source):
    """Exit unless `slug` is safe to use in a file name."""
    if not SLUG.fullmatch(slug):
        sys.exit(f"{source}: {slug!r} is not a valid slug (use lowercase "
                 f"letters, numbers and single dashes, e.g. blue-purple)")
    return slug


def palette_folder(scheme):
    """Where palettes of a scheme ("dark" or "light") are filed."""
    return PALETTES / SCHEME_FOLDERS[scheme]


def palette_folders():
    """Every folder palettes are found in: palettes/Dark, palettes/Light,
    and palettes/ itself, for a palette not filed yet."""
    return [palette_folder(scheme) for scheme in SCHEMES] + [PALETTES]


def in_palettes(path):
    """Whether a file is in one of the palette folders."""
    return path.resolve().parent in palette_folders()


def palette_files():
    """Every palette file in the palette folders, in order of file name."""
    return sorted((path for folder in palette_folders()
                   for path in folder.glob("*-palette.toml")),
                  key=lambda path: path.name)


def palette_path(arg):
    """Turn a slug or a path into the palette file's path."""
    if is_path(arg):
        path = Path(arg)
        if not path.is_file():
            sys.exit(f"No palette file at {path}.")
        return path
    name = f"{check_slug(arg, 'palette')}-palette.toml"
    found = [folder / name for folder in palette_folders() if (folder / name).is_file()]
    if len(found) > 1:
        sys.exit(f"The palette {arg!r} is in more than one place: "
                 f"{', '.join(str(p.relative_to(ROOT)) for p in found)}. "
                 f"Keep one of them.")
    if not found:
        sys.exit(f"No palette named {arg!r} (looked for {name} in palettes/Dark "
                 f"and palettes/Light). Run ./jenerate.py --list to see the "
                 f"available palettes.")
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
    folder = {PALETTES / name: scheme for scheme, name in SCHEME_FOLDERS.items()}
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
        sys.exit(f"{path}: not a valid palette file: {error}")

    for key in ("name", "slug"):
        if not isinstance(data.get(key), str):
            sys.exit(f"{path}: missing top-level `{key}` string")
    # The name is written into the themes as is, so it mustn't be able to
    # break out of a JSON string, an XML file or an INI line. It also names
    # the Obsidian theme's folder, so no slashes.
    name = data["name"]
    if any(c in '"\\/<>&' or not c.isprintable() for c in name):
        sys.exit(f"{path}: `name` can't contain quotes, slashes, "
                 f"backslashes, <, >, & or line breaks")
    if not name.strip() or name != name.strip():
        sys.exit(f"{path}: `name` can't be empty or start or end with spaces")
    slug = check_slug(data["slug"], path)
    if in_palettes(path) and path.name != f"{slug}-palette.toml":
        sys.exit(f"{path}: palettes in palettes/ must be named after their "
                 f"slug; rename it to {slug}-palette.toml")

    if data.get("scheme") not in (None, *SCHEMES):
        sys.exit(f'{path}: `scheme` must be "dark" or "light" (or left out, '
                 f"to work it out from `bg`)")

    colors = data.setdefault("colors", {})
    if not isinstance(colors, dict):
        sys.exit(f"{path}: `colors` must be a [colors] table")
    for key, value in colors.items():
        if not isinstance(value, str):
            sys.exit(f"{path}: color `{key}` must be a quoted string, like "
                     f'"#rrggbb" or "red"')
    return data


def srgb_to_linear(channel):
    """An sRGB channel (0-255) in linear light (0-1), by the sRGB curve."""
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color_formats(key, value):
    """The other forms of a #rrggbb color that templates can use."""
    r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return {
        f"{key}_hex": value[1:],
        f"{key}_rgb": f"{r}, {g}, {b}",
        f"{key}_rgb_csv": f"{r},{g},{b}",
        f"{key}_rgb_spaced": f"{r} {g} {b}",
        f"{key}_rgb16": f"{r * 257},{g * 257},{b * 257}",
        f"{key}_int": str((r << 16) | (g << 8) | b),
        f"{key}_float": f"{r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f}",
        f"{key}_float_spaced": f"{r / 255:.4f} {g / 255:.4f} {b / 255:.4f}",
        f"{key}_linear_r": f"{srgb_to_linear(r):.6f}",
        f"{key}_linear_g": f"{srgb_to_linear(g):.6f}",
        f"{key}_linear_b": f"{srgb_to_linear(b):.6f}",
        f"{key}_h": str(round(h * 360) % 360),
        f"{key}_s": str(round(s * 100)),
        f"{key}_l": str(round(l * 100)),
    }


def luminance(color):
    """A #rrggbb color's relative luminance, as WCAG defines it: 0 for black
    to 1 for white."""
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
              for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a, b):
    """The WCAG contrast ratio of two #rrggbb colors, from 1 (the same) to 21
    (black and white)."""
    light, dark = sorted((luminance(a), luminance(b)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def scheme_of(color):
    """ "light" for a background black text reads better on, else "dark"."""
    # The contrast with black beats the contrast with white.
    return "light" if contrast(color, "#000000") > contrast(color, "#ffffff") else "dark"


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
            sys.exit(f"{path}: color `{key}` refers to itself in a loop")
        if value not in colors:
            sys.exit(f"{path}: color `{key}` = {value!r} is not a #rrggbb "
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


def read_template(path):
    """Read a template, or exit naming it if it's missing."""
    try:
        return path.read_text()
    except FileNotFoundError:
        sys.exit(f"{path.relative_to(ROOT)}: template not found. Restore it "
                 f"(git checkout -- {path.relative_to(ROOT)}), or remove it "
                 f"from TARGETS in jenerate.py.")


def blend(top, bottom, percent):
    """#rrggbb for the color `top` laid over `bottom` at `percent` (0-100),
    as it looks with that much opacity."""
    channels = [round(int(t, 16) * percent / 100 + int(b, 16) * (100 - percent) / 100)
                for t, b in ((top[i:i + 2], bottom[i:i + 2]) for i in (1, 3, 5))]
    return "#" + "".join(f"{c:02x}" for c in channels)


def render(template_path, values):
    """Fill in a template's placeholders, or exit naming any missing ones."""
    text = read_template(template_path)
    missing = set()

    def substitute(match):
        key, for_dark, for_light = match.groups()
        if key is None:
            return for_dark if values["scheme"] == "dark" else for_light
        if key not in values:
            blended = BLEND.fullmatch(key)
            if blended and all(HEX.fullmatch(values.get(name, "")) for name in blended.groups()[:2]):
                top, bottom, percent = blended.groups()
                return blend(values[top], values[bottom], int(percent))
            missing.add(key)
            return match.group(0)
        return values[key]

    result = PLACEHOLDER.sub(substitute, text)
    if missing:
        sys.exit(f"{template_path.relative_to(ROOT)}: the palette has no "
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


def read_vscode_theme(path):
    """Return a generated VS Code theme's name and type, or exit if the file
    is broken."""
    try:
        theme = json.loads(path.read_text())
        name, kind = theme["name"], theme.get("type", "dark")
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        sys.exit(f"{path.relative_to(ROOT)}: not a valid theme file ({error}). "
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


def main():
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        epilog="Separate several palettes with commas or spaces.")
    parser.add_argument("palettes", nargs="*",
                        help="palette slugs (e.g. blue-purple) or .toml paths")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--remove", action="store_true",
                        help="delete these palettes' generated themes")
    action.add_argument("--list", action="store_true",
                        help="list the palettes in palettes/")
    action.add_argument("--contrast", action="store_true",
                        help="report text colors below the recommended contrast "
                             f"({CONTRAST_TARGET}:1), for these palettes or all of them")
    args = parser.parse_args()
    names = [name.strip() for arg in args.palettes
             for name in arg.split(",") if name.strip()]

    if args.list:
        if names:
            parser.error("--list doesn't take palettes")
        list_palettes()
        return
    if args.contrast:
        report_contrast(names)
        return

    if not names:
        parser.error("name at least one palette, e.g. ./jenerate.py "
                     "blue-purple (see ./jenerate.py --list)")

    if args.remove:
        remove(names)
    else:
        add(names)
    write_vscode_package()


if __name__ == "__main__":
    main()
