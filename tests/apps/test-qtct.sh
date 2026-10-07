#!/usr/bin/env bash
# Tests for Qt apps outside KDE Plasma (qt5ct and qt6ct): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-qtct.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

qtct_scheme() { printf '%s' "$SANDBOX/repo/app-themes/qtct-theme/jenerated-$1.conf"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its qt5ct/qt6ct color scheme
# THEN it has a [ColorScheme] with active, disabled and inactive colors, each
#      Qt's 21 palette colors as #aarrggbb; and in Qt's order, window text is
#      Sunset's text, base (views) its editor background, window its sidebar,
#      and highlight its accent with its bright text on it
test_qtct_scheme_follows_the_palette() {
  generate sunset
  scheme="$(qtct_scheme sunset)"
  assert_file_contains "$scheme" "[ColorScheme]"
  for key in active_colors disabled_colors inactive_colors; do
    colors="$(sed -n "s/^$key=//p" "$scheme" | tr -d ' ' | tr ',' '\n')"
    [ "$(printf '%s\n' "$colors" | grep -cE '^#[0-9a-fA-F]{8}$')" = "21" ] ||
      fail "expected 21 #aarrggbb colors in $key"
  done
  active="$(sed -n 's/^active_colors=//p' "$scheme" | tr -d ' ' | tr ',' '\n')"
  role() { printf '%s\n' "$active" | sed -n "$1p" | tr '[:upper:]' '[:lower:]'; }
  want() { printf '#ff%s' "$(color "$1" | tr -d '#' | tr '[:upper:]' '[:lower:]')"; }
  [ "$(role 1)" = "$(want text)" ] || fail "expected window text to be text"
  [ "$(role 10)" = "$(want bg)" ] || fail "expected base to be bg"
  [ "$(role 11)" = "$(want bg_sidebar)" ] || fail "expected window to be bg_sidebar"
  [ "$(role 13)" = "$(want accent)" ] || fail "expected highlight to be accent"
  [ "$(role 14)" = "$(want text_bright)" ] || fail "expected highlighted text to be text_bright"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Linux
# WHEN choosing Qt apps outside KDE Plasma, and Blue Purple
# THEN the scheme is linked into qt6ct's and qt5ct's colors folders, named for
#      the palette (the name they list it by), and it explains
#      QT_QPA_PLATFORMTHEME, choosing the scheme, KDE, and apps run with sudo
test_qtct_links_the_scheme_for_both() {
  fake_os Linux
  install_app qtct blue-purple "y\n1\n"
  assert_status 0
  for tool in qt5ct qt6ct; do
    assert_link "$SANDBOX/home/.config/$tool/colors/Jenerated Blue Purple.conf" \
      "$SANDBOX/repo/app-themes/qtct-theme/jenerated-blue-purple.conf"
  done
  assert_contains "QT_QPA_PLATFORMTHEME=qt6ct"
  assert_contains 'Custom palette and "Jenerated Blue Purple"'
  assert_contains "On KDE"
  assert_contains "sudo"
}

# GIVEN Linux, where the Qt apps theme also covers Wireshark
# WHEN searching for "wireshark"
# THEN Wireshark itself comes first, then the Qt apps theme that covers it
test_search_lists_name_matches_first() {
  fake_os Linux
  run_setup "1\nwireshark\n0\n0\n"
  assert_contains 'Apps matching "wireshark":
  1) Wireshark (network analyzer)
  2) Qt apps outside KDE Plasma (qt5ct and qt6ct)'
}

# GIVEN a Mac
# WHEN looking for the Qt apps theme
# THEN it isn't offered, since qt5ct and qt6ct are for Linux desktops
test_qtct_is_linux_only() {
  fake_os Darwin
  run_setup "1\n9\nqt6ct\n\n1\nslack\n1\n1\n"
  assert_not_contains "Qt apps outside KDE Plasma"
}

run_tests
