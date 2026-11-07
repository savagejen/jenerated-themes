"""Ghidra (reverse engineering)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step, stop
from . import App


def ghidra_settings_dirs():
    """Ghidra's settings folders, one for each version that has run (the
    folder's name has the version in it): ghidra_<version> in ~/.config/ghidra
    on Linux (11.1 and later), in ~/Library/ghidra on macOS, and in the
    Flatpak's config folder, and .ghidra_<version> in ~/.ghidra from before
    11.1."""
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    places = [(config / "ghidra", "ghidra_*"), (HOME / "Library/ghidra", "ghidra_*"),
              (HOME / ".var/app/org.ghidra_sre.Ghidra/config/ghidra", "ghidra_*"),
              (HOME / ".ghidra", ".ghidra_*")]
    return [folder for parent, pattern in places for folder in sorted(parent.glob(pattern))
            if folder.is_dir()]


def install(theme):
    file = f"jenerated-{theme.slug}.theme"
    source = paths.app_themes(f"ghidra-theme/{file}")
    dirs = ghidra_settings_dirs()

    if not dirs:
        # Ghidra makes its settings folder the first time it runs, named for
        # its version, so there's nowhere to put the theme yet.
        if state.current.auto:
            stop("no Ghidra settings folder found; run Ghidra once, or run "
                f"{state.COMMAND} again and choose Ghidra on its own")
        step("No Ghidra settings folder found (Ghidra makes one the first time it runs).")
        say("To add the theme from Ghidra itself:")
        say("1. In Ghidra's project window, choose Edit -> Theme -> Import..., and")
        say(f"   choose {source}")
        say(f'2. Choose Edit -> Theme -> Switch..., and pick "Jenerated {theme.name}".')
        say("Importing copies the theme, so import it again after changing the palette.")
        return

    for folder in dirs:
        plan_link(folder / f"themes/{file}", source)
    run_install_plan("the Ghidra theme")

    step("Done! To turn the theme on:")
    say("1. Restart Ghidra if it's open; it reads its themes when it starts.")
    say("2. In the project window, choose Edit -> Theme -> Switch..., and pick")
    say(f'   "Jenerated {theme.name}".')
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and restart Ghidra.")


APP = App(
    id="ghidra",
    label="Ghidra (reverse engineering)",
    category="hacking",
    templates=(
        ("app-themes/ghidra-theme/theme.theme.tmpl",
         "app-themes/ghidra-theme/jenerated-{slug}.theme"),
    ),
    words=("reverse", "engineering", "disassembler", "decompiler", "binary", "nsa"),
    commands=("ghidra", "ghidraRun"),
    flatpaks=("org.ghidra_sre.Ghidra",),
    present=lambda: bool(ghidra_settings_dirs()),
    install=install,
)
