"""Chromium browsers (Chrome, Brave, Edge, Opera and more)."""

from .. import paths, state
from ..ui import say, step
from . import App


def install(theme):
    folder = paths.app_themes(f"chromium-theme/{theme.slug}")

    # Browsers cache a theme in its folder when they load it; clear any old
    # cache so the new colors are used.
    (folder / "Cached Theme.pak").unlink(missing_ok=True)

    step(f"Done! The theme is ready in {folder}")
    say("To turn it on, in Chrome, Brave, Edge, Opera, Chromium or another")
    say("Chromium-based browser:")
    say("1. Open the browser's extensions page:")
    say("     chrome://extensions  (Chrome, Chromium)")
    say("     brave://extensions   (Brave)")
    say("     edge://extensions    (Edge)")
    say("     opera://extensions   (Opera)")
    say("2. Turn on Developer mode.")
    say('3. Click "Load unpacked" and choose the folder above. The theme applies')
    say("   right away.")
    say("The browser keeps loading the theme from that folder, so leave it there.")
    say(f"After changing the palette, run {state.COMMAND} again and load it again.")
    say("To go back to the browser's own look: Settings -> Appearance -> Theme ->")
    say("Reset to default.")


APP = App(
    id="chromium",
    label="Chromium browsers (Chrome, Brave, Edge, Opera and more)",
    category="browsers",
    templates=(
        ("app-themes/chromium-theme/manifest.json.tmpl",
         "app-themes/chromium-theme/{slug}/manifest.json"),
    ),
    covers="Google Chrome, Chromium, Brave, Microsoft Edge, Opera",
    manual=True,
    install=install,
)
