#!/usr/bin/env bash
# Tests for QTerminal (LXQt's and Kali's terminal): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-qterminal.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

# --- Tests: installing -------------------------------------------------------

# GIVEN Linux
# WHEN choosing QTerminal and Blue Purple
# THEN the KDE theme's Konsole scheme is linked into QTerminal's
#      color-schemes folder, named for the palette (the name QTerminal lists
#      it by), and it says where to choose it
test_qterminal_links_the_konsole_scheme() {
  fake_os Linux
  install_app qterminal blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/qterminal/color-schemes/Jenerated Blue Purple.colorscheme" \
    "$SANDBOX/repo/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colorscheme"
  assert_contains '"Jenerated Blue Purple" as the Color scheme'
}

# GIVEN dark palettes and a light one, Dawn
# WHEN choosing QTerminal and ALL THE PALETTES
# THEN every palette's scheme is linked, side by side
test_qterminal_takes_all_the_palettes() {
  fake_os Linux
  dawn_palette Light
  install_app qterminal all "y\n"
  assert_status 0
  for name in "Blue Purple" "Dawn" "Sunset"; do
    assert_exists "$SANDBOX/home/.local/share/qterminal/color-schemes/Jenerated $name.colorscheme"
  done
}

# GIVEN a Mac
# WHEN looking for QTerminal
# THEN it isn't offered, since it's for Linux
test_qterminal_is_linux_only() {
  fake_os Darwin
  run_setup "1\n9\nqterminal\n\n1\nslack\n1\n1\n"
  assert_not_contains "QTerminal"
}

run_tests
