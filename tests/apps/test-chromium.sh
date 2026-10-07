#!/usr/bin/env bash
# Tests for Chromium browsers (Chrome, Brave, Edge, Opera and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-chromium.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
chromium_theme() { printf '%s' "$SANDBOX/repo/app-themes/chromium-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Chromium theme is a valid Manifest V3 theme named after the palette,
#      with every color an [r, g, b] list, using Sunset's colors
test_chromium_theme_uses_the_palette() {
  generate sunset
  manifest="$(chromium_theme sunset)/manifest.json"
  assert_valid_json "$manifest"
  result="$("$PYTHON" -c '
import json, sys
m = json.load(open(sys.argv[1]))
c = m["theme"]["colors"]
ok = all(isinstance(v, list) and len(v) == 3 and all(isinstance(x, int) and 0 <= x <= 255 for x in v) for v in c.values())
rgb = lambda k: ", ".join(map(str, c[k]))
print(m["manifest_version"], m["name"], ok)
print(rgb("frame"), "|", rgb("toolbar"), "|", rgb("tab_text"), "|", rgb("ntp_link"))
' "$manifest")"
  expected="3 Jenerated Sunset True
$(color_rgb bg_chrome) | $(color_rgb bg) | $(color_rgb text_bright) | $(color_rgb accent_soft)"
  [ "$result" = "$expected" ] || fail "expected Chromium theme values:
$expected
got:
$result"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Chromium theme folder is deleted, and the template is kept
test_remove_deletes_the_chromium_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/chromium-theme/sunset/manifest.json"
  assert_missing "$(chromium_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/chromium-theme/manifest.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN the Sunset palette
# WHEN choosing Chromium browsers and Sunset
# THEN Sunset's theme is generated, and it explains loading its folder as an
#      unpacked extension in each browser
test_chromium_explains_loading_the_theme() {
  install_app chromium sunset
  assert_status 0
  folder="$SANDBOX/repo/app-themes/chromium-theme/sunset"
  assert_exists "$folder/manifest.json"
  assert_contains "The theme is ready in $folder"
  assert_contains "chrome://extensions"
  assert_contains "brave://extensions"
  assert_contains "edge://extensions"
  assert_contains '"Load unpacked"'
}

# GIVEN a browser's old cache of Blue Purple's theme in its folder
# WHEN choosing Chromium browsers and Blue Purple
# THEN the cache is deleted, so the browser uses the current colors
test_chromium_clears_an_old_theme_cache() {
  touch "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/Cached Theme.pak"
  install_app chromium blue-purple
  assert_status 0
  assert_missing "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/Cached Theme.pak"
  assert_exists "$SANDBOX/repo/app-themes/chromium-theme/blue-purple/manifest.json"
}

run_tests
