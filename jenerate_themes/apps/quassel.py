"""Quassel IRC."""

import shutil

from .. import paths, state
from ..install import plan_link, run_install_plan, shell_quote
from ..system import HOME, OS, folder_from_env, make_folders
from ..ui import say, step
from . import App


def quassel_config_dir():
    """Quassel's settings folder (not the Flatpak's; see quassel_flatpak)."""
    if OS == "Darwin":
        return HOME / "Library/Application Support/Quassel"
    return folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "quassel-irc.org"


def quassel_flatpak():
    """The Flatpak's own folder. The Flatpak can't see files outside it, so
    it gets a copy of the stylesheet rather than a link to this folder."""
    return HOME / ".var/app/org.quassel_irc.QuasselClient"


def install(theme):
    file = f"jenerated-{theme.slug}.qss"
    source = paths.app_themes(f"quassel-theme/{file}")
    flatpak_copy = None
    stylesheets = quassel_config_dir() / "stylesheets"

    plan_link(stylesheets / file, source)
    run_install_plan("the Quassel stylesheet")

    if quassel_flatpak().is_dir():
        flatpak_copy = quassel_flatpak() / f"config/quassel-irc.org/stylesheets/{file}"
    if flatpak_copy and state.current.mode == "manual":
        step("For the Quassel Flatpak, which can't see files outside its own folder, run:")
        say(f"    mkdir -p {shell_quote(flatpak_copy.parent)}")
        say(f"    cp {shell_quote(source)} {shell_quote(flatpak_copy)}")
    elif flatpak_copy:
        step("Copying the stylesheet for the Quassel Flatpak")
        say("(The Flatpak can't see files outside its own folder, so it gets a copy.)")
        make_folders(flatpak_copy.parent)
        flatpak_copy.unlink(missing_ok=True)
        shutil.copy(source, flatpak_copy)
        say(f"Copied {source} to {flatpak_copy}")

    step("Done! To turn the stylesheet on:")
    say("1. In Quassel, open Settings -> Configure Quassel... -> Interface.")
    say('2. Check "Use custom stylesheet" and choose')
    say(f"   {stylesheets}/{file}")
    if flatpak_copy:
        say(f"   (or, in the Flatpak, {flatpak_copy})")
    say("3. Click OK; the colors change right away.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart Quassel.")
    if flatpak_copy:
        say(f"The Flatpak's copy doesn't update itself: run {state.COMMAND} again for it.")


APP = App(
    id="quassel",
    label="Quassel IRC",
    category="communication",
    templates=(
        ("app-themes/quassel-theme/stylesheet.qss.tmpl",
         "app-themes/quassel-theme/jenerated-{slug}.qss"),
    ),
    words=("irc", "chat", "messaging", "quasselclient"),
    commands=("quasselclient", "quassel"),
    flatpaks=("org.quassel_irc.QuasselClient",),
    mac_apps=("Quassel Client", "Quassel"),
    install=install,
)
