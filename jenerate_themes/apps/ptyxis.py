"""Ptyxis (Ubuntu terminal)."""

from .. import paths
from ..install import plan_link, run_install_plan
from ..system import HOME
from ..ui import say, step
from . import App


def install(theme):
    palettes = HOME / ".local/share/org.gnome.Ptyxis/palettes"

    plan_link(palettes / f"{theme.slug}.palette",
              paths.app_themes(f"ptyxis-theme/{theme.slug}.palette"))
    run_install_plan("the Ptyxis palette")

    step("Done! To turn the palette on:")
    say("1. Close and reopen Ptyxis.")
    say(f'2. Open Preferences (Ctrl+,), and under Appearance choose "{theme.name}".')
    say("   It applies to the current profile; repeat for other profiles.")


APP = App(
    id="ptyxis",
    label="Ptyxis (Ubuntu terminal)",
    category="terminal",
    templates=(
        ("app-themes/ptyxis-theme/palette.tmpl", "app-themes/ptyxis-theme/{slug}.palette"),
    ),
    words=("gnome",),
    commands=("ptyxis",),
    flatpaks=("app.devsuite.Ptyxis",),
    system="Linux",
    install=install,
)
