"""Slack."""

from .. import paths
from ..system import copy_to_clipboard, read_text
from ..ui import say, step
from . import App


def install(theme):
    text = read_text(paths.app_themes(f"slack-theme/{theme.slug}.txt")).replace("\n", "")

    step("Your Slack theme string")
    say("")
    say(f"    {text}")
    say("")
    if copy_to_clipboard(text.encode("utf-8", "surrogateescape")):
        say("(Copied to your clipboard.)")

    step("Done! To turn the theme on (Slack can't be themed from outside the app):")
    say("1. Paste the string above into any message box in Slack, such as a DM")
    say("   to yourself, and send it.")
    say('2. Click the "Switch sidebar theme" button that appears under it.')
    say("Slack themes are per workspace, so repeat this in each workspace.")


APP = App(
    id="slack",
    label="Slack",
    category="communication",
    templates=(
        ("app-themes/slack-theme/slack-theme.txt.tmpl", "app-themes/slack-theme/{slug}.txt"),
    ),
    words=("chat", "messaging"),
    manual=True,
    install=install,
)
