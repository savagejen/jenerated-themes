"""mpv (media player)."""

from .. import paths, state
from ..install import install_link, load_colors_from
from ..system import HOME, folder_from_env, make_folders
from ..ui import say, step
from . import App


def mpv_config_dirs():
    """mpv's settings folders: the usual one (on macOS too), and, if mpv was
    installed through Flatpak, the folder Flatpak gives it."""
    dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "mpv"]
    if (HOME / ".var/app/io.mpv.Mpv").is_dir():
        dirs.append(HOME / ".var/app/io.mpv.Mpv/config/mpv")
    return dirs


def install(theme):
    folder = paths.app_themes(f"mpv-theme/{theme.slug}")
    line = 'include="~~/jenerated-colors.conf"'

    dirs = mpv_config_dirs()

    step("Installing the mpv colors")
    for folder_ in dirs:
        make_folders(folder_)
        install_link(folder_ / "jenerated-colors.conf", folder / f"jenerated-{theme.slug}.conf")
        load_colors_from(folder_ / "mpv.conf", line,
                         "# mpv's settings. The line below loads the Jenerated colors.")

    step(f"Done! Restart mpv to see Jenerated {theme.name}.")
    say("The on-screen controller's colors need mpv 0.39 or later; older versions")
    say("keep its own colors (and mention the settings they don't know).")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart mpv.")


APP = App(
    id="mpv",
    label="mpv (media player)",
    category="entertainment",
    templates=(
        ("app-themes/mpv-theme/colors.conf.tmpl",
         "app-themes/mpv-theme/{slug}/jenerated-{slug}.conf"),
    ),
    words=("video", "music"),
    commands=("mpv",),
    flatpaks=("io.mpv.Mpv",),
    mac_apps=("mpv",),
    one_palette=True,
    install=install,
)
