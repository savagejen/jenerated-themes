"""Veilamp (music player)."""

import os
from pathlib import Path

from .. import paths, state
from ..install import plan_link, run_install_plan, shell_quote
from ..system import HOME, OS, folder_from_env
from ..ui import say, step
from . import App


def veilamp_skins_dir():
    """Veilamp's skins folder: <data>/skins, where <data> is VEILAMP_DATA_DIR
    if set, or else Veilamp's data folder. Veilamp lists every folder there
    with a skin.json in it each time it starts, as it does the skin packages
    imported from its settings."""
    if os.environ.get("VEILAMP_DATA_DIR"):
        return Path(os.environ["VEILAMP_DATA_DIR"]) / "skins"
    if OS == "Darwin":
        return HOME / "Library/Application Support/com.veilamp.app/skins"
    return folder_from_env("XDG_DATA_HOME", HOME / ".local/share") / "com.veilamp.app/skins"


def install(theme):
    """The skin goes in as jenerated-<slug>, the folder Veilamp itself would
    make when importing it, so importing it from Veilamp later replaces it
    rather than adding a second copy."""
    skins = veilamp_skins_dir()

    plan_link(skins / f"jenerated-{theme.slug}", paths.app_themes(f"veilamp-theme/{theme.slug}"))
    run_install_plan("the Veilamp skin")

    step("Done! To turn the skin on:")
    say("1. Restart Veilamp if it's open; it looks for skins when it starts.")
    say(f'2. Open Settings -> Appearance and click the "Jenerated {theme.name}" skin.')
    say("   It's colors only, so it recolors the layout you're using: Modern,")
    say("   Circular, Sci-fi HUD or Neonwave. (Classic and LCARS keep their own")
    say("   colors.) For another of those layouts, click its skin first.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart Veilamp.")
    if state.current.mode == "link":
        say("Veilamp can't remove a linked skin itself (its remove button shows an")
        say(f"error); to remove it, delete {shell_quote(f'{skins}/jenerated-{theme.slug}')}")


APP = App(
    id="veilamp",
    label="Veilamp (music player)",
    category="entertainment",
    templates=(
        ("app-themes/veilamp-theme/theme.json.tmpl", "app-themes/veilamp-theme/{slug}/skin.json"),
    ),
    words=("music", "audio", "player", "winamp", "veilid"),
    commands=("veilamp",),
    mac_apps=("veilamp",),
    install=install,
)
