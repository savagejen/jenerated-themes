"""Vivaldi."""

from .. import paths, state
from ..system import zip_folder
from ..ui import say, step, stop
from . import App


def install(theme):
    folder = paths.app_themes(f"vivaldi-theme/{theme.slug}")
    theme_zip = paths.app_themes(f"vivaldi-theme/jenerated-{theme.slug}.zip")

    step("Packaging the Vivaldi theme")
    # Vivaldi imports a theme as a .zip holding its settings.json.
    if not zip_folder(folder, theme_zip):
        stop(f"couldn't make {theme_zip}; zip {folder}/settings.json by hand")
    say(f"Made {theme_zip}")

    step("Done! To turn the theme on:")
    say('1. In Vivaldi, open Settings -> Themes, and click "Import Theme..." at the')
    say("   bottom.")
    say(f"2. Choose {theme_zip}")
    say("3. Vivaldi previews the theme and asks whether to install it. Accept")
    say("   within 30 seconds, or the preview expires and nothing is installed.")
    say(f"After changing the palette, run {state.COMMAND} again and import the new .zip:")
    say("Vivaldi offers it as an update to the theme you installed.")


APP = App(
    id="vivaldi",
    label="Vivaldi",
    category="browsers",
    templates=(
        ("app-themes/vivaldi-theme/settings.json.tmpl",
         "app-themes/vivaldi-theme/{slug}/settings.json"),
    ),
    manual=True,
    install=install,
)
