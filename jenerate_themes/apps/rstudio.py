"""RStudio."""

import os
from pathlib import Path

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def install(theme):
    # RStudio's settings folder, on Linux and macOS alike.
    if os.environ.get("RSTUDIO_CONFIG_HOME"):
        themes = Path(os.environ["RSTUDIO_CONFIG_HOME"]) / "themes"
    else:
        themes = folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "rstudio/themes"

    plan_link(themes / f"jenerated-{theme.slug}.rstheme",
              paths.app_themes(f"rstudio-theme/jenerated-{theme.slug}.rstheme"))
    run_install_plan("the RStudio theme")

    step("Done! To turn the theme on, in RStudio:")
    say("1. Open Tools -> Global Options -> Appearance.")
    say(f'2. Choose "Jenerated {theme.name}" as the Editor theme, and Apply. (Restart')
    say("   RStudio first if it doesn't appear.)")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and choose the theme")
    say("again, or restart RStudio.")


APP = App(
    id="rstudio",
    label="RStudio",
    category="editors",
    templates=(
        ("app-themes/rstudio-theme/theme.rstheme.tmpl",
         "app-themes/rstudio-theme/jenerated-{slug}.rstheme"),
    ),
    words=("r", "posit", "rmarkdown", "quarto"),
    commands=("rstudio",),
    mac_apps=("RStudio",),
    install=install,
)
