"""GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)."""

import shutil
import subprocess

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env, output_of, status_of
from ..ui import ask_yes, say, step
from . import App


def gtk_theme_setting():
    """The GNOME setting for the GTK3 theme, or "" without gsettings."""
    if not shutil.which("gsettings"):
        return ""
    current = output_of(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                        stderr=subprocess.DEVNULL)
    return current or ""


def install(theme):
    themes = folder_from_env("XDG_DATA_HOME", HOME / ".local/share") / "themes"
    gtk_theme = f"Jenerated-{theme.slug}"

    plan_link(themes / gtk_theme, paths.app_themes(f"gtk3-theme/{theme.slug}"))
    run_install_plan("the GTK3 theme")

    current = gtk_theme_setting()
    if current and state.current.mode != "manual":
        say("")
        say(f"Your GTK3 theme is {current}.")
        if ask_yes(f"Switch every GTK3 app to {gtk_theme} now?"):
            status = status_of(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme",
                                gtk_theme])
            if status:
                raise SystemExit(status)
            step(f"Done! GTK3 apps use {gtk_theme} now (reopen any that were open).")
            say("To switch back:")
            say(f"    gsettings set org.gnome.desktop.interface gtk-theme {current}")
            return

    step("Done! To turn the theme on:")
    say("- For every GTK3 app on GNOME: in GNOME Tweaks, under Appearance, choose")
    say(f'  "{gtk_theme}" for Legacy Applications, or run')
    say(f"      gsettings set org.gnome.desktop.interface gtk-theme {gtk_theme}")
    say(f'- On Xfce: Settings -> Appearance -> Style -> "{gtk_theme}".')
    say(f"- To try it in one app: GTK_THEME={gtk_theme} gimp (or any GTK3 app).")


APP = App(
    id="gtk3",
    label="GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)",
    category="desktop",
    templates=(
        ("app-themes/gtk3-theme/gtk.css.tmpl", "app-themes/gtk3-theme/{slug}/gtk-3.0/gtk.css"),
        ("app-themes/gtk3-theme/index.theme.tmpl", "app-themes/gtk3-theme/{slug}/index.theme"),
    ),
    covers="GIMP, Inkscape, Shotwell, Thunar, Nemo, Caja, gedit, Mousepad, Geany, Meld, Pluma, "
            "Xed, GParted, Synaptic, dconf Editor, Virtual Machine Manager, Evolution, Remmina, "
            "Deluge, Rhythmbox, GNOME Terminal, and the Xfce, MATE and Cinnamon desktops' own apps",
    libraries=("libgtk-3.so.0",),
    system="Linux",
    one_palette=True,
    install=install,
)
