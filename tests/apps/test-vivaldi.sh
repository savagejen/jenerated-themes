#!/usr/bin/env bash
# Tests for Vivaldi: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-vivaldi.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
vivaldi_theme() { printf '%s' "$SANDBOX/repo/app-themes/vivaldi-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Vivaldi theme is valid JSON, named after the palette, with the
#      palette's UUID as its id, using Sunset's colors, and not taking its
#      accent from websites
test_vivaldi_theme_uses_the_palette() {
  generate sunset
  settings="$(vivaldi_theme sunset)/settings.json"
  assert_valid_json "$settings"
  result="$("$PYTHON" -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(s["name"], s["accentFromPage"])
print(s["colorAccentBg"], s["colorBg"], s["colorFg"], s["colorHighlightBg"], s["colorWindowBg"])
print(s["id"])
' "$settings")"
  expected="Jenerated Sunset False
$(color bg_chrome) $(color bg) $(color text) $(color accent) $(color bg_minimap)"
  [ "$(printf '%s\n' "$result" | head -n 2)" = "$expected" ] ||
    fail "expected Vivaldi theme values '$expected', got '$result'"
  printf '%s\n' "$result" | tail -n 1 | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' ||
    fail "expected the id to be a UUID, got '$(printf '%s\n' "$result" | tail -n 1)'"
}

# GIVEN the fields in a theme exported by Vivaldi (a theme with other fields,
#       or a non-UUID id, is refused on import with "format errors")
# WHEN generating Sunset
# THEN the Vivaldi theme has exactly those fields
test_vivaldi_theme_has_the_fields_vivaldi_exports() {
  generate sunset
  fields="$("$PYTHON" -c '
import json, sys
print(" ".join(sorted(json.load(open(sys.argv[1])))))
' "$(vivaldi_theme sunset)/settings.json")"
  expected="accentFromPage accentOnWindow accentSaturationLimit alpha backgroundImage backgroundPosition blur colorAccentBg colorBg colorFg colorHighlightBg colorPosition colorWindowBg contrast dimBlurred engineVersion id name preferSystemAccent radius simpleScrollbar transparencyTabBar transparencyTabs url version"
  [ "$fields" = "$expected" ] || fail "expected Vivaldi's fields '$expected', got '$fields'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Vivaldi theme folder is deleted, and the template is kept
test_remove_deletes_the_vivaldi_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/vivaldi-theme/sunset/settings.json"
  assert_missing "$(vivaldi_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/vivaldi-theme/settings.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

VIVALDI_DIR="app-themes/vivaldi-theme"

# GIVEN the Sunset palette
# WHEN choosing Vivaldi and Sunset
# THEN it's packaged as a .zip holding just its settings.json, as Vivaldi
#      imports it, and it explains how to import it
test_vivaldi_packages_the_theme() {
  install_app vivaldi sunset
  assert_status 0
  theme_zip="$SANDBOX/repo/$VIVALDI_DIR/jenerated-sunset.zip"
  assert_exists "$theme_zip"
  result="$("$(find_python)" -c '
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
s = json.loads(z.read("settings.json"))
print(z.namelist(), s["name"])
' "$theme_zip")"
  [ "$result" = "['settings.json'] Jenerated Sunset" ] ||
    fail "unexpected .zip contents: $result"
  assert_contains '"Import Theme..."'
  assert_contains "$theme_zip"
  assert_contains "within 30 seconds"
}

run_tests
