"""Mattermost."""

import re

from .. import paths, state
from ..system import copy_to_clipboard, read_text
from ..ui import say, step
from . import App


def install(theme):
    # One line, so it's easy to copy from the terminal too.
    text = re.sub(" +", " ",
                  read_text(paths.app_themes(f"mattermost-theme/{theme.slug}.json")).replace("\n",
                            "")).rstrip("\n")

    step("Your Mattermost theme")
    say("")
    say(text)
    say("")
    if copy_to_clipboard(text.encode("utf-8", "surrogateescape")):
        say("(Copied to your clipboard.)")

    step("Done! To turn the theme on (Mattermost keeps themes with your account):")
    say("1. In Mattermost, open Settings -> Display -> Theme, and choose Edit.")
    say("2. Choose Custom Theme, and paste the theme above into the box under")
    say('   "Copy and paste to share theme colors".')
    say("3. Choose Save.")
    say("It applies wherever you use Mattermost: the web, the desktop app and the")
    say(f"mobile apps. After changing the palette, run {state.COMMAND} again and paste")
    say("the new theme.")


APP = App(
    id="mattermost",
    label="Mattermost",
    category="communication",
    templates=(
        ("app-themes/mattermost-theme/theme.json.tmpl", "app-themes/mattermost-theme/{slug}.json"),
    ),
    words=("chat", "messaging"),
    manual=True,
    install=install,
)
