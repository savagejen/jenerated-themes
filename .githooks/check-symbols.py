#!/usr/bin/env python3
"""Lists file names and lines that have a forbidden symbol.

A character is fine if it is printable ASCII, a tab, a letter in any
language or an accent mark. Anything else (dashes, curly quotes, arrows,
emoji, invisible spaces, control characters like escape, bytes that aren't
UTF-8) is flagged. See "Symbols stay ASCII" in CONTRIBUTING.md.

A file or list that can't be read is listed too, and the script then exits
with status 1, so a check that couldn't run is never mistaken for a pass.

Usage:
  check-symbols.py        the files being committed, as staged (run by
                          .githooks/pre-commit)
  check-symbols.py --all  every file and folder under the current folder,
                          as it is on disk (run by tests/repo/)
"""

import os
import subprocess
import sys
import unicodedata

# The mode git gives a submodule (another repository, linked in at a fixed
# commit).
SUBMODULE_MODE = b"160000"


class Unreadable(Exception):
    """A file or list that couldn't be read."""


def is_allowed(ch):
    if ch == "\t":
        return True

    if ch.isascii():
        return ch.isprintable()

    # Reject characters that normalize to ASCII.
    if unicodedata.normalize("NFKC", ch).isascii():
        return False

    # Letters (category L) and accent marks (category M) are fine; anything
    # else is a symbol.
    return unicodedata.category(ch)[0] in "LM"


def has_symbol(text):
    return not all(is_allowed(ch) for ch in text)


def safe_to_print(name):
    """Return the name in a form that is safe to print. Characters that would
    be invisible, or that could mess up the terminal, are written out as
    their code instead, like <U+200B>."""
    result = []

    for ch in name:
        is_printable_ascii = " " <= ch <= "~"
        is_allowed_unicode = not ch.isascii() and is_allowed(ch)

        if is_printable_ascii or is_allowed_unicode:
            result.append(ch)
        else:
            result.append(f"<U+{ord(ch):04X}>")

    return "".join(result)


def run_git(*arguments):
    """Run a git command and return what it printed.

    If git fails, raise Unreadable with git's own error message, so the
    caller can say which file or list couldn't be read.
    """
    command = ["git", *arguments]
    result = subprocess.run(command, capture_output=True)

    if result.returncode == 0:
        return result.stdout

    error_message = result.stderr.decode("utf-8", errors="replace").strip()

    # git's message can be several lines long. Put it on one line so it fits
    # in the hook's list of problems.
    error_message = error_message.replace("\n", " ")

    # Some failures come with no message at all.
    if error_message == "":
        error_message = f"git exited with status {result.returncode}"

    raise Unreadable(error_message)


class FileToCheck:
    """One file or folder to check.

    name:     its path, as raw bytes (a file name doesn't have to be valid
              UTF-8, and a broken name still has to be reported)
    contents: what's in it, or None when there's nothing inside to check
              (a folder, a binary file or a submodule)
    problem:  why it couldn't be read, or None if it could
    """

    def __init__(self, name, contents=None, problem=None):
        self.name = name
        self.contents = contents
        self.problem = problem


def read_submodule_names():
    """Return the names of the staged submodules. A submodule has no contents
    of its own to check."""
    submodule_names = set()
    listing = run_git("ls-files", "--stage", "-z")

    for entry in listing.split(b"\0"):
        if entry == b"":
            continue

        # Each entry is "<mode> <object id> <stage>\t<name>".
        details, name = entry.split(b"\t", 1)
        mode = details.split(b" ")[0]

        if mode == SUBMODULE_MODE:
            submodule_names.add(name)

    return submodule_names


def list_staged_files():
    """Return each file being added or changed in this commit, as a
    FileToCheck holding its staged version (the one the commit will hold).

    Raises Unreadable if git can't list the files.
    """
    try:
        changes = run_git(
            "diff", "--cached",    # what's staged for the commit
            "-z",                  # names exactly as they are, each ending in a zero byte
            "--numstat",           # with line counts, which show which files are binary
            "--no-renames",        # a renamed file counts as a new one
            "--diff-filter=ACMT",  # added, copied, modified or changed type, not deleted
        )
        submodule_names = read_submodule_names()
    except Unreadable as error:
        raise Unreadable(f"git couldn't list the staged files: {error}")

    files = []

    for entry in changes.split(b"\0"):
        if entry == b"":
            continue

        # Each entry is "<lines added>\t<lines removed>\t<name>".
        lines_added, _lines_removed, name = entry.split(b"\t", 2)

        # git shows "-" instead of line counts for a binary file.
        is_binary = lines_added == b"-"
        is_submodule = name in submodule_names

        if is_binary or is_submodule:
            files.append(FileToCheck(name))
            continue

        # ":0:<name>" asks git for the staged version of the file.
        try:
            contents = run_git("cat-file", "blob", b":0:" + name)
            files.append(FileToCheck(name, contents=contents))
        except Unreadable as error:
            files.append(FileToCheck(name, problem=str(error)))

    return files


def list_all_files():
    """Return each file and folder under the current folder, except .git, as
    a FileToCheck holding what's on disk."""
    files = []

    for folder, subfolder_names, file_names in os.walk(b"."):
        # Taking .git out of this list stops os.walk from going into it.
        if b".git" in subfolder_names:
            subfolder_names.remove(b".git")

        for subfolder_name in subfolder_names:
            path = os.path.join(folder, subfolder_name)
            files.append(FileToCheck(os.path.relpath(path)))

        for file_name in file_names:
            path = os.path.join(folder, file_name)
            name = os.path.relpath(path)

            try:
                with open(path, "rb") as file:
                    contents = file.read()
            except OSError as error:
                files.append(FileToCheck(name, problem=error.strerror))
                continue

            # Like git, treat a file as binary if a zero byte shows up in its
            # first 8000 bytes.
            looks_binary = b"\0" in contents[:8000]

            if looks_binary:
                files.append(FileToCheck(name))
            else:
                files.append(FileToCheck(name, contents=contents))

    return files


def main():
    # Print letters in any language correctly, whatever language settings
    # the terminal has.
    sys.stdout.reconfigure(encoding="utf-8")

    arguments = sys.argv[1:]

    if arguments not in ([], ["--all"]):
        print("Usage: check-symbols.py [--all]", file=sys.stderr)
        sys.exit(2)

    try:
        if arguments == ["--all"]:
            files = list_all_files()
        else:
            files = list_staged_files()
    except Unreadable as error:
        print(f"  ({safe_to_print(str(error))})")
        sys.exit(1)

    any_unreadable = False

    for file in files:
        # Bytes that aren't valid UTF-8 become a replacement character, which
        # has_symbol() then flags.
        name = file.name.decode("utf-8", errors="replace")

        if has_symbol(name):
            print(f"  {safe_to_print(name)} (its name)")

        if file.problem is not None:
            print(f"  {safe_to_print(name)} (couldn't be read: {safe_to_print(file.problem)})")
            any_unreadable = True
            continue

        if file.contents is None:
            continue

        # Split on "\n" only: splitlines() also splits on other characters,
        # and the line numbers would no longer match an editor's.
        lines = file.contents.split(b"\n")

        for line_number, line in enumerate(lines, start=1):
            text = line.decode("utf-8", errors="replace")

            if has_symbol(text):
                print(f"  {safe_to_print(name)}:{line_number}")

    # A file that couldn't be read means the check didn't finish.
    if any_unreadable:
        sys.exit(1)


main()
