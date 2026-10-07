"""Putting a theme's files in place: the install plan, which shows the
commands and offers to run them, linking or copying the files."""

import os
import re
from pathlib import Path

from . import state
from .system import HOME, append_lines, copy_path, has_line, make_folders, remove, write_text
from .ui import ask_yes, choose, say, step, stop


def install_link(target, source):
    """Links (or, with the install mode copy, copies) source to target,
    offering to replace anything already at target."""
    target, source = Path(target), Path(source)
    if is_linked(target, source):
        say("Already installed (linked to this folder).")
        return
    if target.is_symlink() or target.exists():
        say(f"An older install exists at {target}.")
        if state.current.mode == "copy":
            question = "Replace it with a copy?"
        else:
            question = "Replace it with a link to this folder?"
        if not ask_yes(question):
            stop("left the existing install alone")
        remove(target)
    if state.current.mode != "copy":
        try:
            target.symlink_to(source, target_is_directory=source.is_dir())
            say(f"Linked {target} -> {source}")
            return
        except OSError as error:
            # Some systems only let some users make links; a copy still
            # works there.
            say(f"Couldn't make a link ({error.strerror or error}), so copying instead.")
            state.current.mode = "copy"
    copy_path(source, target)
    say(f"Copied {source} to {target}")


def is_linked(target, source):
    """True if target is a link to source."""
    return target.is_symlink() and os.readlink(target) == str(source)


def shell_quote(path):
    """The path in double quotes, ready to paste into a shell, with $HOME
    standing for your home folder."""
    path, home = str(path), ""
    if HOME and path.startswith(f"{HOME}/"):
        home = "$HOME"
        path = path[len(str(HOME)):]
    return '"' + home + re.sub(r'([\\"$`])', r"\\\1", path) + '"'


def plan_link(target, source):
    """Adds a file to install to the plan that run_install_plan shows and
    offers to run."""
    state.current.plan.append((Path(target), Path(source)))


def run_install_plan(what):
    """Shows the commands that install the planned files (what names them,
    like "the Tilix color scheme"), then offers to run them, linking or
    copying the files. Sets the install mode to link, copy, or manual if you'd
    rather run them yourself. Files already linked to this folder are left
    out, and if that's all of them, there's nothing to ask."""
    planned = [(target, source) for target, source in state.current.plan
               if not is_linked(target, source)]
    state.current.plan.clear()

    if not planned:
        step(f"Installing {what}")
        say("Already installed (linked to this folder).")
        state.current.mode = "link"
        return

    step(f"To install {what}, run:")
    dirs = []
    existing = False
    for target, _ in planned:
        if target.parent not in dirs:
            dirs.append(target.parent)
            say(f"    mkdir -p {shell_quote(target.parent)}")
        if target.is_symlink() or target.exists():
            existing = True
    for target, source in planned:
        say(f"    ln -s {shell_quote(source)} {shell_quote(target)}")
    say("Or, to copy the files instead of linking them:")
    for target, source in planned:
        say(f"    cp -R {shell_quote(source)} {shell_quote(target)}")
    if existing:
        say("(An older install is in the way; move it aside first.)")

    say("")
    if not ask_yes("Run these for you?"):
        state.current.mode = "manual"
        return
    choice = choose("Link or copy the files?",
                    "Link (recommended): they update by themselves when you change the palette",
                    f"Copy: they don't need this folder, but run {state.COMMAND} again after "
                    "changing the palette")
    state.current.mode = "link" if choice == 0 else "copy"

    step(f"Installing {what}")
    for target, source in planned:
        make_folders(target.parent)
        install_link(target, source)


def load_colors_from(conf, line, header):
    """Makes the settings file conf load the colors with line: creates it with
    header, or offers to add the line at its end."""
    if not Path(conf).exists():
        write_text(conf, f"{header}\n{line}\n")
        say(f"Created {conf}")
    elif has_line(conf, line):
        pass
    elif ask_yes(f"Load the colors at the end of {conf}? (Your settings in it are kept.)"):
        append_lines(conf, "# Colors from Jenerated Themes", line)
        say(f"Added the colors to {conf}")
    else:
        say(f"Left {conf} alone; add this line to the end of it to use the colors:")
        say(f"    {line}")
