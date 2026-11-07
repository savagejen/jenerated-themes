"""Jellyfin (media server)."""

from .. import paths, state
from ..system import copy_file_to_clipboard
from ..ui import say, step
from . import App


def install(theme):
    file = paths.app_themes(f"jellyfin-theme/jenerated-{theme.slug}.css")

    step("Your Jellyfin CSS")
    say(f"It's in {file}")
    if copy_file_to_clipboard(file):
        say("(Copied to your clipboard.)")
    else:
        say("Open that file and copy everything in it.")

    step("Done! To turn the theme on (Jellyfin is themed from inside the app):")
    say("For everyone on your server (as an administrator):")
    say("1. Open Dashboard -> Branding (Dashboard -> General in older versions).")
    say("2. Paste the CSS into Custom CSS code, replacing anything there, and")
    say("   save.")
    say("Or just for one device:")
    say("1. Open Settings -> Display.")
    say("2. Paste the CSS into the Custom CSS code box, and save.")
    say("Choose Jellyfin's Dark theme for a dark palette, or Light for a light one.")
    say(f"After changing the palette, run {state.COMMAND} again and paste the new CSS.")


APP = App(
    id="jellyfin",
    label="Jellyfin (media server)",
    category="entertainment",
    templates=(
        ("app-themes/jellyfin-theme/theme.css.tmpl",
         "app-themes/jellyfin-theme/jenerated-{slug}.css"),
    ),
    words=("media", "server", "movies", "tv", "streaming", "plex", "emby"),
    manual=True,
    install=install,
)
