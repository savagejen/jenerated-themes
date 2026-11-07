"""The jenerate command.

    jenerate                       menus: pick an app and a palette, and it
                                   generates the theme and installs it
    jenerate install APP PALETTE   install a theme, skipping the menus
    jenerate generate PALETTE...   generate palettes' themes
    jenerate remove PALETTE...     remove palettes' generated themes
    jenerate list                  list the palettes, marking generated ones
    jenerate contrast [PALETTE...] check palettes' text contrast
    jenerate design                start the Palette Creator
"""

import argparse
import os
import shutil
import sys
from pathlib import Path

from . import __version__, paths, state
from .errors import JenerateError
from .palettes import CONTRAST_TARGET, is_path, report_contrast
from .render import add, list_palettes, refresh_blue_purple, remove
from .system import current_folder
from .vscode import write_vscode_package


def command_name():
    """What to call the command in messages: JENERATE_COMMAND if the
    launcher set it (setup.sh sets ./setup.sh), jenerate if it was run from
    PATH, or the path it was started with (like ./jenerate). It works on the
    command as typed, with os.path: Path would turn ./jenerate into jenerate."""
    if os.environ.get("JENERATE_COMMAND"):
        return os.environ["JENERATE_COMMAND"]
    started = sys.argv[0]
    on_path = shutil.which(os.path.basename(started))
    if on_path and os.path.realpath(on_path) == os.path.realpath(started):
        return os.path.basename(started)
    return started


def repository(start_dir):
    """The repository's folder as you named it (keeping the links in its
    path), when the command was started from it, for paths.LINK_ROOT;
    otherwise paths.DATA. os.path.normpath takes .. as the shell does (Path
    keeps it)."""
    candidate = Path(os.path.normpath(os.path.join(start_dir, os.path.dirname(sys.argv[0]) or ".")))
    try:
        if candidate.samefile(paths.DATA):
            return candidate
    except OSError:
        pass
    return paths.DATA


def palette_names(values):
    """Palette names from the command line, where several can also be
    separated by commas. A palette given as a path is taken from the folder
    the command was started in."""
    names = [name.strip() for value in values for name in value.split(",") if name.strip()]
    return [str(Path(state.START_DIR, name)) if is_path(name) else name for name in names]


def parser():
    top = argparse.ArgumentParser(
        prog="jenerate",
        description="Jenerated Themes: generate app themes from color palettes, "
                    "and install them. With no command, it shows menus to pick an "
                    "app and a palette.")
    top.add_argument("--version", action="version", version=f"jenerate-themes {__version__}")
    commands = top.add_subparsers(dest="command", metavar="COMMAND")

    install = commands.add_parser(
        "install", help="install a theme, skipping the menus",
        description='Install a theme. APP is an app\'s id and PALETTE a palette\'s short name, '
                    'like "jenerate install vscode candy". Leave either out to choose it '
                    'from its menu (use --palette to name only the palette). "all" means '
                    'ALL THE APPS or ALL THE PALETTES. A name it doesn\'t know lists the '
                    'ones it does.')
    install.add_argument("app", nargs="?", default="", help="the app's id, or all")
    install.add_argument("palette", nargs="?", default="", help="the palette's short name, or all")
    install.add_argument("--palette", dest="palette_option", default="", metavar="PALETTE",
                         help="the palette, when choosing the app from the menus")

    generate = commands.add_parser(
        "generate", help="generate palettes' themes",
        epilog="Separate several palettes with commas or spaces.")
    generate.add_argument("palettes", nargs="+",
                          help="palettes' short names (e.g. blue-purple) or .toml paths")

    remove_ = commands.add_parser(
        "remove", help="remove palettes' generated themes (the palettes are kept)",
        epilog="Separate several palettes with commas or spaces.")
    remove_.add_argument("palettes", nargs="+", help="palettes' short names or .toml paths")

    commands.add_parser("list", help="list the palettes, marking the generated ones")

    contrast = commands.add_parser(
        "contrast", help=f"report text colors below the recommended contrast ({CONTRAST_TARGET}:1)")
    contrast.add_argument("palettes", nargs="*", help="palettes' short names or .toml paths (default: all)")

    commands.add_parser("design", help="start the Palette Creator, for designing a new palette")
    return top


def main(args=None):
    # Messages, prompts and errors come out in order, as they happen.
    sys.stdout.reconfigure(line_buffering=True)
    options = parser().parse_args(args)

    state.START_DIR = current_folder()
    state.COMMAND = command_name()
    if paths.DATA is None:
        sys.exit("HOME isn't set, so there's no folder to keep your themes in. Set it to "
                 f"yours (like export HOME=/home/you), then run {state.COMMAND} again.")
    if not paths.INSTALLED:
        # A clone works from the repository, as you named it.
        paths.LINK_ROOT = repository(state.START_DIR)
        os.chdir(paths.LINK_ROOT)
        os.environ["PWD"] = str(paths.LINK_ROOT)

    from . import menus  # the apps are loaded only when they're needed

    try:
        # After an upgrade, an installed copy's Blue Purple themes catch up
        # with the ones it comes with.
        if refresh_blue_purple():
            write_vscode_package()
        if options.command is None:
            menus.run()
        elif options.command == "install":
            palette = options.palette or options.palette_option
            if options.app == "" and palette == "":
                menus.run()
            else:
                menus.run(want_app=options.app, want_palette=palette)
        elif options.command == "design":
            menus.run(design=True)
        elif options.command == "generate":
            add(palette_names(options.palettes))
            write_vscode_package()
        elif options.command == "remove":
            remove(palette_names(options.palettes))
            write_vscode_package()
        elif options.command == "list":
            list_palettes()
        elif options.command == "contrast":
            report_contrast(palette_names(options.palettes))
    except KeyboardInterrupt:
        # Ctrl+C stops it without a traceback.
        raise SystemExit(130)
    except (JenerateError, OSError) as error:
        # A palette or template with a problem, or a file it couldn't read or
        # write, stops it, naming the problem.
        sys.stdout.flush()
        sys.stderr.write(f"{error}\n")
        raise SystemExit(1)
