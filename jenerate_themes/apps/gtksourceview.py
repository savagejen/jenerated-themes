"""GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)."""

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env, has_match
from ..ui import say, step
from . import App


def install(theme):
    """Editors built on GtkSourceView read style schemes from a folder named
    after their GtkSourceView version, and the three versions in use each need
    their own file (see app-themes/gtksourceview-theme/README.md)."""
    data = folder_from_env("XDG_DATA_HOME", HOME / ".local/share")
    folder = paths.app_themes(f"gtksourceview-theme/{theme.slug}")
    file = f"jenerated-{theme.slug}.xml"
    # (folder-in-this-repo, styles-folder) pairs: GtkSourceView 3 and 4 (gedit
    # 46 and earlier, Xed, Pluma, Meld), 5 (GNOME Text Editor), and gedit 47
    # and later's own libgedit-gtksourceview.
    pairs = [
        ("gtksourceview-4", data / "gtksourceview-3.0/styles"),
        ("gtksourceview-4", data / "gtksourceview-4/styles"),
        ("gtksourceview-5", data / "gtksourceview-5/styles"),
        ("libgedit-gtksourceview-300", data / "libgedit-gtksourceview-300/styles"),
    ]
    # Apps installed through Flatpak keep their data in folders of their own.
    if (HOME / ".var/app/org.gnome.TextEditor").is_dir():
        pairs.append(("gtksourceview-5",
                      HOME / ".var/app/org.gnome.TextEditor/data/gtksourceview-5/styles"))
    if (HOME / ".var/app/org.gnome.gedit").is_dir():
        pairs.append(("libgedit-gtksourceview-300",
                      HOME / ".var/app/org.gnome.gedit/data/libgedit-gtksourceview-300/styles"))

    for version, styles in pairs:
        plan_link(styles / file, folder / f"{version}/{file}")
    run_install_plan("the style schemes")

    step(f'Done! Choose "Jenerated {theme.name}" as the color scheme in each editor:')
    say("- gedit: Preferences -> Font & Colors.")
    say("- GNOME Text Editor: the menu -> Preferences -> Style. It only lists")
    say("  schemes that match its own light or dark style, so for this palette")
    if has_match(folder / f"gtksourceview-5/{file}", '<property name="variant">light</property>'):
        say("  choose the light style first (the sun at the top of the menu).")
    else:
        say("  choose the dark style first (the moon at the top of the menu).")
    say("- Xed: Edit -> Preferences -> Theme.")
    say("- Pluma, Meld and other GtkSourceView editors: in their preferences,")
    say("  usually under fonts and colors.")
    say("Reopen editors that were already open. After changing the palette, run")
    say(f"{state.regenerate(theme.slug)} and reopen them.")


APP = App(
    id="gtksourceview",
    label="GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)",
    category="editors",
    templates=(
        ("app-themes/gtksourceview-theme/gtksourceview-4.xml.tmpl",
         "app-themes/gtksourceview-theme/{slug}/gtksourceview-4/jenerated-{slug}.xml"),
        ("app-themes/gtksourceview-theme/gtksourceview-5.xml.tmpl",
         "app-themes/gtksourceview-theme/{slug}/gtksourceview-5/jenerated-{slug}.xml"),
        ("app-themes/gtksourceview-theme/libgedit.xml.tmpl",
         "app-themes/gtksourceview-theme/{slug}/libgedit-gtksourceview-300/jenerated-{slug}.xml"),
    ),
    covers="gedit, GNOME Text Editor, Xed, Pluma, Meld",
    words=("gtksourceview",),
    commands=("gedit", "gnome-text-editor", "xed", "pluma", "meld"),
    flatpaks=("org.gnome.TextEditor", "org.gnome.gedit"),
    system="Linux",
    install=install,
)
