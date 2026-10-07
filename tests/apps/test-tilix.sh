#!/usr/bin/env bash
# Tests for Tilix (terminal): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-tilix.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
tilix_scheme() { printf '%s' "$SANDBOX/repo/app-themes/tilix-theme/$1.json"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Tilix scheme is valid JSON
test_tilix_scheme_is_valid_json() {
  generate sunset
  assert_valid_json "$(tilix_scheme sunset)"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Tilix scheme has Sunset's name, background, foreground, 16 terminal
#      colors and cursor color
test_tilix_scheme_uses_the_palette() {
  generate sunset
  result="$("$PYTHON" -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(s["name"], s["background-color"], s["foreground-color"],
      len(s["palette"]), s["palette"][1], s["palette"][15], s["cursor-background-color"])
' "$(tilix_scheme sunset)")"
  expected="Jenerated Sunset $(color bg) $(color text) 16 $(color term_red) $(color term_bright_white) $(color accent)"
  [ "$result" = "$expected" ] || fail "expected Tilix scheme values '$expected', got '$result'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Tilix scheme is deleted and the template is kept
test_remove_deletes_the_tilix_scheme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/tilix-theme/sunset.json"
  assert_missing "$(tilix_scheme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/scheme.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

TILIX_SCHEMES=".config/tilix/schemes"

# GIVEN a Linux system
# WHEN choosing Tilix and Blue Purple
# THEN the scheme is linked into Tilix's schemes folder as
#      jenerated-blue-purple.json, and it says which scheme to choose
test_tilix_links_the_scheme() {
  fake_os Linux
  install_app tilix blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a Linux system
# WHEN choosing Tilix and Sunset
# THEN Sunset's scheme is generated and linked
test_tilix_links_a_generated_palette() {
  fake_os Linux
  install_app tilix sunset "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$TILIX_SCHEMES/jenerated-sunset.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
}

# GIVEN a scheme of the user's own called blue-purple.json
# WHEN choosing Tilix and Blue Purple
# THEN their scheme is untouched
test_tilix_leaves_other_schemes_alone() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo mine >"$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json"
  install_app tilix blue-purple "y\n1\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/blue-purple.json" "mine"
}

# GIVEN the Tilix scheme is already linked
# WHEN choosing Tilix again
# THEN it says it's already installed
test_tilix_already_linked_is_left_alone() {
  fake_os Linux
  install_app tilix blue-purple "y\n1\n"
  install_app tilix blue-purple "y\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

# GIVEN a file already at jenerated-blue-purple.json
# WHEN choosing Tilix and answering no to replacing it
# THEN it exits with status 1 and the file is untouched
test_tilix_asks_before_replacing_a_file() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/$TILIX_SCHEMES"
  echo old >"$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json"
  install_app tilix blue-purple "y\n1\nn\n"
  assert_status 1
  assert_file_equals "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" "old"
}

run_tests
