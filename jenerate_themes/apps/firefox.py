"""Firefox."""

import json
import shutil
import time
import zipfile

from .. import paths, state
from ..system import OS, start_in_background, succeeds
from ..ui import ask_yes, say, step
from . import App


def open_firefox(url):
    """Opens the URL in Firefox without waiting for it, or returns False if
    Firefox can't be found."""
    if OS == "Darwin":
        return succeeds(["open", "-a", "Firefox", url])
    if shutil.which("firefox"):
        start_in_background(["firefox", url])
        return True
    return False


def package_firefox_theme(folder, xpi):
    """Zips the theme's manifest.json into an .xpi for Mozilla to sign, with a
    version made from the date and time, since each upload needs a new
    version. Returns False if it can't."""
    try:
        manifest = json.loads((folder / "manifest.json").read_text())
        now = time.localtime()
        manifest["version"] = (f"{now.tm_year}.{now.tm_mon * 100 + now.tm_mday}."
                               f"{now.tm_hour * 100 + now.tm_min}")
        with zipfile.ZipFile(xpi, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
        return True
    except (OSError, ValueError):
        return False


def install(theme):
    folder = paths.app_themes(f"firefox-theme/{theme.slug}")
    xpi = paths.app_themes(f"firefox-theme/jenerated-{theme.slug}.xpi")

    step("Packaging the Firefox theme")
    if package_firefox_theme(folder, xpi):
        say(f"Made {xpi}, for keeping the theme (see below).")
    else:
        xpi = ""
        say("Couldn't package it (that needs python3), but you can still try it.")

    say("")
    if ask_yes("Open Firefox's add-on debugging page, to try the theme now?"):
        if not open_firefox("about:debugging#/runtime/this-firefox"):
            say("Couldn't find Firefox; open about:debugging#/runtime/this-firefox in it.")

    step("Done! To try the theme (until Firefox restarts):")
    say('1. In Firefox, on about:debugging ("This Firefox"), click')
    say('   "Load Temporary Add-on...".')
    say(f"2. Choose {folder}/manifest.json")
    if xpi:
        say("")
        say("To keep it: Firefox only keeps add-ons signed by Mozilla, and signing")
        say("your own theme is free.")
        say("1. Go to https://addons.mozilla.org/developers/addon/submit/distribution")
        say("   and sign in with a Mozilla account.")
        say(f'2. Choose "On your own", and upload {xpi}')
        say("3. Download the signed file it gives you, and open it in Firefox")
        say("   (File -> Open File, or drag it onto a Firefox window).")
        say(f"Run {state.COMMAND} again after changing the palette, for a new version.")


APP = App(
    id="firefox",
    label="Firefox",
    category="browsers",
    templates=(
        ("app-themes/firefox-theme/manifest.json.tmpl",
         "app-themes/firefox-theme/{slug}/manifest.json"),
    ),
    words=("mozilla",),
    manual=True,
    install=install,
)
