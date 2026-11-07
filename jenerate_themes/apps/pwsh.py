"""PowerShell (pwsh)."""

from .. import paths, state
from ..install import install_link, load_colors_from
from ..system import HOME, folder_from_env, make_folders
from ..ui import say, step
from . import App


def install(theme):
    """PowerShell's profile (the same place on Linux and macOS) loads the
    colors from one file, so switching palettes just repoints the link."""
    config = folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "powershell"
    colors = config / "jenerated-colors.ps1"
    profile = config / "Microsoft.PowerShell_profile.ps1"

    step("Installing the PowerShell colors")
    make_folders(config)
    install_link(colors, paths.app_themes(f"pwsh-theme/jenerated-{theme.slug}.ps1"))

    # In PowerShell, $HOME is your home folder, so the line works wherever it
    # is.
    path = f"$HOME/{colors.relative_to(HOME)}" if colors.is_relative_to(HOME) else colors
    line = f'if (Test-Path "{path}") {{ . "{path}" }}'

    load_colors_from(profile, line,
                     "# PowerShell profile. The line below loads the Jenerated colors.")

    step(f"Done! Start a new PowerShell (pwsh) to see Jenerated {theme.name}.")
    say("The output colors need PowerShell 7.2 or later; the command line's work")
    say("in any version with PSReadLine.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and start pwsh again.")


APP = App(
    id="pwsh",
    label="PowerShell (pwsh)",
    category="terminal",
    templates=(
        ("app-themes/pwsh-theme/colors.ps1.tmpl", "app-themes/pwsh-theme/jenerated-{slug}.ps1"),
    ),
    covers="PSReadLine",
    words=("powershell", "pwsh", "psreadline", "psstyle"),
    commands=("pwsh",),
    one_palette=True,
    install=install,
)
