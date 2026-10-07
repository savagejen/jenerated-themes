"""VS Code (and Code - OSS, VSCodium)."""

import os
import re

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, has_match, read_text, write_text
from ..ui import read_line, say, step, stop
from . import App


def vscode_extension_dirs():
    """The extensions folders of the VS Code family that are in use: VS
    Code's (~/.vscode), and Code - OSS's and VSCodium's (both ~/.vscode-oss),
    which each makes the first time it runs. With neither there, VS Code's."""
    dirs = []
    if (HOME / ".vscode").is_dir():
        dirs.append(HOME / ".vscode/extensions")
    if (HOME / ".vscode-oss").is_dir():
        dirs.append(HOME / ".vscode-oss/extensions")
    return dirs or [HOME / ".vscode/extensions"]


def install(theme):
    source = paths.app_themes("vs-code-theme")
    dirs = vscode_extension_dirs()

    for extensions in dirs:
        plan_link(extensions / "jenerated-themes", source)
    run_install_plan("the VS Code extension")

    for extensions in dirs:
        # A .vsix install of the same extension would clash with the link.
        for other in sorted(extensions.glob("local.jenerated-themes-*")):
            if not other.exists():
                continue
            say("")
            say(f"Note: you also have a packaged copy installed ({other.name}, in {extensions}).")
            say('Uninstall "Jenerated Themes" from the editor\'s Extensions view so the two '
                "don't clash.")

        # If the extension was ever uninstalled, VS Code lists it in .obsolete
        # and ignores it, even after it's reinstalled. VS Code rewrites that
        # file while it runs, so it has to be closed while we remove the entry.
        obsolete = extensions / ".obsolete"
        if state.current.mode != "manual" and obsolete.is_file() and has_match(obsolete,
                                                               r"local\.jenerated-themes"):
            say("")
            say(f"This extension is marked as uninstalled in {extensions},")
            say("which hides the theme.")
            # Fixing that waits for the editor to be closed, so it can't
            # happen by itself.
            if state.current.auto:
                stop(f"run {state.COMMAND} again and choose VS Code on its own, to fix that")
            say("Quit it completely (all windows), then press Enter to fix it.")
            if read_line() is None:
                stop(f"stopped before changing its files; run {state.COMMAND} again")
            text = read_text(obsolete)
            fixed = []
            for line in text.split("\n"):
                line = re.sub(r'"local\.jenerated-themes[^"]*":[a-z]*', "", line)
                line = re.sub(r",,*", ",", line)
                line = line.replace("{,", "{", 1).replace(",}", "}", 1)
                fixed.append(line)
            text = "\n".join(fixed)
            if "{}" in text.split("\n"):
                os.unlink(obsolete)
            else:
                write_text(obsolete, text)
            say("Fixed.")

    step("Done! To turn the theme on (in VS Code, Code - OSS or VSCodium):")
    say('1. Open (or reload) the editor: Command Palette -> "Developer: Reload Window".')
    say("2. Open the theme picker (Ctrl+K Ctrl+T, or Cmd+K Cmd+T on a Mac).")
    say(f'3. Choose "Jenerated {theme.name}".')
    if not (HOME / ".vscode-oss").is_dir():
        say("For Code - OSS or VSCodium, open it once first, so it makes its")
        say(f"~/.vscode-oss folder, then run {state.COMMAND} again.")


APP = App(
    id="vscode",
    label="VS Code (and Code - OSS, VSCodium)",
    category="editors",
    templates=(
        ("app-themes/vs-code-theme/themes/color-theme.json.tmpl", paths.VSCODE_THEME),
    ),
    covers="VS Code, Code - OSS, VSCodium",
    words=("visual", "studio", "code", "oss", "codium"),
    commands=("code", "code-oss", "codium"),
    flatpaks=("com.visualstudio.code", "com.vscodium.codium"),
    mac_apps=("Visual Studio Code", "VSCodium"),
    install=install,
)
