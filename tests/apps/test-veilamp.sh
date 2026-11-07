#!/usr/bin/env bash
# Tests for Veilamp (music player): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-veilamp.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
veilamp_skin() { printf '%s' "$SANDBOX/repo/app-themes/veilamp-theme/$1/skin.json"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating its Veilamp skin
# THEN it's valid JSON with the name, and string vars, which Veilamp needs to
#      load it; its main highlight color is Sunset's accent, its text is
#      Sunset's text, and text on the accent is Sunset's text_bright
test_veilamp_skin_follows_the_palette() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import json, sys
t = json.load(open(sys.argv[1]))
v = t["vars"]
print(t["name"], v["--cyan"], v["--text"], v["--on-accent"],
      all(isinstance(x, str) for x in v.values()))
' "$(veilamp_skin sunset)")"
  assert_contains "Jenerated Sunset $(color accent) $(color text) $(color text_bright) True"
}

# --- Tests: installing -------------------------------------------------------

VEILAMP_SKIN_DIR=".local/share/com.veilamp.app/skins/jenerated-blue-purple"

# GIVEN Linux
# WHEN choosing Veilamp and Blue Purple
# THEN Blue Purple's skin folder is linked into Veilamp's skins folder as
#      jenerated-blue-purple (the folder Veilamp's own import would make), and
#      it says to restart Veilamp and choose the palette, and how to remove a
#      linked skin
test_veilamp_links_the_skin_package() {
  fake_os Linux
  install_app veilamp blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$VEILAMP_SKIN_DIR" "$SANDBOX/repo/app-themes/veilamp-theme/blue-purple"
  assert_exists "$SANDBOX/home/$VEILAMP_SKIN_DIR/skin.json"
  assert_contains "Restart Veilamp"
  assert_contains 'Open Settings -> Appearance and click the "Jenerated Blue Purple" skin'
  assert_contains "Classic and LCARS keep their own"
  assert_contains "Veilamp can't remove a linked skin itself"
}

# GIVEN a Mac
# WHEN choosing Veilamp and Blue Purple
# THEN the skin goes in Veilamp's folder in Application Support
test_veilamp_on_macos_uses_application_support() {
  fake_os Darwin
  install_app veilamp blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/com.veilamp.app/skins/jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/veilamp-theme/blue-purple"
}

# GIVEN VEILAMP_DATA_DIR is set, pointing Veilamp at another data folder
# WHEN choosing Veilamp and Blue Purple
# THEN the skin goes in that folder's skins folder instead
test_veilamp_follows_its_data_dir_setting() {
  fake_os Linux
  TEST_VEILAMP_DATA_DIR="$SANDBOX/home/veilamp-data" install_app veilamp blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/veilamp-data/skins/jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/veilamp-theme/blue-purple"
  assert_missing "$SANDBOX/home/.local/share/com.veilamp.app"
}

# GIVEN Veilamp found
# WHEN installing ALL THE APPS
# THEN Veilamp is installed with the rest, not left out as a manual install
test_veilamp_is_installed_by_all_the_apps() {
  fake_os Linux
  export SETUP_FOUND_APPS="veilamp tilix"
  run_setup "1\n9\n1\ny\n"
  assert_contains "ALL THE APPS: Veilamp (music player)"
  assert_link "$SANDBOX/home/$VEILAMP_SKIN_DIR" "$SANDBOX/repo/app-themes/veilamp-theme/blue-purple"
}

run_tests
