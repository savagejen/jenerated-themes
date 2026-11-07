"""The system it runs on: commands, files, the clipboard and the browser."""

import os
import re
import shutil
import subprocess
import zipfile
from pathlib import Path


def status_of(args, **kwargs):
    """Runs a command and returns its exit status: 127 if it isn't found, as
    the shell gives. Anything it writes goes where this script's output does,
    unless kwargs say otherwise."""
    try:
        return subprocess.run(args, **kwargs).returncode
    except OSError:
        return 127


def succeeds(args, **kwargs):
    """True if a command runs and succeeds, with its output hidden."""
    return status_of(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kwargs) == 0


def output_of(args, **kwargs):
    """A command's output, without the line breaks at its end, or None if it
    can't be run."""
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE, **kwargs)
    except OSError:
        return None
    return result.stdout.decode("utf-8", "surrogateescape").rstrip("\n")


def start_in_background(args):
    """Starts a command without waiting for it, with its output hidden."""
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def folder_from_env(name, default):
    """The folder the environment variable names, or default if the variable
    is unset or empty."""
    return Path(os.environ.get(name) or default)


def read_text(path):
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        return f.read()


def write_text(path, text, mode="w"):
    with open(path, mode, encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write(text)


def lines_of(path):
    """A file's lines, as grep sees them, or [] if it can't be read."""
    try:
        text = read_text(path)
    except OSError:
        return []
    lines = text.split("\n")
    return lines[:-1] if text.endswith("\n") or not text else lines


def has_line(path, line):
    """True if the file has a line that's exactly this."""
    return line in lines_of(path)


def has_match(path, pattern):
    """True if a line of the file matches the regular expression."""
    return any(re.search(pattern, line) for line in lines_of(path))


def ends_without_newline(path):
    """True if the file isn't empty and doesn't end with a line break, so text
    added to it has to start on a new line."""
    try:
        if Path(path).stat().st_size == 0:
            return False
        with open(path, "rb") as f:
            f.seek(-1, os.SEEK_END)
            return f.read(1) != b"\n"
    except OSError:
        return False


def append_lines(path, *lines):
    """Adds the lines at the end of the file, starting on a line of their own."""
    if ends_without_newline(path):
        write_text(path, "\n", "a")
    write_text(path, "".join(line + "\n" for line in lines), "a")


def replace_text(path, text):
    """Writes the file in one step: the text goes to a new file beside it,
    which then replaces it, so it's never left half-written."""
    path = Path(path)
    new = path.with_name(path.name + ".jenerated-new")
    write_text(new, text)
    os.replace(new, path)


def backup_once(path):
    """Copies a settings file to <its name>.before-jenerated, unless there's
    a backup already: the first one holds the settings from before any
    palette. Returns the backup's path."""
    path = Path(path)
    backup = path.with_name(path.name + ".before-jenerated")
    if not backup.exists():
        shutil.copy(path, backup)
    return backup


def remove(path):
    """Removes a file, link or folder (with everything in it), if it's
    there."""
    path = Path(path)
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def copy_path(source, target):
    """Copies a file, or a folder and everything in it."""
    source = Path(source)
    if source.is_dir() and not source.is_symlink():
        shutil.copytree(source, target, symlinks=True)
    else:
        shutil.copy(source, target)


def make_folders(*paths):
    """Makes each folder, and the folders it's in, as needed."""
    for path in paths:
        Path(path).mkdir(parents=True, exist_ok=True)


def current_folder():
    """The current folder, keeping the links in its path as you named it
    (from PWD, when that's this folder), rather than with them followed."""
    pwd = os.environ.get("PWD")
    try:
        if pwd and Path(pwd).is_absolute() and Path(pwd).samefile("."):
            return Path(pwd)
    except OSError:
        pass
    return Path.cwd()


def system_name():
    """The system's name: Linux, or Darwin for macOS. It asks `uname`, so the
    tests can pretend to be either system."""
    name = output_of(["uname", "-s"], stderr=subprocess.DEVNULL)
    if name is None:
        import platform
        name = platform.system()
    return name


OS = system_name()

# Your home folder, where themes are installed: HOME, or USERPROFILE on
# systems that use that instead. None if neither is set; menus.run stops
# then, rather than install somewhere else instead.
_home = os.environ.get("HOME") or os.environ.get("USERPROFILE")
HOME = Path(_home) if _home else None


def open_url(url):
    """Opens the URL in the default browser without waiting for it, or returns
    False if there's no way to (no `open` or `xdg-open`, as over SSH)."""
    if OS == "Darwin":
        return succeeds(["open", url])
    if shutil.which("xdg-open"):
        start_in_background(["xdg-open", url])
        return True
    return False


def zip_folder(folder, target):
    """Writes a .zip of everything in the folder (paths inside it relative to
    the folder). Returns False if it can't. The .zip is reproducible: the same
    files always make the same bytes (every entry gets a fixed date), so the
    committed example packages only change when their contents do."""
    try:
        Path(target).unlink(missing_ok=True)
        with zipfile.ZipFile(target, "w") as z:
            for dirpath, dirs, files in os.walk(folder):
                dirs.sort()
                for name in sorted(files):
                    path = Path(dirpath, name)
                    entry = zipfile.ZipInfo(path.relative_to(folder).as_posix(),
                                            (1980, 1, 1, 0, 0, 0))
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    entry.external_attr = 0o644 << 16
                    with open(path, "rb") as f:
                        z.writestr(entry, f.read())
        return True
    except OSError:
        return False


def copy_to_clipboard(data):
    """Copies the text (bytes) to the clipboard, with whichever clipboard tool
    there is; False if there's none, or it fails."""
    if OS == "Darwin" and shutil.which("pbcopy"):
        tool = ["pbcopy"]
    elif os.environ.get("WAYLAND_DISPLAY") and shutil.which("wl-copy"):
        tool = ["wl-copy"]
    elif shutil.which("xclip"):
        tool = ["xclip", "-selection", "clipboard"]
    elif shutil.which("xsel"):
        tool = ["xsel", "--clipboard", "--input"]
    else:
        return False
    try:
        return subprocess.run(tool, input=data, stderr=subprocess.DEVNULL).returncode == 0
    except OSError:
        return False


def copy_file_to_clipboard(path):
    """Copies a file's text to the clipboard; False if it can't."""
    try:
        data = Path(path).read_bytes()
    except OSError:
        return False
    return copy_to_clipboard(data)
