#!/usr/bin/env bash
# Tests every app, read from the app registry, so a new app is tested here
# as soon as it exists, before it has tests of its own: its theme is made
# for a palette with nothing left unfilled, and installing it either works
# or stops with a reason. Its own test file then checks the details.
#
# Each app is also tested in an installed copy (see make_installed in
# tests/lib.sh), where templates are read from read-only package data and
# themes written to the data folder. In a clone those are the same folder,
# so an app that reads or writes through the wrong one only shows up here.
#
# Usage: tests/apps/test-every-app.sh [part of a test's name, or an app's id]

source "$(dirname "$0")/apps.sh"

# Every outside command an install might run fails, so installing every app
# can't open a browser, reload a running tmux, or reach anything else
# outside the sandbox.
after_sandbox() {
  quiet_desktop
  for tool in firefox open xdg-open tmux unopkg zsh flatpak pgrep; do
    fake_command "$tool" "exit 1"
  done
}

# app_outputs id slug [folder] -> prints the path of each file the app's
# templates make for the palette, in the sandbox repository or the folder.
app_outputs() {
  "$PYTHON" -c '
import sys
sys.path.insert(0, sys.argv[1])
from jenerate_themes.apps import ALL_APPS
app = next(app for app in ALL_APPS if app.id == sys.argv[2])
for _, output in app.templates:
    print(sys.argv[4] + "/" + output.format(slug=sys.argv[3]))
' "$SANDBOX/repo" "$1" "$2" "${3:-$SANDBOX/repo}"
}

# check_generates id -> makes Blue Purple and Sunset, then checks each of the
# app's files is there with no {{ placeholder left in it.
check_generates() {
  local id="$1" slug file
  generate blue-purple sunset
  assert_status 0
  for slug in blue-purple sunset; do
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      assert_exists "$file"
      [ -f "$file" ] && assert_file_not_contains "$file" "{{"
    done <<<"$(app_outputs "$id" "$slug")"
  done
}

# check_installs id -> installs Blue Purple into the app the way ALL THE APPS
# does (yes to every question, the first of every choice), on its system,
# then checks the summary lists it: installed, or not installed with what to
# do (the reason is above it).
check_installs() {
  local id="$1"
  fake_os "${SYSTEM[$id]:-Linux}"
  SETUP_FOUND_APPS="$id" install_app all blue-purple "y\n"
  assert_contains "==> ALL THE APPS: ${LABEL[$id]} (1 of 1)"
  # The summary after "done", up to the apps not found (not this one).
  local summary="${OUTPUT#*==> ALL THE APPS: done}"
  summary="${summary%%Not found on this computer*}"
  case "$summary" in
    *"  - ${LABEL[$id]}"*) ;;
    *) fail "expected the summary to list ${LABEL[$id]} as installed or not" ;;
  esac
}

# check_generates_installed id -> makes Sunset with an installed copy, then
# checks each of the app's files is in the data folder with no {{
# placeholder left in it, and the installed copy is unchanged.
check_generates_installed() {
  local id="$1" file before
  make_installed
  before="$(cd "$SANDBOX/site" && find . -type f -exec cksum {} + | sort)"
  run_installed "" generate sunset
  assert_status 0
  assert_not_contains "Traceback"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    assert_exists "$file"
    [ -f "$file" ] && assert_file_not_contains "$file" "{{"
  done <<<"$(app_outputs "$id" sunset "$SANDBOX/home/$INSTALLED_DATA_PATH")"
  [ "$(cd "$SANDBOX/site" && find . -type f -exec cksum {} + | sort)" = "$before" ] ||
    fail "expected the installed copy to be unchanged"
}

# check_installs_installed id -> installs Blue Purple into the app with an
# installed copy, as check_installs does, then checks nothing it put in
# place links into the installed copy itself (an upgrade would break it),
# and it never tried to write there.
check_installs_installed() {
  local id="$1" links
  make_installed
  fake_os "${SYSTEM[$id]:-Linux}"
  SETUP_FOUND_APPS="$id" run_installed "y\n" install all blue-purple
  assert_not_contains "Traceback"
  assert_not_contains "Read-only file system"
  assert_not_contains "Permission denied"
  assert_contains "==> ALL THE APPS: ${LABEL[$id]} (1 of 1)"
  links="$(find "$SANDBOX/home" -type l -lname "$SANDBOX/site*" 2>/dev/null)"
  [ -z "$links" ] || fail "expected no links into the installed copy, got: $links"
}

# One generate test per app, and one install test per app that can be
# installed into (not the ones themed by hand in the app), each named for
# the app, like test_every_app_installs_tilix; and each again with an
# installed copy, like test_every_app_installs_installed_tilix.
declare -A LABEL SYSTEM
while IFS='|' read -r id system manual label; do
  LABEL[$id]="$label"
  SYSTEM[$id]="$system"
  eval "test_every_app_generates_$id() { check_generates $id; }"
  eval "test_every_app_generates_installed_$id() { check_generates_installed $id; }"
  if [ "$manual" = False ]; then
    eval "test_every_app_installs_$id() { check_installs $id; }"
    eval "test_every_app_installs_installed_$id() { check_installs_installed $id; }"
  fi
done <<<"$("$PYTHON" -c '
import sys
sys.path.insert(0, sys.argv[1])
from jenerate_themes.apps import ALL_APPS
for app in ALL_APPS:
    print(f"{app.id}|{app.system}|{app.manual}|{app.label}")
' "$REPO")"

run_tests
