"""What one run of the app shares between its parts: how it was started, and
the install going on now."""

from contextlib import contextmanager
from dataclasses import dataclass, field

# Where it was started from, for paths people type (like an Obsidian vault's).
# Set by cli.
START_DIR = ""

# The command people use to run it again, for messages like "run ./setup.sh
# again": ./setup.sh when setup.sh started it, ./jenerate from a clone, or
# jenerate once it's installed. Set by cli.
COMMAND = "jenerate"


@dataclass
class Install:
    """How one install is going.

    auto  questions answer themselves, as in ALL THE APPS and ALL THE
          PALETTES: ask_yes answers yes and choose picks the first choice
          (each still shows the question, and says what was chosen)
    mode  how its files are put in place: "link" (to this folder, so they
          update when the palette is regenerated), "copy", or "manual" (you
          run the commands yourself); see install.run_install_plan
    plan  the (target, source) files install.run_install_plan will show and
          offer to put in place
    """
    auto: bool = False
    mode: str = "link"
    plan: list = field(default_factory=list)


# The install going on now.
current = Install()


@contextmanager
def separate_install(auto=False):
    """Runs the code inside with an install of its own, and puts the one
    before back afterward, so one app's install (in ALL THE APPS, say) never
    carries its choices into the next."""
    global current
    outer = current
    current = Install(auto=auto)
    try:
        yield current
    finally:
        current = outer


def generate():
    """The command that generates themes: ./jenerate.py when started from
    setup.sh (as setup.sh has always said), or the generate subcommand."""
    return "./jenerate.py" if COMMAND == "./setup.sh" else f"{COMMAND} generate"


def regenerate(slug):
    """The command that regenerates one palette's themes."""
    return f"{generate()} {slug}"
