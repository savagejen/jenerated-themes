"""OBS Studio (streaming and recording)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS, folder_from_env
from ..ui import say, step
from . import App


def obs_themes_dirs():
    """OBS Studio's themes folders: the usual one, and, if OBS was installed
    through Flatpak, the folder Flatpak gives it."""
    if OS == "Darwin":
        dirs = [HOME / "Library/Application Support/obs-studio/themes"]
    else:
        dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "obs-studio/themes"]
    if (HOME / ".var/app/com.obsproject.Studio").is_dir():
        dirs.append(HOME / ".var/app/com.obsproject.Studio/config/obs-studio/themes")
    return dirs


def install(theme):
    file = f"jenerated-{theme.slug}.ovt"

    for folder in obs_themes_dirs():
        plan_link(folder / file, paths.app_themes(f"obs-theme/{file}"))
    run_install_plan("the OBS Studio style")

    step("Done! To turn the style on, restart OBS Studio, then:")
    say("1. Open Settings -> Appearance.")
    say(f'2. Choose Yami as the Theme, and "Jenerated {theme.name}" as the Style.')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart OBS.")


APP = App(
    id="obs",
    label="OBS Studio (streaming and recording)",
    category="entertainment",
    templates=(
        ("app-themes/obs-theme/style.ovt.tmpl", "app-themes/obs-theme/jenerated-{slug}.ovt"),
    ),
    words=("obs", "streaming", "recording", "screen", "capture", "twitch", "youtube"),
    commands=("obs",),
    flatpaks=("com.obsproject.Studio",),
    mac_apps=("OBS",),
    install=install,
)
