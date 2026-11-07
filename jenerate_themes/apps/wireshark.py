"""Wireshark (network analyzer)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def wireshark_config_dirs():
    """Wireshark's personal settings folders: ~/.wireshark if there is one (an
    older Wireshark made it, and Wireshark still uses it then), otherwise its
    config folder; and the Flatpak's."""
    if (HOME / ".wireshark").is_dir():
        dirs = [HOME / ".wireshark"]
    else:
        dirs = [folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "wireshark"]
    if (HOME / ".var/app/org.wireshark.Wireshark").is_dir():
        dirs.append(HOME / ".var/app/org.wireshark.Wireshark/config/wireshark")
    return dirs


def install(theme):
    """The coloring rules go in a Wireshark profile of their own, "Jenerated
    <name>", so your own rules (in the Default profile) are left alone, and
    each palette is a profile to switch to."""
    profile = f"Jenerated {theme.name}"

    for folder in wireshark_config_dirs():
        plan_link(folder / f"profiles/{profile}/colorfilters",
                  paths.app_themes(f"wireshark-theme/{theme.slug}/colorfilters"))
    run_install_plan("the Wireshark coloring rules")

    step("Done! To turn the colors on:")
    say("1. In Wireshark, right-click the profile name at the right end of the")
    say(f'   status bar ("Default" at first) and choose "Jenerated {theme.name}", or use')
    say("   Edit -> Configuration Profiles.")
    say("2. Check that View -> Colorize Packet List is on.")
    say("The profile holds just the coloring rules; Wireshark's other settings")
    say("start from their defaults in it.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and switch to the")
    say("profile again (or restart Wireshark).")


APP = App(
    id="wireshark",
    label="Wireshark (network analyzer)",
    category="hacking",
    templates=(
        ("app-themes/wireshark-theme/colorfilters.tmpl",
         "app-themes/wireshark-theme/{slug}/colorfilters"),
    ),
    words=("packets", "packet", "capture", "pcap", "network", "sniffer"),
    commands=("wireshark",),
    flatpaks=("org.wireshark.Wireshark",),
    mac_apps=("Wireshark",),
    install=install,
)
