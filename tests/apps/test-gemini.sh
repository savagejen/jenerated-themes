#!/usr/bin/env bash
# Tests for Gemini CLI: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-gemini.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
gemini_theme() { printf '%s' "$SANDBOX/repo/app-themes/gemini-theme/jenerated-$1.json"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating its Gemini CLI theme
# THEN it's valid JSON, a custom theme named Jenerated Sunset, with Sunset's
#      background and text, and diff backgrounds that are plain #rrggbb
#      (Gemini CLI ignores colors with transparency)
test_gemini_theme_follows_the_palette() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import json, re, sys
t = json.load(open(sys.argv[1]))
print(t["name"], t["type"], t["background"]["primary"], t["text"]["primary"])
for key in ("added", "removed"):
    if not re.fullmatch(r"#[0-9a-f]{6}", t["background"]["diff"][key]):
        print("bad diff color", key)
' "$(gemini_theme sunset)")"
  assert_contains "Jenerated Sunset custom $(color bg) $(color text)"
  assert_not_contains "bad diff color"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN ~/.gemini/settings.json with your settings
# WHEN choosing Gemini CLI and Blue Purple, and saying yes to using it
# THEN the theme is linked into ~/.gemini/themes, ui.theme points at the
#      link, and your other settings are kept
test_gemini_links_the_theme_and_sets_it() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.gemini"
  printf '{"general": {"vimMode": true}, "ui": {"hideTips": true}}\n' >"$SANDBOX/home/.gemini/settings.json"
  install_app gemini blue-purple "y\n1\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.gemini/themes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/gemini-theme/jenerated-blue-purple.json"
  OUTPUT="$("$(find_python)" -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(s["ui"]["theme"], s["ui"]["hideTips"], s["general"]["vimMode"])
' "$SANDBOX/home/.gemini/settings.json")"
  assert_contains "$SANDBOX/home/.gemini/themes/jenerated-blue-purple.json True True"
}

# GIVEN ~/.gemini/settings.json with comments, which isn't plain JSON
# WHEN choosing Gemini CLI and Blue Purple, and saying yes to using it
# THEN the file is left alone, and it says what to set
test_gemini_leaves_settings_it_cannot_read() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.gemini"
  printf '{\n  // my settings\n  "ui": {}\n}\n' >"$SANDBOX/home/.gemini/settings.json"
  cp "$SANDBOX/home/.gemini/settings.json" "$SANDBOX/before"
  install_app gemini blue-purple "y\n1\ny\n"
  assert_status 0
  assert_same_file "$SANDBOX/home/.gemini/settings.json" "$SANDBOX/before"
  assert_contains "so it's unchanged"
  assert_contains "\"theme\": \"$SANDBOX/home/.gemini/themes/jenerated-blue-purple.json\""
}

run_tests
