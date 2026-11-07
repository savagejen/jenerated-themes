"""The apps Jenerated Themes installs into: one module per app, each with an
App describing it and an install function.

To add an app, add its module here, with an APP like the others', then
import it and add its APP to ALL_APPS, below.
"""

import os
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

from ..errors import JenerateError
from ..system import HOME, OS, succeeds


@dataclass
class App:
    """An app in the menus.

    id           what `jenerate install` (and setup.sh --install) call it
    label        its name in the menus
    category     one of CATEGORIES, or "" to stay on the main app menu
    install      install(theme) installs a palette's theme into it
    templates    (template, output) pairs, laid out as in the repository:
                 the files each palette's theme is made from (read from
                 paths.SOURCE), and where they go (under paths.DATA). {slug} in the output is replaced with the palette's slug;
                 it may name a folder, which is created as needed and deleted
                 with the palette's last file. {scheme} in the template is
                 replaced with "dark" or "light", for apps whose dark and
                 light themes differ too much for one template.
    covers       the apps the theme covers, as its README lists them, shown
                 under the label in search results, since the label only has
                 room for a few
    words        other words people might search for (not shown)
    commands     how it's found on this computer, for ALL THE APPS: its
    flatpaks     commands on PATH, its Flatpak ids, its apps in Applications
    mac_apps     on macOS, or a library it installs (any one will do)
    libraries
    present      another way to tell it's there (like a settings folder it
                 leaves), tried first; with none of the above, the only way
    system       the only system it's offered on ("Linux" or "Darwin"), if one
    manual       True if it can't be installed into: the theme is made, and it
                 explains what to do in the app. ALL THE APPS leaves it out.
    one_palette  True if it uses one palette at a time (installing one
                 switches it), so ALL THE PALETTES isn't offered for it
    """
    id: str
    label: str
    category: str
    install: Callable
    templates: tuple = ()
    covers: str = ""
    words: tuple = ()
    commands: tuple = ()
    flatpaks: tuple = ()
    mac_apps: tuple = ()
    libraries: tuple = ()
    present: Optional[Callable[[], bool]] = None
    system: str = ""
    manual: bool = False
    one_palette: bool = False


# The categories of the app menu, by id, in menu order.
CATEGORIES = {
    "browsers": "Web browsers",
    "communication": "Communication",
    "editors": "Editors: code, text and notes",
    "terminal": "Terminals and command-line tools",
    "desktop": "Linux desktops",
    "entertainment": "Entertainment",
    "art": "Art and design",
    "hacking": "Hacking and testing tools",
}

SYSTEM_NAMES = {"Linux": "Linux", "Darwin": "macOS"}

def menu_order(app):
    """Where the app goes in the menus: the main app menu's own apps first,
    then each category's apps in CATEGORIES order, alphabetically by label
    within each."""
    if app.category == "":
        category_position = 0
    else:
        category_position = list(CATEGORIES).index(app.category) + 1

    return (category_position, app.label.lower())


# --- The apps ----------------------------------------------------------------

# Import after defining App: each app module imports it from this package.
# Only modules listed here are imported; tests/apps/test-every-app.sh checks
# that every app module in this directory is listed.
from . import (
    caido,
    chromium,
    decky,
    element,
    emacs,
    firefox,
    fzf,
    gemini,
    ghidra,
    godot,
    gtk3,
    gtksourceview,
    insomnia,
    jellyfin,
    jetbrains,
    kde,
    krita,
    libreoffice,
    mattermost,
    mpv,
    obs,
    obsidian,
    ptyxis,
    pwsh,
    qtcreator,
    qtct,
    qterminal,
    quassel,
    radare2,
    rizin,
    rstudio,
    slack,
    spyder,
    sublime,
    tilix,
    tmux,
    unreal,
    veilamp,
    vim,
    vivaldi,
    vscode,
    wireshark,
    xcode,
    zen,
    zsh,
)

# Every app, in any order; sorted into menu order below.
ALL_APPS = [
    caido.APP,
    chromium.APP,
    decky.APP,
    element.APP,
    emacs.APP,
    firefox.APP,
    fzf.APP,
    gemini.APP,
    ghidra.APP,
    godot.APP,
    gtk3.APP,
    gtksourceview.APP,
    insomnia.APP,
    jellyfin.APP,
    jetbrains.APP,
    kde.APP,
    krita.APP,
    libreoffice.APP,
    mattermost.APP,
    mpv.APP,
    obs.APP,
    obsidian.APP,
    ptyxis.APP,
    pwsh.APP,
    qtcreator.APP,
    qtct.APP,
    qterminal.APP,
    quassel.APP,
    radare2.APP,
    rizin.APP,
    rstudio.APP,
    slack.APP,
    spyder.APP,
    sublime.APP,
    tilix.APP,
    tmux.APP,
    unreal.APP,
    veilamp.APP,
    vim.APP,
    vivaldi.APP,
    vscode.APP,
    wireshark.APP,
    xcode.APP,
    zen.APP,
    zsh.APP,
]

for app in ALL_APPS:
    if not isinstance(app, App):
        raise JenerateError(f"Each entry in ALL_APPS should be an app module's APP, "
                            f"but one is a {type(app).__name__}.")

    if app.category and app.category not in CATEGORIES:
        raise JenerateError(f'The app "{app.id}" has no category called "{app.category}"; '
                            f"the categories are {', '.join(CATEGORIES)} (in "
                            "jenerate_themes/apps/__init__.py).")

ALL_APPS.sort(key=menu_order)

# The apps offered on this system, in menu order.
APPS = [app for app in ALL_APPS if not app.system or app.system == OS]


def find_app(app_id):
    """The App offered on this system with this id, or None."""
    return next((app for app in APPS if app.id == app_id), None)


def other_system(app_id):
    """The system an app is only offered on (Linux or macOS) when it's not
    this one, or ""."""
    app = next((app for app in ALL_APPS if app.id == app_id), None)
    if app and app.system and app.system != OS:
        return SYSTEM_NAMES[app.system]
    return ""


def app_present(app):
    """True if the app looks installed on this computer: one of its commands
    is on PATH, its Flatpak is installed, its app is in Applications (on
    macOS), or its library is there. ALL THE APPS only installs into apps it
    finds. The tests set SETUP_FOUND_APPS to the ids to count as found, so
    they don't depend on what's installed where they run."""
    if "SETUP_FOUND_APPS" in os.environ:
        return app.id in os.environ["SETUP_FOUND_APPS"].split()
    if app.present and app.present():
        return True
    if not (app.commands or app.flatpaks or app.mac_apps or app.libraries):
        # Nothing to look for: an app found only by its folder isn't there;
        # one with no way to tell (a manual install) counts as there.
        return app.present is None
    if any(shutil.which(command) for command in app.commands):
        return True
    if shutil.which("flatpak") and any(succeeds(["flatpak", "info", flatpak])
                                    for flatpak in app.flatpaks):
        return True
    if OS == "Darwin" and any((folder / f"{name}.app").is_dir() for name in app.mac_apps
                              for folder in (Path("/Applications"), HOME / "Applications")):
        return True
    return any(lib.exists() for name in app.libraries
               for lib in [*sorted(Path("/usr/lib").glob(f"*/{name}")), Path("/usr/lib64", name),
                           Path("/usr/lib", name)])
