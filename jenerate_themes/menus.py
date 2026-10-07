"""The menus: choosing an app and a palette, then generating and installing
its theme. This is what `jenerate` (or ./setup.sh) runs with no subcommand."""

import signal
import sys
from dataclasses import dataclass

from . import state
from .apps import APPS, CATEGORIES, app_present, find_app, other_system
from .errors import JenerateError
from .palettes import palette_files, palette_scheme, read_palette_file
from .render import add
from .system import HOME, open_url, status_of
from .ui import (BACK, Search, choose, choose_or_back, confirm, out, read_line, say, step, stop,
                 wrap_at_spaces)
from .vscode import write_vscode_package

# What pick_app, pick_palette and find_palette return for ALL THE APPS or
# ALL THE PALETTES, in place of one app or palette.
ALL = "all"


@dataclass
class Palette:
    """A palette, as the menus list it. An app's install(theme) gets one, for
    its name and slug."""
    name: str
    slug: str
    scheme: str


# --- The Palette Creator -----------------------------------------------------


def start_palette_creator():
    """Explains the Palette Creator, then runs its server until Ctrl+C, and
    exits when it stops. If this folder's Palette Creator is already running,
    serve.py asks whether to open it or start a fresh one; Back there
    (serve.py's exit status 3) returns here, so the first menu can be shown
    again."""
    step("Starting the Palette Creator")
    say("It opens in your browser. If it doesn't, open the address printed below.")
    say("")
    say("1. The page starts with your work-in-progress palette")
    say("   (palette-creator/work-in-progress-palette.toml; the first time, a copy")
    say('   of Blue Purple). To begin from another palette, use "Load from...".')
    say("2. Give it a name and a slug (lowercase words and dashes, like deep-blue-sea).")
    say("3. Change colors with the color pickers, or type #rrggbb or another")
    say("   color's name. The preview updates as you go; hover a color to see")
    say("   where it's used, or click the preview to find a color.")
    say('4. Your draft saves itself as you go. "Save as palette..." opens a save')
    say("   dialog in palettes/Dark or palettes/Light, to match the palette; keep")
    say(f"   the suggested name, <slug>-palette.toml, so jenerate.py and {state.COMMAND}")
    say("   can find it.")
    say(f"5. When you're done, press Ctrl+C here to stop it, then run {state.COMMAND}")
    say('   again and choose "Install a theme": your palette will be listed.')
    say("")
    # Ctrl+C is for serve.py: it stops the server and exits. This waits for it
    # instead of stopping too.
    previous = signal.signal(signal.SIGINT, signal.SIG_IGN)
    try:
        status = status_of([sys.executable, "-m", "jenerate_themes.creator.serve"],
                           preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    finally:
        signal.signal(signal.SIGINT, previous)
    if status == 3:
        return
    raise SystemExit(status if status >= 0 else 128 - status)


# --- Choosing an app ---------------------------------------------------------


class AppMenus:
    """The app menus: the main one, a category's, and search results. They
    stay on the menu an app was chosen from, so Back from the palette
    questions returns there."""

    def __init__(self):
        # The menu showing: "" for the main one, a category's id, or a
        # Search for its results.
        self.menu = ""

    def pick(self):
        """Shows the app menus until an app is chosen: returns its id (ALL
        for ALL THE APPS), or None for Back from the main menu."""
        while True:
            if not self.menu:
                labels, targets = self.main_menu()
                choice = choose_or_back("Which app do you want to theme?", True, *labels)
            elif isinstance(self.menu, Search):
                labels, targets = self.search_results(self.menu.text)
                if not labels:
                    say("")
                    say(f'No app matches "{self.menu.text}".')
                    self.menu = ""
                    continue
                choice = choose_or_back(f'Apps matching "{self.menu.text}":', True, *labels)
            else:
                apps = [app for app in APPS if app.category == self.menu]
                labels, targets = [app.label for app in apps], [app.id for app in apps]
                choice = choose_or_back(f"{CATEGORIES[self.menu]}:", True, *labels)

            if choice == BACK:
                # Back from a category or search goes to the main app menu;
                # from the main app menu, out of pick.
                if not self.menu:
                    return None
                self.menu = ""
            elif isinstance(choice, Search):
                self.menu = choice
            else:
                target = targets[choice]
                if isinstance(target, Category):
                    self.menu = target.id
                elif target is ASK_SEARCH:
                    say("")
                    out("Type part of an app's name (or press Enter to go back): ")
                    text = read_line()
                    if text is None:
                        stop("no choice made")
                    if text:
                        self.menu = Search(text)
                else:
                    return target

    @staticmethod
    def main_menu():
        """The main app menu's labels and what each leads to: the categories
        that have apps (on this system), then the apps in no category, then
        ALL THE APPS and search."""
        labels, targets = [], []
        for category, name in CATEGORIES.items():
            count = sum(1 for app in APPS if app.category == category)
            if count:
                labels.append(f"{name} (1 app)" if count == 1 else f"{name} ({count} apps)")
                targets.append(Category(category))
        for app in APPS:
            if not app.category:
                labels.append(app.label)
                targets.append(app.id)
        labels += ["ALL THE APPS", "Search for an app by name"]
        targets += [ALL, ASK_SEARCH]
        return labels, targets

    @staticmethod
    def search_results(text):
        """The labels and ids of the apps matching a search. Apps whose name or
        id matches come first (searching "wireshark" puts Wireshark itself
        before a theme that covers it), then apps matching by the apps they
        cover, their other words, or their category's name. Here the list of
        apps a theme covers helps, so it's shown under the label, wrapped and
        indented to line up with it."""
        query = text.lower()
        by_name = [app for app in APPS if query in f"{app.label} {app.id}".lower()]
        by_other = [app for app in APPS if app not in by_name and query in
                    " ".join([app.covers, *app.words, CATEGORIES.get(app.category, "")]).lower()]
        labels = []
        for app in by_name + by_other:
            if app.covers:
                covers = wrap_at_spaces(f"Covers: {app.covers}", 70)
                indented = "\n".join("     " + line for line in covers.split("\n"))
                labels.append(f"{app.label}\n{indented}")
            else:
                labels.append(app.label)
        return labels, [app.id for app in by_name + by_other]


@dataclass(frozen=True)
class Category:
    """A main menu entry that opens a category's menu."""
    id: str


# The main menu entry that asks what to search for.
ASK_SEARCH = object()


def app_label(app_id):
    """The app's name in the menus, or "" for an app that isn't offered."""
    app = find_app(app_id)
    return app.label if app else ""


# --- Choosing a palette ------------------------------------------------------


def load_palettes():
    """The palettes, dark then light, each group in order of file name, as
    `jenerate list` shows them. Stops, naming the problem, at a palette it
    can't read."""
    found = {"dark": [], "light": []}
    try:
        for path in palette_files():
            data = read_palette_file(path)
            scheme = palette_scheme(path)
            found[scheme].append(Palette(data["name"], data["slug"], scheme))
    except JenerateError as error:
        sys.stderr.write(f"{error}\n")
        stop(f"fix the palette named above, then run {state.COMMAND} again")
    palettes = found["dark"] + found["light"]
    if not palettes:
        stop("no palettes found in palettes/Dark or palettes/Light")
    return palettes


# Where the palettes' previews are, for the Preview option.
PREVIEW_URL = "https://github.com/savagejen/jenerated-themes/blob/main/palettes/README.md"


def pick_palette(palettes, app_id):
    """Asks whether you want a dark or light theme (when there are palettes of
    both), then which palette of those. Returns the chosen Palette, or ALL for
    ALL THE PALETTES (offered with the dark or light question, for an app
    that keeps palettes side by side), or None if you went back past the
    first question. Back from the palette list goes back to dark or light.
    Preview opens the palettes' previews in the browser and asks again."""
    schemes = {palette.scheme for palette in palettes}
    while True:
        scheme = ""
        if schemes == {"dark", "light"}:
            options = ["Dark", "Light"]
            if not all_palettes_refusal(app_id):
                options.append("ALL THE PALETTES")
            options.append("Preview the palettes (opens in your browser)")
            choice = choose_or_back("Do you want a dark or light theme?", False, *options)
            if choice == BACK:
                return None
            chosen = options[choice]
            if chosen == "ALL THE PALETTES":
                return ALL
            if chosen.startswith("Preview"):
                if open_url(PREVIEW_URL):
                    say("Opening the palette previews in your browser:")
                else:
                    say("Open the palette previews in your browser:")
                say(f"  {PREVIEW_URL}")
                continue
            scheme = chosen.lower()
        shown = [palette for palette in palettes if not scheme or palette.scheme == scheme]
        choice = choose_or_back("Which theme do you want?", False,
                                *(palette.name for palette in shown))
        if choice != BACK:
            return shown[choice]
        if not scheme:
            return None


def all_palettes_refusal(app_id):
    """Why ALL THE PALETTES isn't offered for the app (or for ALL THE APPS),
    or "" if it is."""
    if app_id == ALL:
        return "ALL THE APPS and ALL THE PALETTES don't go together: choose one palette, or one app"
    app = find_app(app_id)
    if app and app.manual:
        return f"{app.label} is themed by hand, one palette at a time"
    if app and app.one_palette:
        return f"{app.label} uses one palette at a time"
    return ""


def confirm_all_the_apps(palette):
    """Says which apps ALL THE APPS will install the palette into, with no
    more questions, and asks to go ahead (no by default). Returns the ids of
    those apps, or None if there are none, or you said no."""
    found = [app for app in APPS if not app.manual and app_present(app)]
    missing = [app for app in APPS if not app.manual and app not in found]
    manual = [app for app in APPS if app.manual]
    step("ALL THE APPS")
    if not found:
        say("None of the apps it can install into by itself were found on this")
        say(f"computer. Run {state.COMMAND} again and choose an app on its own.")
        return None
    say(f"This installs Jenerated {palette.name} into all {len(found)} of these apps, with no")
    say("more questions: each question an install would ask gets its first answer.")
    say("Files are linked to this folder, older installs of these themes are")
    say("replaced, settings files (like ~/.bashrc, ~/.tmux.conf and ~/.zshrc) get a")
    say("line that loads the colors, and apps that can switch to the theme right")
    say("away do.")
    say("")
    for app in found:
        say(f"  - {app.label}")
    if missing:
        say("")
        say("These weren't found on this computer, so they're left out:")
        say("")
        for app in missing:
            say(f"  - {app.label}")
    if manual:
        say("")
        say(f"Manual installs aren't included. Run {state.COMMAND} again and choose each")
        say("of these on its own:")
        say("")
        for app in manual:
            say(f"  - {app.label}")
    say("")
    if not confirm(f"Install into all {len(found)} apps?"):
        return None
    return [app.id for app in found]


def confirm_all_the_palettes(app_id, palettes):
    """Says ALL THE PALETTES will install every palette into the app, with no
    more questions, and asks to go ahead (no by default)."""
    step("ALL THE PALETTES")
    say(f"This installs all {len(palettes)} palettes into {app_label(app_id)}, with no more")
    say("questions: each question the install would ask gets its first answer.")
    say("Files are linked to this folder, and older installs of these themes are")
    say("replaced. Then choose among the themes in the app.")
    say("")
    return confirm(f"Install all {len(palettes)} palettes?")


# --- Naming an app and a palette up front (jenerate install) ----------------


def check_app(app_id):
    """Stops, listing the apps, unless app_id is an app offered on this
    system or ALL (ALL THE APPS)."""
    if app_id == ALL or find_app(app_id):
        return
    system = other_system(app_id)
    if system:
        stop(f"{app_id} is only offered on {system}")
    ids = wrap_at_spaces("".join(f"{app.id}, " for app in APPS), 76)
    stop(f'no app called "{app_id}". The apps are:\n{ids}\nor all, for ALL THE APPS')


def find_palette(slug, palettes):
    """The palette with this slug, or ALL (ALL THE PALETTES); stops, listing
    the palettes, for any other slug."""
    if slug == ALL:
        return ALL
    for palette in palettes:
        if palette.slug == slug:
            return palette
    stop(f'no palette called "{slug}". The palettes are:\n'
        f'{wrap_at_spaces("".join(f"{palette.slug}, " for palette in palettes), 76)}\n'
        "or all, for ALL THE PALETTES")


# --- Installing --------------------------------------------------------------


def install_app(app_id, theme):
    """Installs the theme into one app."""
    find_app(app_id).install(theme)


def install_alone(app_id, theme):
    """Installs the theme into one app as part of ALL THE APPS or ALL THE
    PALETTES: with its questions answering themselves, and on its own, so an
    install that stops with an error only stops itself, and nothing it set
    carries into the next. Returns its exit status."""
    with state.separate_install(auto=True):
        try:
            install_app(app_id, theme)
        except SystemExit as exited:
            # stop(), which has said why.
            return exited.code if isinstance(exited.code, int) else 1
        except (JenerateError, OSError) as error:
            sys.stderr.write(f"{error}\n")
            return 1
    return 0


def report(finished, failed, skipped=(), missing=()):
    """The end of ALL THE APPS or ALL THE PALETTES: what was installed, what
    wasn't (any that stopped with an error, then the manual installs ALL THE
    APPS leaves out), and the apps not found on this computer, apart, since
    there's nothing to do for them. Exits with status 1 if any install
    failed."""
    if finished:
        for label in finished:
            say(f"  - {label}")
    else:
        say("  (none)")
    not_installed = list(failed) + list(skipped)
    if not_installed:
        say("")
        say("Not installed:")
        for label in not_installed:
            say(f"  - {label}")
        say("")
        say(f"These may need to be done by hand. Run {state.COMMAND} again and choose each")
        say("one on its own; it explains what to do (any errors are above, too).")
    if missing:
        say("")
        say("Not found on this computer, so left out:")
        for label in missing:
            say(f"  - {label}")
    if failed:
        raise SystemExit(1)


def install_all_the_apps(app_ids, palette):
    """ALL THE APPS: installs the palette into each app, then reports."""
    finished, failed = [], []
    for n, app_id in enumerate(app_ids, 1):
        label = app_label(app_id)
        step(f"ALL THE APPS: {label} ({n} of {len(app_ids)})")
        (finished if install_alone(app_id, palette) == 0 else failed).append(label)
    step("ALL THE APPS: done")
    say(f"Installed Jenerated {palette.name} into:")
    report(finished, failed,
           skipped=[app.label for app in APPS if app.manual],
           missing=[app.label for app in APPS if not app.manual and app.id not in app_ids])


def install_all_the_palettes(app_id, palettes):
    """ALL THE PALETTES: installs each palette into the app, then reports."""
    finished, failed = [], []
    for n, palette in enumerate(palettes, 1):
        step(f"ALL THE PALETTES: {palette.name} ({n} of {len(palettes)})")
        (finished if install_alone(app_id, palette) == 0 else failed).append(palette.name)
    step("ALL THE PALETTES: done")
    say(f"Installed into {app_label(app_id)}:")
    report(finished, failed)


# --- The whole run -----------------------------------------------------------


def run(want_app="", want_palette="", design=False):
    """Shows the menus and installs what's chosen. want_app and want_palette
    (from `jenerate install`) skip their menus the first time; design starts
    the Palette Creator instead."""
    if HOME is None and not design:
        stop("HOME isn't set, so there's no home folder to install themes into. "
            "Set it to yours (like export HOME=/home/you), then run "
            f"{state.COMMAND} again.")
    if want_app:
        check_app(want_app)
    if want_palette:
        want_palette = find_palette(want_palette, load_palettes())
        if want_app and want_palette == ALL:
            refusal = all_palettes_refusal(want_app)
            if refusal:
                stop(refusal)
    skip_first_menu = bool(want_app or want_palette)

    say("Jenerated Themes setup")
    say("======================")

    if design:
        # Back, at the question about a Palette Creator that's already
        # running, ends here: there's no menu to go back to.
        start_palette_creator()
        return

    # Each menu's Back goes to the one before it: the theme menu back to the
    # app menus, and the main app menu back to this first question. Naming an
    # app or palette starts past the first question.
    while True:
        if not skip_first_menu:
            if choose("What would you like to do?",
                      "Install a theme for an app",
                      "Design a new palette (opens the Palette Creator)") == 1:
                start_palette_creator()
                continue
        skip_first_menu = False

        menus = AppMenus()
        app_id = palette = None
        while True:
            if want_app:
                app_id, want_app = want_app, ""
            else:
                app_id = menus.pick()
                if app_id is None:
                    break
            palettes = load_palettes()
            if want_palette:
                refusal = all_palettes_refusal(app_id)
                if want_palette == ALL and refusal:
                    say("")
                    say(f"{refusal}. Choose another app.")
                    continue
                palette = want_palette
                break
            palette = pick_palette(palettes, app_id)
            if palette is not None:
                break

        # Saying no to ALL THE APPS or ALL THE PALETTES goes back to this
        # menu.
        if palette is not None:
            if app_id == ALL:
                found = confirm_all_the_apps(palette)
                if found is not None:
                    break
            elif palette == ALL:
                if confirm_all_the_palettes(app_id, palettes):
                    break
            else:
                break
        # From the first menu on, the palette named up front is chosen from
        # the menus too.
        want_palette = ""

    # The palettes to install: one, or every one for ALL THE PALETTES.
    themes = palettes if palette == ALL else [palette]
    if len(themes) > 1:
        step(f"Generating all {len(themes)} themes")
    else:
        step(f"Generating the {themes[0].name} theme")
    add([theme.slug for theme in themes])
    write_vscode_package()

    if app_id == ALL:
        install_all_the_apps(found, palette)
    elif palette == ALL:
        install_all_the_palettes(app_id, palettes)
    else:
        install_app(app_id, palette)

    if state.current.mode == "copy":
        say("")
        say(f"The files are copies, so after changing the palette, run {state.COMMAND}")
        say(f"again to copy the new ones ({state.generate()} alone only updates this folder).")
    say("")
    say(f"Run {state.COMMAND} again any time to theme another app or switch palettes.")
