"""Zen Browser."""

from pathlib import Path

from .. import paths, state
from ..install import install_link
from ..system import (HOME, OS, append_lines, folder_from_env, has_line, make_folders, read_text,
                      replace_text, write_text)
from ..ui import ask_yes, choose, say, step, stop
from . import App


def zen_profile_roots():
    """Folders that can hold Zen's profiles.ini: Zen's usual one (newer
    versions use the XDG config folder on Linux), and, if Zen was installed
    through Flatpak, the folder Flatpak gives it."""
    if OS == "Darwin":
        return [HOME / "Library/Application Support/zen"]
    roots = [HOME / ".zen", folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "zen"]
    flatpak = HOME / ".var/app/app.zen_browser.zen"
    if flatpak.is_dir():
        roots += [flatpak / ".zen", flatpak / "config/zen"]
    return roots


def zen_profiles():
    """(folder, name) for each Zen profile whose folder exists."""
    profiles = []
    for root in zen_profile_roots():
        if not (root / "profiles.ini").is_file():
            continue
        in_profile = False
        path = name = ""
        relative = "1"
        found = []

        def flush():
            if in_profile and path:
                found.append((root / path if relative == "1" else Path(path), name))

        for line in read_text(root / "profiles.ini").replace("\r", "").split("\n"):
            key = line.split("=", 1)[0]
            if line.startswith("["):
                flush()
                in_profile = line.startswith("[Profile")
                path = name = ""
                relative = "1"
            elif key == "Name":
                name = line[5:]
            elif key == "Path":
                path = line[5:]
            elif key == "IsRelative":
                relative = line.split("=")[1] if "=" in line else ""
        flush()
        profiles += [(folder, name) for folder, name in found if folder.is_dir()]
    return profiles


def zen_import(path, stylesheet):
    """Makes sure path (userChrome.css or userContent.css) starts by importing
    stylesheet, creating it if needed. Asks before changing a file that's
    already there."""
    line = f'@import "{stylesheet}";'
    name = path.stem if path.suffix == ".css" else path.name
    if not path.exists():
        write_text(path, f"/* Zen's stylesheet for {name}. The line below loads the\n"
                         "   Jenerated theme; your own styles can go after it. */\n"
                         f"{line}\n")
        say(f"Created {path}")
    elif has_line(path, line):
        return
    elif ask_yes(f"Add the theme to the top of your {path.name}? (Your styles in it are kept.)"):
        replace_text(path, line + "\n" + read_text(path))
        say(f"Added the theme to {path}")
    else:
        say(f"Left {path} alone; add this line to the top of it to use the theme:")
        say(f"    {line}")


def install(theme):
    folder = paths.app_themes(f"zen-theme/{theme.slug}")
    pref = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

    found = zen_profiles()
    profiles = [folder_ for folder_, _ in found]
    names = [f"{name or folder_.name} ({folder_})" for folder_, name in found]

    if not profiles:
        if state.current.auto:
            stop("Zen hasn't been opened yet, so it has no profile to add the theme to; "
                f"open it once, close it, and run {state.COMMAND} again")
        step("Zen hasn't been opened yet, so it has no profile to add the theme to.")
        say(f"Open Zen once, close it, and run {state.COMMAND} again.")
        return
    if len(profiles) == 1:
        profile = profiles[0]
    else:
        profile = profiles[choose("Which Zen profile?", *names)]

    step(f"Installing the Zen theme into {profile}")
    chrome = profile / "chrome"
    make_folders(chrome)
    install_link(chrome / "jenerated-userChrome.css", folder / "userChrome.css")
    install_link(chrome / "jenerated-userContent.css", folder / "userContent.css")
    zen_import(chrome / "userChrome.css", "jenerated-userChrome.css")
    zen_import(chrome / "userContent.css", "jenerated-userContent.css")

    # Zen only reads userChrome.css and userContent.css with this setting on;
    # user.js sets it each time Zen starts.
    if not has_line(profile / "user.js", pref):
        append_lines(profile / "user.js", pref)
        say(f"Turned on custom stylesheets in {profile}/user.js")

    step(f"Done! Restart Zen to see Jenerated {theme.name}.")
    say("Zen reads the theme from this folder when it starts, so after changing")
    say("the palette, restart Zen again. To go back to Zen's own look, remove the")
    say("@import lines from userChrome.css and userContent.css in")
    say(f"    {chrome}")


APP = App(
    id="zen",
    label="Zen Browser",
    category="browsers",
    templates=(
        ("app-themes/zen-theme/userChrome.css.tmpl", "app-themes/zen-theme/{slug}/userChrome.css"),
        ("app-themes/zen-theme/userContent.css.tmpl",
         "app-themes/zen-theme/{slug}/userContent.css"),
    ),
    commands=("zen", "zen-browser"),
    flatpaks=("app.zen_browser.zen",),
    mac_apps=("Zen", "Zen Browser"),
    one_palette=True,
    install=install,
)
