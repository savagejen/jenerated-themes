"""Obsidian."""

import re
from pathlib import Path

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, read_text
from ..ui import ask_yes, choose, out, read_line, say, step, stop
from . import App


def known_obsidian_vaults():
    """The vaults Obsidian knows about, from its vault list (obsidian.json),
    wherever this system's Obsidian keeps it."""
    vaults = set()
    for config in (HOME / ".config/obsidian/obsidian.json",
                   HOME / ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json",
                   HOME / "snap/obsidian/current/.config/obsidian/obsidian.json",
                   HOME / "Library/Application Support/obsidian/obsidian.json"):
        if config.is_file():
            vaults.update(re.findall(r'"path":"([^"]*)"', read_text(config)))
    return [Path(vault) for vault in sorted(vaults) if Path(vault).is_dir()]


def choose_obsidian_vault():
    """Asks which vault to theme, and returns its folder."""
    vaults = known_obsidian_vaults()

    vault = None
    if vaults:
        choice = choose("Which Obsidian vault? (themes are set per vault)", *vaults,
                        "Another folder (type its path)")
        if choice < len(vaults):
            vault = vaults[choice]
    if vault is None:
        # Typing a path can't happen by itself.
        if state.current.auto:
            stop(f"no Obsidian vault found; run {state.COMMAND} again and choose Obsidian on its "
                "own, to type its path")
        say("")
        out("Path to your vault folder: ")
        typed = read_line()
        if not typed:
            stop("no vault given")
        if typed == "~" or typed.startswith("~/"):
            typed = f"{HOME}{typed[1:]}"
        # A relative path is relative to where it was run, not the repo (an
        # absolute one replaces START_DIR).
        vault = Path(state.START_DIR, typed)

    if not vault.is_dir():
        stop(f"there's no folder at {vault}")
    if not (vault / ".obsidian").is_dir():
        say(f"{vault} has no .obsidian folder, so it may not be an Obsidian vault.")
        if not ask_yes("Use it anyway?"):
            stop("no vault chosen")
    return vault


def install(theme):
    vault = choose_obsidian_vault()
    themes = vault / ".obsidian/themes"

    # Obsidian names a theme after its folder, which must match the name in
    # its manifest.json.
    plan_link(themes / f"Jenerated {theme.name}", paths.app_themes(f"obsidian-theme/{theme.slug}"))
    run_install_plan("the Obsidian theme")

    step("Done! To turn the theme on:")
    say("1. In Obsidian, open Settings -> Appearance.")
    say(f'2. Under Themes, choose "Jenerated {theme.name}". If it isn\'t listed, click')
    say("   the reload button next to Themes, or restart Obsidian.")
    say(f"Themes are per vault; run {state.COMMAND} again for your other vaults.")


APP = App(
    id="obsidian",
    label="Obsidian",
    category="editors",
    templates=(
        ("app-themes/obsidian-theme/theme.css.tmpl", "app-themes/obsidian-theme/{slug}/theme.css"),
        ("app-themes/obsidian-theme/manifest.json.tmpl",
         "app-themes/obsidian-theme/{slug}/manifest.json"),
    ),
    words=("notes", "markdown"),
    commands=("obsidian",),
    flatpaks=("md.obsidian.Obsidian",),
    mac_apps=("Obsidian",),
    present=lambda: bool(known_obsidian_vaults()),
    install=install,
)
