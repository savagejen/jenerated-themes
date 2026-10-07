"""Caido (web security testing)."""

from .. import paths, state
from ..system import copy_file_to_clipboard, has_match
from ..ui import say, step
from . import App


def install(theme):
    """Caido keeps its custom CSS in its own settings, so it's pasted in."""
    file = paths.app_themes(f"caido-theme/jenerated-{theme.slug}.css")
    appearance = "Light" if has_match(file, "color-scheme: light;") else "Dark"

    step("Your Caido CSS")
    say(f"It's in {file}")
    if copy_file_to_clipboard(file):
        say("(Copied to your clipboard.)")
    else:
        say("Open that file and copy everything in it.")

    step("Done! To turn the theme on (Caido is themed from inside the app):")
    say("1. In Caido, click your account button at the top right and choose")
    say("   Settings, then open the Appearance tab.")
    say(f"2. Choose the {appearance} appearance, to match the palette.")
    say("3. Open Custom CSS, paste the CSS in, replacing anything there, and save.")
    say(f"After changing the palette, run {state.COMMAND} again and paste the new CSS.")


APP = App(
    id="caido",
    label="Caido (web security testing)",
    category="hacking",
    templates=(
        ("app-themes/caido-theme/theme.css.tmpl", "app-themes/caido-theme/jenerated-{slug}.css"),
    ),
    words=("proxy", "burp", "pentest", "pentesting", "web", "security", "http", "intercept"),
    manual=True,
    install=install,
)
