#!/usr/bin/env bash
# Tests for the repository as a whole.
#
# Usage: tests/repo/test-repo.sh [part of a test's name]
#
# Each test looks at a throwaway copy of the repository as git sees it.

source "$(dirname "$0")/../lib.sh"

# --- Tests: symbols stay ASCII -----------------------------------------------

# GIVEN every file and folder in the repository (tracked, or new and not
#       ignored)
# WHEN looking for characters outside ASCII that aren't letters or accent
#      marks in its name and, for a text file, its lines, the same rule and
#      script as the pre-commit hook
# THEN there are none: letters in any language are fine, but symbols are
#      written as plain text ("...", "-", "->")
test_symbols_are_plain_ascii() {
  OUTPUT="$(cd "$SANDBOX/repo" && python3 .githooks/check-symbols.py --all)"
  STATUS=$?
  [ -z "$OUTPUT" ] || fail "these file names and lines have symbols outside plain ASCII:
$OUTPUT"
  # A non-zero exit means the check couldn't finish, even with nothing listed.
  assert_status 0
}

# --- Tests: no compiled Python ----------------------------------------------

# GIVEN every file in the repository (tracked, or new and not ignored)
# WHEN looking for compiled Python files (.so, .pyd, .pyc, .pyo)
# THEN there are none: Python imports a compiled module in place of a .py
#      file with the same name, and review only shows it as a binary file,
#      so one could run hidden code instead of the source everyone reads
test_no_compiled_python_files() {
  OUTPUT="$(cd "$SANDBOX/repo" && find . -path ./.git -prune -o -type f \
    \( -name '*.so' -o -name '*.pyd' -o -name '*.pyc' -o -name '*.pyo' \) -print)"
  [ -z "$OUTPUT" ] || fail "these compiled Python files shouldn't be in the repository:
$OUTPUT"
}

# --- Tests: dashes in file names ---------------------------------------------

# GIVEN every file in the repository (tracked, or new and not ignored)
# WHEN looking for underscores in its name or its folders' names, the same
#      rule as the pre-commit hook
# THEN there are none outside jenerate_themes/, where Python needs them
test_file_names_use_dashes() {
  OUTPUT="$(cd "$SANDBOX/repo" && find . -path ./.git -prune -o -path ./jenerate_themes -prune \
    -o -name '*_*' -print)"
  [ -z "$OUTPUT" ] || fail "these file names have underscores (use dashes):
$OUTPUT"
}

run_tests
