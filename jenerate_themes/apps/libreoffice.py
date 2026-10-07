"""LibreOffice (Writer, Calc, Impress and more)."""

import os
import shutil

from .. import paths, state
from ..system import OS, status_of, succeeds, zip_folder
from ..ui import say, step, stop
from . import App


def libreoffice_unopkg():
    """LibreOffice's extension installer, or "" if it can't be found."""
    if shutil.which("unopkg"):
        return shutil.which("unopkg")
    mac_unopkg = "/Applications/LibreOffice.app/Contents/MacOS/unopkg"
    if OS == "Darwin" and os.access(mac_unopkg, os.X_OK):
        return mac_unopkg
    return ""


def install(theme):
    folder = paths.app_themes(f"libreoffice-theme/{theme.slug}")
    oxt = paths.app_themes(f"libreoffice-theme/jenerated-{theme.slug}.oxt")
    installed = False

    step("Packaging the LibreOffice theme")
    # The theme is a small extension: its folder, zipped as an .oxt.
    if not zip_folder(folder, oxt):
        stop(f"couldn't make {oxt}; zip the contents of {folder} by hand")
    say(f"Made {oxt}")

    unopkg = libreoffice_unopkg()
    open_already = succeeds(["pgrep", "-x", "soffice.bin"]) or succeeds(["pgrep", "-x", "soffice"])
    if unopkg and not open_already:
        step("Installing it as a LibreOffice extension")
        # --force replaces an earlier version of the same palette's theme.
        if status_of([unopkg, "add", "--force", oxt]) == 0:
            installed = True
            say("Installed.")
        else:
            say("unopkg couldn't install it; add it by hand as below.")

    # Without its installer, or with LibreOffice open, it's only packaged.
    if not installed and state.current.auto:
        stop("LibreOffice's extension installer (unopkg) wasn't found, or LibreOffice is open; "
            f"run {state.COMMAND} again and choose LibreOffice on its own")
    step("Done! To turn the theme on:")
    if not installed:
        say("1. In LibreOffice, open Tools -> Extensions, click Add, and choose")
        say(f"   {oxt}")
        say("   then restart LibreOffice.")
    else:
        say("1. Open LibreOffice (or restart it).")
    say("2. Open Tools -> Options (LibreOffice -> Preferences on a Mac) ->")
    say("   LibreOffice -> Appearance.")
    say(f'3. Tick "Enable application theming", choose "Jenerated {theme.name}" as the')
    say("   theme, click OK, and restart LibreOffice when it asks.")
    say('To keep documents on white pages, also tick "Use white document')
    say('background".')
    say(f"After changing the palette, run {state.COMMAND} again (with LibreOffice")
    say("closed) and restart LibreOffice.")


APP = App(
    id="libreoffice",
    label="LibreOffice (Writer, Calc, Impress and more)",
    category="editors",
    templates=(
        ("app-themes/libreoffice-theme/theme.xcu.tmpl",
         "app-themes/libreoffice-theme/{slug}/theme.xcu"),
        ("app-themes/libreoffice-theme/description.xml.tmpl",
         "app-themes/libreoffice-theme/{slug}/description.xml"),
        ("app-themes/libreoffice-theme/description.txt.tmpl",
         "app-themes/libreoffice-theme/{slug}/description.txt"),
        ("app-themes/libreoffice-theme/manifest.xml.tmpl",
         "app-themes/libreoffice-theme/{slug}/META-INF/manifest.xml"),
    ),
    covers="Writer, Calc, Impress, Draw, Base, Math",
    words=("office", "documents", "spreadsheets", "presentations", "word", "processor"),
    commands=("soffice", "libreoffice"),
    flatpaks=("org.libreoffice.LibreOffice",),
    mac_apps=("LibreOffice",),
    install=install,
)
