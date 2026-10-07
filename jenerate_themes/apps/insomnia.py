"""Insomnia (API client)."""

from .. import paths, state
from ..system import HOME, OS, copy_path, folder_from_env, make_folders, remove
from ..ui import say, step
from . import App


def insomnia_plugin_dirs():
    """Insomnia's plugin folders: the usual one, and, if Insomnia was
    installed through Flatpak or Snap, the folder each of those gives it."""
    if OS == "Darwin":
        return [HOME / "Library/Application Support/Insomnia/plugins"]
    dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "Insomnia/plugins"]
    if (HOME / ".var/app/rest.insomnia.Insomnia").is_dir():
        dirs.append(HOME / ".var/app/rest.insomnia.Insomnia/config/Insomnia/plugins")
    if (HOME / "snap/insomnia").is_dir():
        dirs.append(HOME / "snap/insomnia/current/.config/Insomnia/plugins")
    return dirs


def install(theme):
    plugin = f"insomnia-plugin-jenerated-{theme.slug}"
    source = paths.app_themes(f"insomnia-theme/{theme.slug}/{plugin}")

    # Insomnia ignores plugins that are links to folders elsewhere, so the
    # plugin is copied. A folder with this name is one setup.sh made before, so
    # it's replaced.
    step("Installing the Insomnia theme plugin")
    for folder in insomnia_plugin_dirs():
        make_folders(folder)
        remove(folder / plugin)
        copy_path(source, folder / plugin)
        say(f"Copied the plugin to {folder}/{plugin}")

    step("Done! To turn the theme on:")
    say("1. Restart Insomnia, or open Settings (Preferences in older versions)")
    say("   -> Plugins and choose Reload.")
    say(f'2. Open Settings -> Themes, and choose "Jenerated {theme.name}".')
    say(f"The plugin is a copy, so after changing the palette, run {state.COMMAND} again")
    say("and reload the plugins.")


APP = App(
    id="insomnia",
    label="Insomnia (API client)",
    category="hacking",
    templates=(
        ("app-themes/insomnia-theme/package.json.tmpl",
         "app-themes/insomnia-theme/{slug}/insomnia-plugin-jenerated-{slug}/package.json"),
        ("app-themes/insomnia-theme/index.js.tmpl",
         "app-themes/insomnia-theme/{slug}/insomnia-plugin-jenerated-{slug}/index.js"),
    ),
    words=("rest", "http", "graphql", "api", "kong", "testing"),
    commands=("insomnia",),
    flatpaks=("rest.insomnia.Insomnia",),
    mac_apps=("Insomnia",),
    install=install,
)
