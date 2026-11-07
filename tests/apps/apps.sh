# Helpers for the app tests, tests/apps/test-<app>.sh: source this instead
# of lib.sh. Each app's file has its tests for both making its theme and
# installing it. To add tests for a new app, copy the file of an app like it.
#
#   generate SLUG...                 makes the palettes' themes in the sandbox
#                                    repository (./jenerate generate)
#   remove SLUG...                   removes them again (./jenerate remove)
#   install_app APP PALETTE ANSWERS  installs a palette's theme into an app
#                                    (./jenerate install), answering the app's
#                                    own questions with ANSWERS ("y\n1\n")
#
# Each sets OUTPUT and STATUS for the assert_* helpers in lib.sh, as does
# run_setup there, for the few app tests about the menus. lib.sh also has
# fake_os, to make the system look like Linux or macOS.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ]; then
  printf 'skipped: jenerate needs Python 3.11 or later\n'
  exit 0
fi

after_sandbox() {
  quiet_desktop
}

# generate SLUG... -> runs ./jenerate generate in the sandbox repository.
generate() {
  OUTPUT="$(cd "$SANDBOX/repo" && "$PYTHON" ./jenerate generate "$@" 2>&1)"
  STATUS=$?
  # Every failure should be a readable message, never a Python crash.
  assert_not_contains "Traceback"
}

# remove SLUG... -> runs ./jenerate remove in the sandbox repository.
remove() {
  OUTPUT="$(cd "$SANDBOX/repo" && "$PYTHON" ./jenerate remove "$@" 2>&1)"
  STATUS=$?
  assert_not_contains "Traceback"
}

# install_app APP PALETTE "answers" -> runs ./jenerate install APP PALETTE in
# the sandbox repository, feeding it the answers (use \n between them). With
# RUN_FROM set, it runs from that folder instead.
install_app() {
  local app="$1" palette="$2" answers="${3:-}" command=./jenerate
  [ -n "${RUN_FROM:-}" ] && command="$SANDBOX/repo/jenerate"
  OUTPUT="$(cd "${RUN_FROM:-$SANDBOX/repo}" && printf '%b' "$answers" |
    in_sandbox "$PYTHON" "$command" install "$app" "$palette" 2>&1)"
  STATUS=$?
  assert_not_contains "Traceback"
}
