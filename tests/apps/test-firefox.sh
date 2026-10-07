#!/usr/bin/env bash
# Tests for Firefox: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-firefox.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
firefox_theme() { printf '%s' "$SANDBOX/repo/app-themes/firefox-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Firefox theme is valid JSON, named after the palette, with an add-on
#      id from the slug, dark, and using Sunset's colors, including the
#      translucent accent as RGB
test_firefox_theme_uses_the_palette() {
  generate sunset
  manifest="$(firefox_theme sunset)/manifest.json"
  assert_valid_json "$manifest"
  result="$("$PYTHON" -c '
import json, sys
m = json.load(open(sys.argv[1]))
c = m["theme"]["colors"]
print(m["name"], m["browser_specific_settings"]["gecko"]["id"], m["theme"]["properties"]["color_scheme"])
print(c["frame"], c["toolbar"], c["tab_line"], c["toolbar_field_highlight"])
' "$manifest")"
  expected="Jenerated Sunset jenerated-sunset@jenerated-themes dark
$(color bg_chrome) $(color bg) $(color accent) rgba($(color_rgb accent), 0.4)"
  [ "$result" = "$expected" ] || fail "expected Firefox theme values '$expected', got '$result'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Firefox theme folder is deleted, and the template is kept
test_remove_deletes_the_firefox_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/firefox-theme/sunset/manifest.json"
  assert_missing "$(firefox_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/firefox-theme/manifest.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

FIREFOX_DIR="app-themes/firefox-theme"

# xpi_manifest xpi expression -> prints a Python expression over the .xpi's
# manifest (as `m`), or its file list (as `names`).
xpi_manifest() {
  "$(find_python)" -c "
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = z.namelist()
m = json.loads(z.read('manifest.json'))
print($2)
" "$1"
}

# GIVEN a Linux system
# WHEN choosing Firefox and Sunset, and not opening Firefox
# THEN Sunset's theme is packaged as an .xpi holding just its manifest, with
#      a date-based version, and it explains trying and keeping the theme
test_firefox_packages_the_theme() {
  fake_os Linux
  fake_command firefox "touch \"$SANDBOX/firefox-ran\""
  install_app firefox sunset "n\n"
  assert_status 0
  xpi="$SANDBOX/repo/$FIREFOX_DIR/jenerated-sunset.xpi"
  assert_exists "$xpi"
  [ "$(xpi_manifest "$xpi" 'names')" = "['manifest.json']" ] || fail "expected the .xpi to hold only manifest.json"
  [ "$(xpi_manifest "$xpi" 'm["name"], m["browser_specific_settings"]["gecko"]["id"]')" = \
    "Jenerated Sunset jenerated-sunset@jenerated-themes" ] || fail "unexpected .xpi name or id"
  version="$(xpi_manifest "$xpi" 'm["version"]')"
  printf '%s' "$version" | grep -Eq '^20[0-9]{2}\.[1-9][0-9]{2,3}\.(0|[1-9][0-9]{0,3})$' ||
    fail "expected a date-based version without leading zeros, got $version"
  assert_contains "$SANDBOX/repo/$FIREFOX_DIR/sunset/manifest.json"
  assert_contains "https://addons.mozilla.org/developers/addon/submit/distribution"
  assert_contains "upload $xpi"
  assert_missing "$SANDBOX/firefox-ran"
}

# GIVEN a Linux system with Firefox
# WHEN choosing Firefox and answering yes to opening it
# THEN Firefox is started on its add-on debugging page
test_firefox_opens_the_debugging_page() {
  fake_os Linux
  fake_command firefox "printf '%s' \"\$*\" >\"$SANDBOX/firefox-ran\""
  install_app firefox blue-purple "y\n"
  assert_status 0
  wait_for "$SANDBOX/firefox-ran"
  assert_file_equals "$SANDBOX/firefox-ran" "about:debugging#/runtime/this-firefox"
}

# GIVEN a Mac
# WHEN choosing Firefox and answering yes to opening it
# THEN it opens the page with `open -a Firefox`
test_firefox_on_macos_uses_open() {
  fake_os Darwin
  fake_command open "printf '%s' \"\$*\" >\"$SANDBOX/open-ran\""
  install_app firefox blue-purple "y\n"
  assert_status 0
  assert_file_equals "$SANDBOX/open-ran" "-a Firefox about:debugging#/runtime/this-firefox"
}

# GIVEN a Mac where Firefox can't be opened
# WHEN choosing Firefox and answering yes to opening it
# THEN it says so, and still explains how to load the theme
test_firefox_that_cant_be_found_is_explained() {
  fake_os Darwin
  fake_command open "exit 1"
  install_app firefox blue-purple "y\n"
  assert_status 0
  assert_contains "Couldn't find Firefox"
  assert_contains "Load Temporary Add-on"
}

run_tests
