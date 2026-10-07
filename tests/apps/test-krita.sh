#!/usr/bin/env bash
# Tests for Krita (painting): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-krita.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

# --- Tests: installing -------------------------------------------------------

# GIVEN Linux
# WHEN choosing Krita and Blue Purple
# THEN the KDE theme's color scheme is linked into Krita's color-schemes
#      folder, and it says where to choose it
test_krita_links_the_kde_color_scheme() {
  fake_os Linux
  install_app krita blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/krita/color-schemes/Jenerated-blue-purple.colors" \
    "$SANDBOX/repo/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colors"
  assert_contains 'Settings -> Themes -> "Jenerated Blue Purple"'
}

# GIVEN the Krita Flatpak
# WHEN choosing Krita and Blue Purple
# THEN the Flatpak's color-schemes folder gets the scheme too
test_krita_flatpak_gets_the_scheme_too() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/org.kde.krita"
  install_app krita blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.var/app/org.kde.krita/data/krita/color-schemes/Jenerated-blue-purple.colors" \
    "$SANDBOX/repo/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colors"
}

# GIVEN a Mac
# WHEN choosing Krita and Blue Purple
# THEN the scheme goes in Krita's folder in Application Support
test_krita_on_macos_uses_application_support() {
  fake_os Darwin
  install_app krita blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/krita/color-schemes/Jenerated-blue-purple.colors" \
    "$SANDBOX/repo/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colors"
}

run_tests
