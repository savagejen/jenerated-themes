"""Qt Creator."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS, folder_from_env
from ..ui import say, step
from . import App


def qtcreator_styles_dirs():
    """Qt Creator's user styles folders: the usual one (~/.config on macOS
    too), and, if Qt Creator was installed through Flatpak, the folder Flatpak
    gives it."""
    if OS == "Darwin":
        dirs = [HOME / ".config/QtProject/qtcreator/styles"]
    else:
        dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "QtProject/qtcreator/styles"]
    if (HOME / ".var/app/io.qt.QtCreator").is_dir():
        dirs.append(HOME / ".var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles")
    return dirs


def install(theme):
    file = f"jenerated-{theme.slug}.xml"

    for folder in qtcreator_styles_dirs():
        plan_link(folder / file, paths.app_themes(f"qtcreator-theme/{file}"))
    run_install_plan("the Qt Creator color scheme")

    step("Done! To turn the color scheme on, in Qt Creator:")
    say("1. Open Edit -> Preferences (Qt Creator -> Settings on a Mac, Tools ->")
    say("   Options in older versions) -> Text Editor -> Font & Colors.")
    say(f'2. Choose "Jenerated {theme.name}" as the Color Scheme. (Restart Qt Creator')
    say("   first if it doesn't appear.)")
    say("For the rest of the window, choose Qt Creator's own Dark or Light theme")
    say("to match, under Environment -> Interface -> Theme.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and choose the scheme")
    say("again, or restart Qt Creator.")


APP = App(
    id="qtcreator",
    label="Qt Creator",
    category="editors",
    templates=(
        ("app-themes/qtcreator-theme/color-scheme.xml.tmpl",
         "app-themes/qtcreator-theme/jenerated-{slug}.xml"),
    ),
    words=("qt", "qml", "c++"),
    commands=("qtcreator",),
    flatpaks=("io.qt.QtCreator",),
    mac_apps=("Qt Creator",),
    install=install,
)
