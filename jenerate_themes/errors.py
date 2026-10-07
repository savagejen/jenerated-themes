"""The errors the library raises."""


class JenerateError(Exception):
    """A problem with a palette, a template or a generated file, with a
    message for the person running it, naming the file and what's wrong. The
    command line shows the message and exits with status 1; the Palette
    Creator shows it on its page."""
