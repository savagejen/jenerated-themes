#!/usr/bin/env python3
"""Puts the generated files git tracks back to the committed defaults, so
local palettes don't end up in a commit (for maintainers; see
CONTRIBUTING.md). Run it before each commit:

    ./maintainer-tools/prep-commit.py

Blue Purple's files are regenerated (restored if removed, updated if a
template changed), and package.json is rebuilt listing only Blue Purple
(keeping any change to package.json.tmpl). The example packages made from
Blue Purple (EXAMPLE_PACKAGES) are rebuilt from its regenerated files. Other
generated themes stay on disk; they're ignored by git.

./setup.sh --prep-commit runs this too.
"""

import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from jenerate_themes.errors import JenerateError  # noqa: E402
from jenerate_themes.palettes import palette_files, palette_scheme, read_palette_file  # noqa: E402
from jenerate_themes.paths import SOURCE as ROOT  # noqa: E402  (a clone: the repository)
from jenerate_themes.render import add, output_path  # noqa: E402
from jenerate_themes.system import zip_folder  # noqa: E402
from jenerate_themes.targets import TARGETS  # noqa: E402
from jenerate_themes.ui import stop, say, step  # noqa: E402
from jenerate_themes.vscode import write_vscode_package  # noqa: E402

# Committed, ready-to-install packages of Blue Purple: (folder, package) pairs.
EXAMPLE_PACKAGES = [
    ("app-themes/vivaldi-theme/blue-purple", "app-themes/vivaldi-theme/jenerated-blue-purple.zip"),
    ("app-themes/jetbrains-theme/blue-purple",
     "app-themes/jetbrains-theme/jenerated-blue-purple.jar"),
    ("app-themes/libreoffice-theme/blue-purple",
     "app-themes/libreoffice-theme/jenerated-blue-purple.oxt"),
]


def generated_palettes():
    """The slugs of the palettes with generated themes, dark then light, as
    `jenerate list` marks them."""
    found = {"dark": [], "light": []}
    for path in palette_files():
        slug = read_palette_file(path)["slug"]
        if any(output_path(output, slug).exists() for _, output in TARGETS):
            found[palette_scheme(path)].append(slug)
    return found["dark"] + found["light"]


def prep_commit():
    others = ",".join(slug for slug in generated_palettes() if slug != "blue-purple")

    step("Preparing the repository for a commit")
    add(["blue-purple"])
    write_vscode_package(["blue-purple"])
    for folder, package in EXAMPLE_PACKAGES:
        if not zip_folder(f"{ROOT}/{folder}", f"{ROOT}/{package}"):
            stop(f"couldn't rebuild {package}")
        say(f"Rebuilt {package}")
    say("The generated files git tracks now match the Blue Purple defaults.")
    if others:
        say("")
        say(f"Your other themes ({others}) are still generated, but VS Code won't")
        say("list them until you run, after committing:")
        say(f"    ./jenerate.py {others}")


def main():
    # Messages come out in order with the output of what it runs.
    sys.stdout.reconfigure(line_buffering=True)
    if sys.argv[1:]:
        sys.exit("prep-commit.py takes no options; run it on its own")
    os.chdir(ROOT)
    prep_commit()


if __name__ == "__main__":
    try:
        main()
    except JenerateError as error:
        # A palette or template with a problem: its message, and status 1.
        sys.exit(str(error))
