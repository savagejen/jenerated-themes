"""Which templates each app's theme is made from, and where each palette's
files go: every app's templates (in its APP, in jenerate_themes/apps/),
together."""

from .apps import ALL_APPS
from .paths import VSCODE_THEME  # noqa: F401  (kept here for older imports)

# (template, output) pairs, relative to the repository root.
TARGETS = [pair for app in ALL_APPS for pair in app.templates]
