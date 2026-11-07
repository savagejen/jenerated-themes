"""KDE Plasma (Plasma and KDE apps, Konsole, Kate)."""

import re
import subprocess

from .. import paths
from ..install import install_link
from ..system import HOME, folder_from_env, make_folders, output_of, status_of, succeeds
from ..ui import ask_yes, say, step
from . import App


def install(theme):
    data = folder_from_env("XDG_DATA_HOME", HOME / ".local/share")
    folder = paths.app_themes(f"kde-theme/{theme.slug}")
    scheme = f"Jenerated-{theme.slug}"
    current = ""
    applied = False

    step("Installing the Plasma color scheme, Konsole colors and Kate theme")
    make_folders(data / "color-schemes", data / "konsole",
                 data / "org.kde.syntax-highlighting/themes")
    install_link(data / f"color-schemes/{scheme}.colors", folder / f"{scheme}.colors")
    install_link(data / f"konsole/{scheme}.colorscheme", folder / f"{scheme}.colorscheme")
    install_link(data / f"org.kde.syntax-highlighting/themes/{scheme}.theme",
                 folder / f"{scheme}.theme")

    # On Plasma, offer to switch the color scheme now.
    if succeeds(["plasma-apply-colorscheme", "--list-schemes"]):
        schemes = output_of(["plasma-apply-colorscheme", "--list-schemes"],
                            stderr=subprocess.DEVNULL) or ""
        current = "\n".join(match.group(1) for match in
                            re.finditer(r"^ *\* *(.*) \(current color scheme\)$", schemes, re.M))
        say("")
        if current:
            say(f"Your Plasma color scheme is {current}.")
        if ask_yes(f"Switch Plasma to Jenerated {theme.name} now?"):
            applied = status_of(["plasma-apply-colorscheme", scheme]) == 0

    step("Done! To turn the themes on:")
    if applied:
        say(f"- Plasma, its window title bars and KDE apps use Jenerated {theme.name} now.")
        if current:
            say(f"  To switch back: plasma-apply-colorscheme {current}")
    else:
        say("- Plasma and KDE apps: System Settings -> Colors & Themes -> Colors,")
        say(f'  choose "Jenerated {theme.name}" (or run plasma-apply-colorscheme {scheme}).')
    say("- Konsole: Settings -> Edit Current Profile -> Appearance, choose")
    say(f'  "Jenerated {theme.name}".')
    say("- Kate and KWrite: Settings -> Configure Kate -> Color Themes, choose")
    say(f'  "Jenerated {theme.name}" (restart Kate first if it\'s open).')
    say("GTK apps follow Plasma's colors too, through KDE's GTK integration.")


APP = App(
    id="kde",
    label="KDE Plasma (Plasma and KDE apps, Konsole, Kate)",
    category="desktop",
    templates=(
        ("app-themes/kde-theme/colors.tmpl",
         "app-themes/kde-theme/{slug}/Jenerated-{slug}.colors"),
        ("app-themes/kde-theme/konsole.colorscheme.tmpl",
         "app-themes/kde-theme/{slug}/Jenerated-{slug}.colorscheme"),
        ("app-themes/kde-theme/syntax.theme.tmpl",
         "app-themes/kde-theme/{slug}/Jenerated-{slug}.theme"),
    ),
    covers="Dolphin, Kate, KWrite, Okular, Konsole, System Settings",
    commands=("plasmashell",),
    system="Linux",
    one_palette=True,
    install=install,
)
