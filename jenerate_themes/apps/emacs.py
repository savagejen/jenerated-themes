"""Emacs."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def emacs_dir():
    """Emacs's own folder, chosen the way Emacs chooses it: ~/.emacs.d if it
    (or a ~/.emacs file) exists, otherwise ~/.config/emacs if that exists, and
    otherwise ~/.emacs.d."""
    xdg = folder_from_env("XDG_CONFIG_HOME", HOME / ".config") / "emacs"
    if (HOME / ".emacs.d").exists() or (HOME / ".emacs").exists():
        return HOME / ".emacs.d"
    if xdg.exists():
        return xdg
    return HOME / ".emacs.d"


def install(theme):
    file = f"jenerated-{theme.slug}-theme.el"

    # Emacs looks for themes in its own folder, so nothing else needs setting.
    plan_link(emacs_dir() / file, paths.app_themes(f"emacs-theme/{file}"))
    run_install_plan("the Emacs theme")

    step("Done! To turn the theme on, in Emacs:")
    say(f"1. Run M-x load-theme RET jenerated-{theme.slug} RET. Emacs asks whether to")
    say("   trust the theme's code first; say yes (and yes to treating it as")
    say("   safe, so it doesn't ask again).")
    say(f"2. To keep it, run M-x customize-themes, tick jenerated-{theme.slug} (and")
    say("   untick any other theme), and choose Save Theme Settings.")
    say(f"After changing the palette, run {state.regenerate(theme.slug)} and load the theme")
    say("again.")


APP = App(
    id="emacs",
    label="Emacs",
    category="editors",
    templates=(
        ("app-themes/emacs-theme/theme.el.tmpl",
         "app-themes/emacs-theme/jenerated-{slug}-theme.el"),
    ),
    words=("gnu", "doom", "spacemacs"),
    commands=("emacs",),
    flatpaks=("org.gnu.emacs",),
    mac_apps=("Emacs",),
    install=install,
)
