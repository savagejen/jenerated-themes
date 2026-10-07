"""Qt apps outside KDE Plasma (qt5ct and qt6ct)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def install(theme):
    """qt5ct and qt6ct each read color schemes from their own colors folder,
    and list each by its file name, so the link is named for the palette. The
    schemes do nothing until Qt apps use qt5ct or qt6ct (QT_QPA_PLATFORMTHEME),
    which KDE Plasma's own Qt integration replaces, so they never change
    KDE."""
    source = paths.app_themes(f"qtct-theme/jenerated-{theme.slug}.conf")
    for tool in ("qt5ct", "qt6ct"):
        config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
        plan_link(config / f"{tool}/colors/Jenerated {theme.name}.conf", source)
    run_install_plan("the qt5ct and qt6ct color scheme")

    step("Done! To turn the colors on:")
    say("1. Qt apps use qt6ct (or qt5ct, for Qt 5 apps) when QT_QPA_PLATFORMTHEME")
    say("   is set to it. If yours isn't, add QT_QPA_PLATFORMTHEME=qt6ct to")
    say("   /etc/environment (or ~/.profile), and log out and back in. (On KDE")
    say("   Plasma, leave it unset and use the KDE Plasma theme instead.)")
    say("2. Open Qt6 Settings (qt6ct): on the Appearance tab, choose Fusion as the")
    say(f'   style, then Custom palette and "Jenerated {theme.name}", and Apply. Do the')
    say("   same in Qt5 Settings (qt5ct) for Qt 5 apps.")
    say("3. Restart your Qt apps.")
    say("Apps started with sudo (like Legion) use root's settings, not yours. To")
    say("color them too, set up qt6ct for root the same way (sudo qt6ct), with the")
    say("scheme copied into /root/.config/qt6ct/colors.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart your Qt apps.")


APP = App(
    id="qtct",
    label="Qt apps outside KDE Plasma (qt5ct and qt6ct)",
    category="desktop",
    templates=(
        ("app-themes/qtct-theme/colors.conf.tmpl", "app-themes/qtct-theme/jenerated-{slug}.conf"),
    ),
    covers="Legion, Wireshark, VLC, qBittorrent, KeePassXC and other Qt apps, on GNOME, Xfce and "
            "other desktops",
    words=("qt", "qt5", "qt6", "qt5ct", "qt6ct", "pyqt", "legion"),
    commands=("qt5ct", "qt6ct"),
    system="Linux",
    install=install,
)
