#!/usr/bin/env bash
# Tests for Caido (web security testing): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-caido.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

caido_css() { printf '%s' "$SANDBOX/repo/app-themes/caido-theme/jenerated-$1.css"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette (dark) and a light one, Daylight
# WHEN generating them and reading their Caido CSS
# THEN it sets Caido's color variables, current and older names alike, from
#      the palette (page background, default text, primary fill), under a
#      selector that outranks Caido's own, with Sunset dark and Daylight
#      light, and its braces balance
test_caido_css_follows_the_palette() {
  write_light_palette daylight Daylight
  generate sunset daylight
  css="$(caido_css sunset)"
  assert_file_contains "$css" ":root[data-appearance] {"
  assert_file_contains "$css" "color-scheme: dark;"
  assert_file_contains "$css" "--color-surface-page: $(color bg);"
  assert_file_contains "$css" "--color-fg-default: $(color text);"
  assert_file_contains "$css" "--color-fill-primary: $(color accent);"
  assert_file_contains "$css" "--c-surface-900: $(color bg);"
  assert_file_contains "$(caido_css daylight)" "color-scheme: light;"
  [ "$(grep -o '{' "$css" | wc -l)" = "$(grep -o '}' "$css" | wc -l)" ] || fail "expected the braces to balance"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a clipboard tool
# WHEN choosing Caido and Blue Purple
# THEN it shows where the CSS is, copies it to the clipboard, and explains
#      pasting it into Custom CSS with the Dark appearance
test_caido_copies_the_css() {
  fake_os Linux
  install_app caido blue-purple
  assert_status 0
  assert_contains "It's in $SANDBOX/repo/app-themes/caido-theme/jenerated-blue-purple.css"
  assert_contains "(Copied to your clipboard.)"
  assert_same_file "$SANDBOX/clipboard" "$SANDBOX/repo/app-themes/caido-theme/jenerated-blue-purple.css"
  assert_contains "Choose the Dark appearance"
  assert_contains "Open Custom CSS"
}

# GIVEN a light palette, Dawn
# WHEN choosing Caido and Dawn
# THEN it says to choose Caido's Light appearance
test_caido_light_palette_says_light() {
  fake_os Linux
  dawn_palette Light
  install_app caido dawn
  assert_status 0
  assert_contains "Choose the Light appearance"
}

# GIVEN ALL THE APPS
# WHEN it lists what it leaves out
# THEN Caido is among the manual installs
test_caido_is_a_manual_install() {
  fake_os Linux
  export SETUP_FOUND_APPS="tilix"
  run_setup "1\n9\n1\nn\n1\nslack\n1\n1\n"
  assert_contains "  - Caido (web security testing)"
  assert_not_contains "ALL THE APPS: Caido"
}

run_tests
