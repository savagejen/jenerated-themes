#!/usr/bin/env bash
# Tests for Ptyxis (Ubuntu terminal): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-ptyxis.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system
# WHEN choosing Ptyxis and Blue Purple
# THEN the palette is linked into Ptyxis's palettes folder, and it says which
#      palette to choose
test_ptyxis_links_the_palette() {
  fake_os Linux
  install_app ptyxis blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/app-themes/ptyxis-theme/blue-purple.palette"
  assert_contains 'choose "Blue Purple"'
}

# GIVEN the Ptyxis palette is already linked
# WHEN choosing Ptyxis again
# THEN it succeeds and the link is still right
test_ptyxis_running_twice_is_fine() {
  fake_os Linux
  install_app ptyxis blue-purple "y\n1\n"
  install_app ptyxis blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/org.gnome.Ptyxis/palettes/blue-purple.palette" \
    "$SANDBOX/repo/app-themes/ptyxis-theme/blue-purple.palette"
}

run_tests
