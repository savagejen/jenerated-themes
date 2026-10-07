"""Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)."""

from .. import paths
from ..install import plan_link, run_install_plan
from ..system import HOME
from ..ui import say, step
from . import App


def install(theme):
    themes = HOME / "homebrew/themes"

    if not (HOME / "homebrew").is_dir():
        say("")
        say("Decky Loader isn't installed yet (there's no ~/homebrew folder), so the")
        say("theme will wait for it. Install Decky Loader from https://decky.xyz,")
        say("then CSS Loader from Decky's plugin store.")
    plan_link(themes / f"Jenerated-{theme.slug}", paths.app_themes(f"decky-theme/{theme.slug}"))
    run_install_plan("the CSS Loader theme")

    step("Done! To turn the theme on, in Gaming Mode:")
    say("1. Open the Quick Access menu (the ... button on a Steam Deck), then")
    say("   Decky's plug icon, and choose CSS Loader.")
    say("2. If CSS Loader was already running, scroll to the bottom and press")
    say("   Refresh so it finds the new theme.")
    say(f'3. Turn on "Jenerated {theme.name}".')
    say("CSS Loader reads the theme from this folder, so after changing the")
    say("palette, press Refresh again. To go back to Steam's own colors, turn the")
    say("theme off.")


APP = App(
    id="decky",
    label="Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)",
    category="desktop",
    templates=(
        ("app-themes/decky-theme/theme.json.tmpl", "app-themes/decky-theme/{slug}/theme.json"),
        ("app-themes/decky-theme/shared.css.tmpl", "app-themes/decky-theme/{slug}/shared.css"),
    ),
    words=("steam", "deck", "steamos", "bazzite", "cachyos", "css", "loader", "gaming", "mode"),
    present=lambda: (HOME / "homebrew/plugins").is_dir(),
    system="Linux",
    install=install,
)
