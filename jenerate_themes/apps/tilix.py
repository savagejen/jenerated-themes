"""Tilix (terminal)."""

from .. import paths
from ..install import plan_link, run_install_plan
from ..system import HOME
from ..ui import say, step
from . import App


def install(theme):
    schemes = HOME / ".config/tilix/schemes"

    # The jenerated- prefix keeps it from replacing a scheme of your own.
    plan_link(schemes / f"jenerated-{theme.slug}.json",
              paths.app_themes(f"tilix-theme/{theme.slug}.json"))
    run_install_plan("the Tilix color scheme")

    step("Done! To turn the color scheme on:")
    say("1. Close every Tilix window, then open Tilix again.")
    say("2. Open Preferences, choose your profile under Profiles, and on the")
    say(f'   Color tab choose "Jenerated {theme.name}" as the color scheme.')
    say("   Repeat for other profiles.")


APP = App(
    id="tilix",
    label="Tilix (terminal)",
    category="terminal",
    templates=(
        ("app-themes/tilix-theme/scheme.json.tmpl", "app-themes/tilix-theme/{slug}.json"),
    ),
    commands=("tilix",),
    flatpaks=("com.gexperts.Tilix",),
    system="Linux",
    install=install,
)
