#!/usr/bin/env bash
# Tests for the jenerate command (./jenerate): its subcommands, and that its
# messages name it the way it was started. The menus are tested in
# tests/menus/, and each app's install in tests/apps/.
#
# Usage: tests/cli/test-cli.sh [part of a test's name]

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"

# No test changes your desktop or clipboard; the system is Linux.
after_sandbox() {
  for tool in pbcopy wl-copy xclip xsel; do
    fake_command "$tool" "cat > \"$SANDBOX/clipboard\""
  done
  fake_command gsettings "exit 1"
  fake_command plasma-apply-colorscheme "exit 1"
  fake_command uname "echo Linux"
}

# run_cli "answers" args... -> runs ./jenerate from the sandbox repository
# with the answers on its input, and sets OUTPUT and STATUS.
run_cli() {
  local answers="$1"
  shift
  OUTPUT="$(cd "$SANDBOX/repo" && printf '%b' "$answers" |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WAYLAND_DISPLAY= XDG_DATA_HOME= XDG_CACHE_HOME= \
    XDG_CONFIG_HOME= ZDOTDIR= RSTUDIO_CONFIG_HOME= SPYDER_CONFDIR= VEILAMP_DATA_DIR= JENERATE_COMMAND= \
      "$PYTHON" ./jenerate "$@" 2>&1)"
  STATUS=$?
}

# old_jenerate args... -> runs ./jenerate.py the same way, and prints its
# output.
old_jenerate() {
  (cd "$SANDBOX/repo" && "$PYTHON" ./jenerate.py "$@" 2>&1)
}

# --- Tests: the subcommands ----------------------------------------------------

# GIVEN the jenerate command
# WHEN asking for help
# THEN it lists each subcommand
test_help_lists_the_subcommands() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" --help
  assert_status 0
  for command in install generate remove list contrast design; do
    assert_contains "    $command "
  done
}

# GIVEN the jenerate command
# WHEN asking for its version
# THEN it prints the project's name and the version in jenerate_themes
test_version() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" --version
  assert_status 0
  version="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$SANDBOX/repo/jenerate_themes/__init__.py")"
  [ -n "$version" ] || fail "expected a __version__ in jenerate_themes/__init__.py"
  [ "$OUTPUT" = "jenerate-themes $version" ] || fail "expected 'jenerate-themes $version', got '$OUTPUT'"
}

# GIVEN the palettes
# WHEN running jenerate list and ./jenerate.py --list
# THEN both print the same list
test_list_matches_jenerate_py() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" list
  assert_status 0
  assert_contains "Dark palettes:"
  [ "$OUTPUT" = "$(old_jenerate --list)" ] || fail "expected jenerate list to match ./jenerate.py --list"
}

# GIVEN the Sunset palette
# WHEN running jenerate generate sunset, then jenerate remove sunset
# THEN its themes are generated (and listed in package.json), then removed
test_generate_and_remove() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" generate sunset
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_file_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "Jenerated Sunset"
  run_cli "" remove sunset
  assert_status 0
  assert_contains "Removed app-themes/tilix-theme/sunset.json"
  assert_missing "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_file_not_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "Jenerated Sunset"
}

# GIVEN two palettes named with a comma, as ./jenerate.py takes them
# WHEN running jenerate generate
# THEN both are generated
test_generate_takes_commas() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" generate sunset,blue-purple
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_contains "Generated Blue Purple (blue-purple)"
}

# GIVEN the jenerate command
# WHEN running jenerate generate with no palette
# THEN it stops with a usage message
test_generate_needs_a_palette() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" generate
  assert_status 2
  assert_contains "usage: jenerate generate"
}

# GIVEN the Sunset palette
# WHEN running jenerate contrast sunset and ./jenerate.py --contrast sunset
# THEN both report the same
test_contrast_matches_jenerate_py() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" contrast sunset
  assert_status 0
  assert_contains "Sunset:"
  [ "$OUTPUT" = "$(old_jenerate --contrast sunset)" ] || fail "expected jenerate contrast to match ./jenerate.py --contrast"
}

# --- Tests: install --------------------------------------------------------------

# GIVEN the jenerate command
# WHEN running jenerate install tilix sunset, and linking
# THEN Sunset is linked into Tilix with no menus, and its messages name the
#      command ./jenerate, as it was started
test_install_names_app_and_palette() {
  [ -n "$PYTHON" ] || return 0
  run_cli "y\n1\n" install tilix sunset
  assert_status 0
  assert_not_contains "What would you like to do?"
  assert_not_contains "Which app do you want to theme?"
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_contains "Run ./jenerate again any time to theme another app or switch palettes."
}

# GIVEN a system that doesn't let this user make links
# WHEN installing and choosing to link
# THEN it copies the files instead, says so, and says to run it again after
#      changing the palette
test_install_copies_when_links_fail() {
  [ -n "$PYTHON" ] || return 0
  OUTPUT="$(cd "$SANDBOX/repo" && printf 'y\n1\n' |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" XDG_CONFIG_HOME= JENERATE_COMMAND= \
    "$PYTHON" -c '
import pathlib, runpy, sys
def refuse(*args, **kwargs):
    raise OSError(1, "Operation not permitted")
pathlib.Path.symlink_to = refuse
sys.argv = ["./jenerate", "install", "tilix", "sunset"]
runpy.run_path("./jenerate", run_name="__main__")
' 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "Couldn't make a link (Operation not permitted), so copying instead."
  assert_same_file "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  [ ! -L "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" ] || fail "expected a copy, not a link"
  assert_contains "The files are copies, so after changing the palette, run ./jenerate"
}

# GIVEN the jenerate command
# WHEN installing into OBS, whose instructions say how to regenerate
# THEN they say ./jenerate generate SLUG (not ./jenerate.py)
test_install_says_how_to_regenerate() {
  [ -n "$PYTHON" ] || return 0
  run_cli "y\n1\n" install obs sunset
  assert_status 0
  assert_contains "After changing the palette, run ./jenerate generate sunset and restart OBS."
  assert_not_contains "jenerate.py"
}

# GIVEN the jenerate command
# WHEN running jenerate install with only --palette
# THEN it skips the first menu and starts at the app menu (Back from there
#      leads to the first menu, as usual)
test_install_with_only_a_palette() {
  [ -n "$PYTHON" ] || return 0
  run_cli "0\n" install --palette sunset
  assert_contains "Which app do you want to theme?"
  case "${OUTPUT%%Which app do you want to theme?*}" in
    *"What would you like to do?"*) fail "expected the app menu before the first menu" ;;
  esac
}

# GIVEN the jenerate command
# WHEN running jenerate install with an app it doesn't know
# THEN it stops, listing the apps
test_install_unknown_app_lists_the_apps() {
  [ -n "$PYTHON" ] || return 0
  run_cli "" install nope sunset
  assert_status 1
  assert_contains 'no app called "nope". The apps are:'
  assert_contains "or all, for ALL THE APPS"
}

# GIVEN HOME isn't set (nor USERPROFILE)
# WHEN installing a theme
# THEN it stops, saying so, instead of installing under / (generating and
#      listing still work without it)
test_install_needs_home() {
  [ -n "$PYTHON" ] || return 0
  OUTPUT="$(cd "$SANDBOX/repo" && env -u HOME -u USERPROFILE PATH="$SANDBOX/bin:$PATH" XDG_CONFIG_HOME= \
    "$PYTHON" ./jenerate install tilix sunset 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "HOME isn't set, so there's no home folder to install themes into."
  OUTPUT="$(cd "$SANDBOX/repo" && env -u HOME -u USERPROFILE "$PYTHON" ./jenerate list 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "Dark palettes:"
}

# GIVEN the jenerate command
# WHEN running it with no subcommand and going back
# THEN it shows the first menu, saying how to run it again by its own name
test_no_subcommand_shows_the_menus() {
  [ -n "$PYTHON" ] || return 0
  run_cli "1\n0\n"
  assert_contains "What would you like to do?"
  assert_contains "Which app do you want to theme?"
}

# --- Tests: the app modules --------------------------------------------------------

# GIVEN a module in jenerate_themes/apps/ with no APP
# WHEN running jenerate
# THEN it stops, naming the module and what it needs
test_an_app_module_needs_an_app() {
  [ -n "$PYTHON" ] || return 0
  printf '"""Not finished yet."""\n' >"$SANDBOX/repo/jenerate_themes/apps/example.py"
  run_cli "" list
  assert_status 1
  assert_contains "jenerate_themes/apps/example.py has no APP."
}

# GIVEN a helper module in jenerate_themes/apps/ whose name starts with _
# WHEN running jenerate
# THEN it's left out, rather than taken for an app
test_helper_modules_are_not_apps() {
  [ -n "$PYTHON" ] || return 0
  printf '"""Shared by some apps."""\n' >"$SANDBOX/repo/jenerate_themes/apps/_shared.py"
  run_cli "" list
  assert_status 0
  assert_contains "Dark palettes:"
}

# GIVEN an app whose category isn't one of the categories
# WHEN running jenerate
# THEN it stops, naming the module and listing the categories
test_an_app_needs_a_known_category() {
  [ -n "$PYTHON" ] || return 0
  printf 'from . import App\n\nAPP = App(id="example", label="Example", category="nope", install=print)\n' \
    >"$SANDBOX/repo/jenerate_themes/apps/example.py"
  run_cli "" list
  assert_status 1
  assert_contains 'jenerate_themes/apps/example.py: no category called "nope"; the categories are browsers, communication,'
}

# GIVEN a new app module, with no list to add it to
# WHEN listing the apps (by asking for one that doesn't exist)
# THEN it's there, in its category, in alphabetical order
test_a_new_app_is_found_by_itself() {
  [ -n "$PYTHON" ] || return 0
  printf 'from . import App\n\nAPP = App(id="example", label="Example Chat", category="communication", install=print)\n' \
    >"$SANDBOX/repo/jenerate_themes/apps/example.py"
  run_cli "" install nope
  assert_contains "element, example, mattermost"
}

run_tests
