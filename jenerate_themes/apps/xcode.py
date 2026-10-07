"""Xcode."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME
from ..ui import say, step
from . import App


def install(theme):
    themes = HOME / "Library/Developer/Xcode/UserData/FontAndColorThemes"

    # Xcode lists a theme by its file name, so the link is named after the
    # palette rather than its slug.
    plan_link(themes / f"Jenerated {theme.name}.xccolortheme",
              paths.app_themes(f"xcode-theme/jenerated-{theme.slug}.xccolortheme"))
    run_install_plan("the Xcode theme")

    step("Done! To turn the theme on:")
    say("1. Quit Xcode if it's open, and open it again (it finds new themes when")
    say("   it starts).")
    say("2. Open Xcode -> Settings (Preferences in older versions) -> Themes, and")
    say(f'   choose "Jenerated {theme.name}".')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart Xcode.")


APP = App(
    id="xcode",
    label="Xcode",
    category="editors",
    templates=(
        ("app-themes/xcode-theme/theme.xccolortheme.tmpl",
         "app-themes/xcode-theme/jenerated-{slug}.xccolortheme"),
    ),
    words=("apple", "swift"),
    mac_apps=("Xcode",),
    system="Darwin",
    install=install,
)
