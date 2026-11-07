"""QTerminal (LXQt's and Kali's terminal)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def install(theme):
    """QTerminal's terminal (qtermwidget) reads Konsole's color scheme format,
    so it uses the KDE theme's Konsole scheme. It lists schemes by file name,
    so the link is named for the palette."""
    schemes = folder_from_env("XDG_DATA_HOME", HOME / ".local/share") / "qterminal/color-schemes"

    plan_link(schemes / f"Jenerated {theme.name}.colorscheme",
              paths.app_themes(f"kde-theme/{theme.slug}/Jenerated-{theme.slug}.colorscheme"))
    run_install_plan("the QTerminal color scheme")

    step("Done! To turn the colors on:")
    say("1. Close every QTerminal window, then open QTerminal again; it reads its")
    say("   color schemes when it starts.")
    say("2. Open File -> Preferences, and on the Appearance tab choose")
    say(f'   "Jenerated {theme.name}" as the Color scheme.')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart QTerminal.")


APP = App(
    id="qterminal",
    label="QTerminal (LXQt's and Kali's terminal)",
    category="terminal",
    words=("lxqt", "kali", "qtermwidget"),
    commands=("qterminal",),
    system="Linux",
    install=install,
)
