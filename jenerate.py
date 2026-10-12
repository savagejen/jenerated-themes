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

# The code lives in the jenerate_themes package; this script is its command
# line from before the jenerate command, kept so ./jenerate.py works as it
# always has. ./jenerate generate, remove, list and contrast do the same.

import argparse
import sys

from jenerate_themes import state
from jenerate_themes.errors import JenerateError
from jenerate_themes.palettes import CONTRAST_TARGET, report_contrast
from jenerate_themes.render import add, list_palettes, remove
from jenerate_themes.vscode import write_vscode_package


def main():
    # Its messages name ./jenerate.py and its options.
    state.COMMAND = "./jenerate.py"
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
    try:
        main()
    except JenerateError as error:
        # A palette or template with a problem: its message, and status 1.
        sys.exit(str(error))
