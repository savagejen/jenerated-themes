#!/usr/bin/env bash
# Tests for Ghidra (reverse engineering): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-ghidra.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

ghidra_theme() { printf '%s' "$SANDBOX/repo/app-themes/ghidra-theme/jenerated-$1.theme"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette (dark) and a light one, Daylight
# WHEN generating them and reading their Ghidra themes
# THEN each is named "Jenerated" plus the palette's name, Sunset builds on
#      Flat Dark and the dark defaults and Daylight on Flat Light, and the
#      colors follow the palette: the view background, keywords in the soft
#      accent, and decompiler function names in the light accent
test_ghidra_theme_follows_the_palette() {
  write_light_palette daylight Daylight
  generate sunset daylight
  theme="$(ghidra_theme sunset)"
  assert_file_contains "$theme" "name = Jenerated Sunset"
  assert_file_contains "$theme" "lookAndFeel = Flat Dark"
  assert_file_contains "$theme" "useDarkDefaults = true"
  assert_file_contains "$theme" "[color]system.color.bg.view = $(color bg)"
  assert_file_contains "$theme" "color.fg.decompiler.keyword = $(color accent_soft)"
  assert_file_contains "$theme" "color.fg.decompiler.function.name = $(color accent_light)"
  assert_file_contains "$(ghidra_theme daylight)" "lookAndFeel = Flat Light"
  assert_file_contains "$(ghidra_theme daylight)" "useDarkDefaults = false"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Ghidra theme without comments
# THEN every line is "name = value", with the first three being name,
#      lookAndFeel and useDarkDefaults, as Ghidra expects
test_ghidra_theme_is_name_value_lines() {
  generate sunset
  lines="$(grep -v -e '^//' -e '^$' "$(ghidra_theme sunset)")"
  OUTPUT="$(printf '%s\n' "$lines" | grep -v -E '^[][A-Za-z.]+ = [^ ].*$')"
  [ -z "$OUTPUT" ] || fail "these lines aren't name = value: $OUTPUT"
  [ "$(printf '%s\n' "$lines" | head -n 3 | cut -d' ' -f1 | tr '\n' ' ')" = "name lookAndFeel useDarkDefaults " ] ||
    fail "expected name, lookAndFeel and useDarkDefaults first"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN settings folders for Ghidra 11.3 and 11.4 (Linux, 11.1 and later) and
#       for 10.4 (from before 11.1, in ~/.ghidra)
# WHEN choosing Ghidra and Blue Purple
# THEN the theme is linked into each version's themes folder, and it says
#      how to switch to it
test_ghidra_links_the_theme_for_each_version() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/ghidra/ghidra_11.3_PUBLIC" "$SANDBOX/home/.config/ghidra/ghidra_11.4_PUBLIC" \
    "$SANDBOX/home/.ghidra/.ghidra_10.4_PUBLIC"
  install_app ghidra blue-purple "y\n1\n"
  assert_status 0
  for dir in .config/ghidra/ghidra_11.3_PUBLIC .config/ghidra/ghidra_11.4_PUBLIC .ghidra/.ghidra_10.4_PUBLIC; do
    assert_link "$SANDBOX/home/$dir/themes/jenerated-blue-purple.theme" \
      "$SANDBOX/repo/app-themes/ghidra-theme/jenerated-blue-purple.theme"
  done
  assert_contains 'Edit -> Theme -> Switch...'
}

# GIVEN a Mac with a Ghidra settings folder
# WHEN choosing Ghidra and Blue Purple
# THEN the theme goes in the folder in ~/Library/ghidra
test_ghidra_on_macos_uses_library() {
  fake_os Darwin
  mkdir -p "$SANDBOX/home/Library/ghidra/ghidra_11.4_PUBLIC"
  install_app ghidra blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/ghidra/ghidra_11.4_PUBLIC/themes/jenerated-blue-purple.theme" \
    "$SANDBOX/repo/app-themes/ghidra-theme/jenerated-blue-purple.theme"
}

# GIVEN no Ghidra settings folder (Ghidra hasn't run yet)
# WHEN choosing Ghidra and Blue Purple
# THEN nothing is installed, and it explains importing the theme in Ghidra
test_ghidra_without_a_settings_folder_explains_importing() {
  fake_os Linux
  install_app ghidra blue-purple
  assert_status 0
  assert_contains "No Ghidra settings folder found"
  assert_contains "Edit -> Theme -> Import..."
  assert_contains "$SANDBOX/repo/app-themes/ghidra-theme/jenerated-blue-purple.theme"
  assert_missing "$SANDBOX/home/.config/ghidra"
}

# GIVEN Ghidra found, but no settings folder
# WHEN installing ALL THE APPS
# THEN Ghidra is listed as not installed, since the theme has to be imported
test_ghidra_without_a_settings_folder_in_all_the_apps() {
  fake_os Linux
  export SETUP_FOUND_APPS="ghidra tilix"
  run_setup "1\n9\n1\ny\n"
  assert_contains "no Ghidra settings folder found"
  assert_contains "Not installed:
  - Ghidra (reverse engineering)"
}

run_tests
