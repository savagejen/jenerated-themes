#!/usr/bin/env python3
"""Update the palette screenshots and palettes/README.md (for maintainers).

Usage:
    ./palette-creator/screenshots.py                # screenshots, then README
    ./palette-creator/screenshots.py candy,sunset   # just these palettes' screenshots
    ./palette-creator/screenshots.py --readme-only  # just the README

First files every palette: a palette belongs in palettes/Dark or
palettes/Light, by jenerate.py's reckoning of its scheme (its `scheme`
setting, or else its editor background), and its screenshot in the matching
folder of palettes/Screenshots. A palette or screenshot filed in the wrong
place, or not filed yet, is moved there.

Then screenshots each palette (or just the ones named, by slug) in the
Palette Creator's preview, into palettes/Screenshots/Dark/<slug>.png or
palettes/Screenshots/Light/<slug>.png, using Playwright (screenshots.js). The
Palette Creator runs on a throwaway copy of the repository, so the real
work-in-progress palette is never touched. Playwright is installed into
~/.cache/jenerated-themes/playwright (outside the repository) the first time,
with its browser, which needs Node.js, npm and a network connection.

Then updates palettes/README.md, which lists the palettes in two sections
that can be collapsed, dark and light: palettes with a screenshot but no
section get one (from their description and key colors), existing sections
get their key colors refreshed, and a section moves to the other group if
its palette's scheme changed. Other text is left alone; sections and
screenshots for palettes that no longer exist are reported, not removed.

./setup.sh --update-screenshots runs this, and ./setup.sh
--update-screenshots=candy,sunset runs it for just those palettes.
"""

import argparse
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import serve  # noqa: E402  (needs the path above)
from serve import jenerate  # noqa: E402

ROOT = jenerate.ROOT
PALETTES = jenerate.PALETTES
SCREENSHOTS = PALETTES / "Screenshots"
README = PALETTES / "README.md"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "jenerated-themes" / "playwright"
# The line under each screenshot in the README, with the palette's key colors.
COLORS_LINE = re.compile(r"^Editor `#[0-9a-fA-F]{6}`, Sidebar .*$", re.M)
# A section's screenshot, filed (Screenshots/Dark/<slug>.png) or from before
# the palettes were filed (Screenshots/<slug>.png).
IMAGE = re.compile(r"\]\(Screenshots/(?:(Dark|Light)/)?([a-z0-9-]+)\.png\)")
# A palette's section starts with a heading: ### now, ## before the dark and
# light groups.
HEADING = re.compile(r"^#{2,3} ", re.M)
# The dark and light groups: collapsible, open to begin with.
GROUP_START = "<details open>\n<summary><h2>{title}</h2></summary>\n"
GROUP_END = "</details>\n"
GROUP_LINE = re.compile(r"^(?:<details open>|<summary><h2>(?:Dark|Light) palettes</h2></summary>"
                        r"|</details>)\n?", re.M)


def relative(path):
    return path.relative_to(ROOT).as_posix()


def screenshot_path(slug, scheme):
    return SCREENSHOTS / jenerate.SCHEME_FOLDERS[scheme] / f"{slug}.png"


def move(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    source.rename(target)
    print(f"Moved {relative(source)} to {relative(target.parent)}/", flush=True)


def file_palettes():
    """Move each palette, and its screenshot, to where its scheme says it
    belongs, and return {slug: (path, template values)}, sorted by slug."""
    found = {}
    for path in jenerate.palette_files():
        values = jenerate.load_palette(path)
        found.setdefault(values["slug"], []).append((path, values))
    twice = {slug: places for slug, places in found.items() if len(places) > 1}
    if twice:
        sys.exit("\n".join(f"The palette {slug!r} is in more than one place: "
                           f"{', '.join(relative(path) for path, _ in places)}. "
                           f"Keep one of them." for slug, places in twice.items()))

    palettes = {}
    for slug, [(path, values)] in sorted(found.items()):
        target = jenerate.filed_path(values)
        if path != target:
            move(path, target)
        screenshot = screenshot_path(slug, values["scheme"])
        if not screenshot.exists():
            for place in (SCREENSHOTS / f"{slug}.png",
                          *(screenshot_path(slug, s) for s in jenerate.SCHEMES)):
                if place.exists():
                    move(place, screenshot)
                    break
        palettes[slug] = (target, values)
    return palettes


# --- Screenshots -------------------------------------------------------------

def playwright():
    """The folder whose node_modules has Playwright and its browser,
    installing them the first time."""
    for tool in ("node", "npm"):
        if not shutil.which(tool):
            sys.exit("Updating screenshots needs Node.js and npm (for Playwright)")
    if not (CACHE / "node_modules" / "playwright").is_dir():
        print(f"Installing Playwright into {CACHE}", flush=True)
        CACHE.mkdir(parents=True, exist_ok=True)
        subprocess.run(["npm", "install", "--prefix", str(CACHE), "--no-save",
                        "--no-audit", "--no-fund", "--silent", "playwright"],
                       env={**os.environ, "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD": "1"},
                       check=True)
    # Fetches the browser if it's missing; quick when it's already there.
    subprocess.run([str(CACHE / "node_modules" / ".bin" / "playwright"),
                    "install", "--only-shell", "chromium"], check=True)
    return CACHE


def copy_repository(target):
    """Copy the repository as git sees it (tracked files, and new ones that
    aren't ignored) into target; outside a git repository, the whole folder."""
    try:
        listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--cached",
                                 "--others", "--exclude-standard"],
                                capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        shutil.copytree(ROOT, target, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        return
    for name in filter(None, listed.decode().split("\0")):
        source = ROOT / name
        if source.is_file():
            (target / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target / name)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def take_screenshots(palettes):
    """Screenshot each (path, values) palette into its scheme's folder."""
    modules = playwright()
    by_scheme = {}
    for path, values in palettes:
        by_scheme.setdefault(values["scheme"], []).append(path)
    with tempfile.TemporaryDirectory() as folder:
        copy = Path(folder) / "repo"
        copy_repository(copy)
        port = free_port()
        server = subprocess.Popen(
            [sys.executable, str(copy / "palette-creator" / "serve.py"),
             "--no-browser", "--port", str(port)],
            env={**os.environ, "PALETTE_CREATOR_DIALOG": "none"},
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            base = f"http://127.0.0.1:{port}"
            for _ in range(100):
                try:
                    urllib.request.urlopen(base, timeout=1)
                    break
                except OSError:
                    time.sleep(0.05)
            else:
                sys.exit("The Palette Creator didn't start")
            for scheme, paths in by_scheme.items():
                out = SCREENSHOTS / jenerate.SCHEME_FOLDERS[scheme]
                out.mkdir(parents=True, exist_ok=True)
                # Named as the Palette Creator lists them, like Dark/sunset-palette.toml.
                subprocess.run(["node", str(HERE / "screenshots.js"), base, str(out),
                                *[serve.listed_name(p) for p in paths]],
                               env={**os.environ, "NODE_PATH": str(modules / "node_modules")},
                               check=True)
        finally:
            server.terminate()
            server.wait()


# --- README --------------------------------------------------------------------

def colors_line(values):
    """The line of key colors under a palette's screenshot."""
    return ", ".join(f"{label} `{values[key]}`" for label, key in
                      (("Editor", "bg"), ("Sidebar", "bg_sidebar"),
                       ("Accent", "accent"), ("Text", "text")))


def section(path, values):
    """A new README section for a palette."""
    name, slug = values["name"], values["slug"]
    description = serve.read_palette(path)["description"]
    description = "\n\n".join(textwrap.fill(p, 78, break_long_words=False,
                                            break_on_hyphens=False)
                              for p in description.split("\n\n") if p.strip())
    image = screenshot_path(slug, values["scheme"]).relative_to(PALETTES).as_posix()
    parts = [f"### {name}", f"`{slug}`"]
    if description:
        parts.append(description)
    parts += [f"![The {name} palette in the Palette Creator's preview]({image})",
              colors_line(values)]
    return "\n\n".join(parts) + "\n"


def update_readme(palettes):
    """Bring palettes/README.md up to date with `palettes` ({slug: (path,
    values)}): every palette's section in its scheme's group."""
    text = README.read_text() if README.exists() else ""
    if not text.strip():
        text = "# Palettes\n"
    text = GROUP_LINE.sub("", text)

    # Split at each heading. Sections with a screenshot are the palettes';
    # other text stays before the groups, or after them if it came later.
    starts = [m.start() for m in HEADING.finditer(text)] + [len(text)]
    chunks = [text[:starts[0]]] + [text[a:b] for a, b in zip(starts, starts[1:])]
    before, after = [], []
    groups = {scheme: [] for scheme in jenerate.SCHEMES}
    listed = set()
    for chunk in chunks:
        image = IMAGE.search(chunk)
        if not image:
            (after if listed else before).append(chunk)
            continue
        folder, slug = image.groups()
        listed.add(slug)
        if slug in palettes:
            values = palettes[slug][1]
            scheme = values["scheme"]
            chunk = COLORS_LINE.sub(colors_line(values), chunk, count=1)
        else:
            print(f"palettes/README.md has a section for {slug}, which isn't a palette any more")
            scheme = "light" if folder == "Light" else "dark"
        chunk = HEADING.sub("### ", chunk, count=1)
        image_path = screenshot_path(slug, scheme).relative_to(PALETTES).as_posix()
        chunk = IMAGE.sub(f"]({image_path})", chunk)
        groups[scheme].append(chunk)

    # Add sections for palettes that have a screenshot but no section.
    added = []
    for slug, (path, values) in palettes.items():
        if slug in listed:
            continue
        if not screenshot_path(slug, values["scheme"]).exists():
            print(f"No screenshot of {slug}, so it isn't added to palettes/README.md")
            continue
        groups[values["scheme"]].append(section(path, values))
        added.append(slug)

    for png in sorted(SCREENSHOTS.rglob("*.png")) if SCREENSHOTS.is_dir() else []:
        if png.stem not in palettes:
            print(f"{relative(png)} is of {png.stem}, which isn't a palette any more")

    text = "".join(before).rstrip("\n") + "\n\n"
    for scheme, sections in groups.items():
        if sections:
            title = f"{jenerate.SCHEME_FOLDERS[scheme]} palettes"
            text += (GROUP_START.format(title=title) + "\n"
                     + "\n".join(s.strip("\n") + "\n" for s in sections)
                     + "\n" + GROUP_END + "\n")
    text = (text + "".join(after).strip("\n")).rstrip("\n") + "\n"

    if not README.exists() or README.read_text() != text:
        README.write_text(text)
        print("Updated palettes/README.md" + (f" (added {', '.join(added)})" if added else ""))
    else:
        print("palettes/README.md is up to date")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--readme-only", action="store_true",
                        help="only update palettes/README.md")
    parser.add_argument("slugs", nargs="*", metavar="slug",
                        help="palettes to screenshot, by slug (commas or spaces "
                             "between several); all of them if none are named")
    args = parser.parse_args()
    slugs = [s for arg in args.slugs for s in arg.split(",") if s]
    if args.readme_only and slugs:
        parser.error("--readme-only updates the README for every palette; "
                     "leave out the palette names")
    palettes = file_palettes()
    chosen = list(palettes.values())
    if slugs:
        unknown = [s for s in slugs if s not in palettes]
        if unknown:
            sys.exit(f"No palette in palettes/ called {', '.join(unknown)} "
                     f"(the palettes are: {', '.join(palettes)})")
        chosen = [palettes[s] for s in dict.fromkeys(slugs)]
    if not args.readme_only:
        take_screenshots(chosen)
    # The README covers every palette, so its key colors stay current.
    update_readme(palettes)


if __name__ == "__main__":
    main()
