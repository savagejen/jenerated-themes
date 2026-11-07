"""Talking to the person running it: messages, questions and menus. Output
is written straight away, so messages, errors and the output of commands it
runs come out in order."""

import os
import re
import sys
from dataclasses import dataclass

from . import state


def out(text):
    sys.stdout.write(text)
    sys.stdout.flush()


def say(*parts):
    out(" ".join(parts) + "\n")


def step(text):
    # When you chose to run the install commands yourself, nothing's done yet.
    if state.current.mode == "manual" and text.startswith("Done! "):
        text = text[len("Done! "):]
        text = "Once you've run the commands above, " + text[:1].lower() + text[1:]
    out(f"\n==> {text}\n")


def stop(message):
    sys.stdout.flush()
    sys.stderr.write(f"\nError: {message}\n")
    sys.stderr.flush()
    raise SystemExit(1)


def read_line():
    """One line typed in, without its surrounding spaces and tabs, or None at
    the end of input (a last line with no line break counts as the end). It
    reads one byte at a time, so typed input meant for a program it starts
    afterward (like the Palette Creator's questions) is left for that
    program."""
    data = b""
    while True:
        try:
            byte = os.read(0, 1)
        except OSError:
            return None
        if not byte:
            return None
        if byte == b"\n":
            return data.decode("utf-8", "surrogateescape").strip(" \t")
        data += byte


def ask_yes(question):
    """True for yes (the default), False for no."""
    out(f"{question} [Y/n] ")
    if state.current.auto:
        say("y (automatic)")
        return True
    reply = read_line()
    if reply is None:
        reply = "n"
    return reply[:1] not in ("n", "N")


def confirm(question):
    """True only for yes; no is the default, for questions where saying yes
    by accident would do a lot."""
    out(f"{question} [y/N] ")
    reply = read_line()
    if reply is None:
        reply = "n"
    return reply[:1] in ("y", "Y")


def choose(prompt, *options):
    """The chosen option's index (0-based)."""
    say("")
    say(prompt)
    for i, option in enumerate(options, 1):
        out(f"  {i}) {option}\n")
    if state.current.auto:
        out(f"Enter a number (1-{len(options)}): 1 (automatic)\n")
        return 0
    while True:
        out(f"Enter a number (1-{len(options)}): ")
        reply = read_line()
        if reply is None:
            stop("no choice made")
        if re.fullmatch(r"[0-9]+", reply) and 1 <= int(reply) <= len(options):
            return int(reply) - 1
        say(f"Please enter a number between 1 and {len(options)}.")


# What choose_or_back returns for 0) Back.
BACK = "back"


@dataclass(frozen=True)
class Search:
    """What choose_or_back returns when something other than a number was
    typed (with allow_search): the text to search for."""
    text: str


def choose_or_back(prompt, allow_search, *options):
    """Like choose, with "0) Back" under the options: the chosen option's
    index, or BACK. With allow_search, typing something other than a number
    gives a Search for it."""
    say("")
    say(prompt)
    for i, option in enumerate(options, 1):
        out(f"  {i}) {option}\n")
    say("  0) Back")
    while True:
        if allow_search:
            out(f"Enter a number (0-{len(options)}), or type part of an app's name to search: ")
        else:
            out(f"Enter a number (0-{len(options)}): ")
        reply = read_line()
        if reply is None:
            stop("no choice made")
        if reply == "0":
            return BACK
        if not re.fullmatch(r"[0-9]+", reply):
            if allow_search and reply:
                return Search(reply)
        elif 1 <= int(reply) <= len(options):
            return int(reply) - 1
        say(f"Please enter a number between 0 and {len(options)}.")


def wrap_at_spaces(text, width):
    """Wraps text at spaces into lines of at most width characters (breaking
    a word only if it's longer than a line), without spaces at their ends.
    Unlike textwrap, the space a line breaks at counts toward its width, so a
    line can break one character earlier; the menus are laid out that way."""
    lines = []
    while len(text) > width:
        space = text.rfind(" ", 0, width)
        cut = space + 1 if space >= 0 else width
        lines.append(text[:cut])
        text = text[cut:]
    lines.append(text)
    return "\n".join(line.rstrip(" ") for line in lines)
