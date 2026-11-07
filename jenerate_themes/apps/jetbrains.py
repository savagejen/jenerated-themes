"""JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)."""

import fnmatch

from .. import paths, state
from ..install import plan_link, run_install_plan
from ..system import HOME, OS, folder_from_env, zip_folder
from ..ui import say, step, stop
from . import App


def jetbrains_plugin_dirs():
    """The plugins folders of the JetBrains IDEs that have run, one for each
    IDE and version, from its settings folder (named like IntelliJIdea2026.2
    or PyCharm2026.2; Android Studio's are under Google instead of JetBrains).
    On Linux the plugins folder is the same name under ~/.local/share; on
    macOS, a plugins folder inside the settings folder."""
    if OS == "Darwin":
        settings = HOME / "Library/Application Support"
    else:
        settings = folder_from_env("XDG_CONFIG_HOME", HOME / ".config")
    found = [folder for folder in [*sorted((settings / "JetBrains").glob("*")),
                                   *sorted((settings / "Google").glob("AndroidStudio*"))]
             if fnmatch.fnmatchcase(folder.name,
                                    "*[0-9][0-9][0-9][0-9].[0-9]*") and folder.is_dir()]
    if OS == "Darwin":
        return [folder / "plugins" for folder in found]
    data = folder_from_env("XDG_DATA_HOME", HOME / ".local/share")
    return [data / folder.parent.name / folder.name for folder in found]


def install(theme):
    folder = paths.app_themes(f"jetbrains-theme/{theme.slug}")
    jar = paths.app_themes(f"jetbrains-theme/jenerated-{theme.slug}.jar")

    step("Packaging the JetBrains theme")
    # The theme is a small plugin: its folder, zipped as a .jar.
    if not zip_folder(folder, jar):
        stop(f"couldn't make {jar}; zip the contents of {folder} by hand")
    say(f"Made {jar}")

    dirs = jetbrains_plugin_dirs()

    if not dirs:
        # An IDE makes its settings folder the first time it runs.
        if state.current.auto:
            stop("no JetBrains IDE has run yet; run one once, or run "
                f"{state.COMMAND} again and choose JetBrains Apps on its own")
        step("Done! To turn the theme on:")
        say("It works in the JetBrains apps built on the IntelliJ Platform (2023.1 or")
        say("later): IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand,")
        say("RubyMine, CLion, Rider, DataGrip, DataSpell and RustRover. (Not Fleet,")
        say("which has its own theme format.) In the app:")
        say("1. Open Settings -> Plugins, click the gear icon, and choose")
        say('   "Install Plugin from Disk...".')
        say(f"2. Choose {jar}")
        say("   and restart the app if it asks.")
        say("3. Open Settings -> Appearance & Behavior -> Appearance, and choose")
        say(f'   "Jenerated {theme.name}" as the theme. Its editor colors come with it.')
        say(f"(Or open the IDE once, and run {state.COMMAND} again to install it for you.)")
        say(f"After changing the palette, run {state.COMMAND} again and install the new .jar.")
        return

    # Each IDE loads the plugins in its plugins folder when it starts.
    for folder in dirs:
        plan_link(folder / f"jenerated-{theme.slug}.jar", jar)
    run_install_plan("the JetBrains theme plugin")

    step("Done! To turn the theme on, in each of those IDEs:")
    say("1. Restart the IDE; it loads new plugins when it starts.")
    say("2. Open Settings -> Appearance & Behavior -> Appearance, and choose")
    say(f'   "Jenerated {theme.name}" as the theme. Its editor colors come with it.')
    say(f"After changing the palette, run {state.COMMAND} again: it rebuilds the .jar.")


APP = App(
    id="jetbrains",
    label="JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)",
    category="editors",
    templates=(
        ("app-themes/jetbrains-theme/plugin.xml.tmpl",
         "app-themes/jetbrains-theme/{slug}/META-INF/plugin.xml"),
        ("app-themes/jetbrains-theme/theme-{scheme}.json.tmpl",
         "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.theme.json"),
        ("app-themes/jetbrains-theme/editor-scheme.xml.tmpl",
         "app-themes/jetbrains-theme/{slug}/jenerated-{slug}.xml"),
    ),
    covers="IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand, RubyMine, CLion, "
            "Rider, DataGrip, DataSpell, RustRover",
    present=lambda: bool(jetbrains_plugin_dirs()),
    install=install,
)
