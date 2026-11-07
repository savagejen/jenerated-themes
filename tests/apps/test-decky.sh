#!/usr/bin/env bash
# Tests for Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-decky.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
decky_theme() { printf '%s' "$SANDBOX/repo/app-themes/decky-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN its CSS Loader theme.json is valid JSON, is named after the palette,
#      uses manifest version 8, and injects shared.css into Steam's Big
#      Picture, Quick Access and main menu tabs
test_decky_theme_json_names_the_theme() {
  generate sunset
  result="$("$PYTHON" -c '
import json, sys
t = json.load(open(sys.argv[1]))
print(t["name"], t["manifest_version"], t["target"], t["inject"])
' "$(decky_theme sunset)/theme.json")"
  expected="Jenerated Sunset 8 System-Wide {'shared.css': ['SP', 'QuickAccess', 'MainMenu']}"
  [ "$result" = "$expected" ] || fail "expected '$expected', got '$result'"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN its CSS Loader stylesheet sets Steam's colors from the palette: the
#      darkest background, the panels, the text, the accent and the status
#      colors
test_decky_theme_uses_the_palette() {
  generate sunset
  css="$(decky_theme sunset)/shared.css"
  assert_file_contains "$css" "--gpSystemDarkestGrey: $(color bg_chrome) !important;"
  assert_file_contains "$css" "--gpSystemDarkerGrey: $(color bg) !important;"
  assert_file_contains "$css" "--gpSystemLightestGrey: $(color text) !important;"
  assert_file_contains "$css" "--gpColor-Blue: $(color accent) !important;"
  assert_file_contains "$css" "--gpColor-Green: $(color green) !important;"
  assert_file_contains "$css" "--gpColor-Red: $(color red) !important;"
  assert_file_contains "$css" "--gpBackground-Neutral-LightSoft: rgba($(color_rgb text), 0.2) !important;"
}

# GIVEN the Sunset palette
# WHEN generating it and reading every custom property its stylesheet sets
# THEN each is one of the color names Steam itself defines (so a typo can't
#      silently do nothing), and the braces balance
test_decky_theme_only_sets_steams_color_names() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
steam = set("""
gpSystemDarkestGrey gpSystemDarkerGrey gpSystemDarkGrey gpSystemGrey
gpSystemLightGrey gpSystemLighterGrey gpSystemLightestGrey
gpStoreDarkestGrey gpStoreDarkerGrey gpStoreDarkGrey gpStoreGrey
gpStoreLightGrey gpStoreLighterGrey gpStoreLightestGrey
gpColor-Blue gpColor-BlueHi gpColor-ChalkyBlue gpColor-DustyBlue gpColor-LightBlue
gpColor-Green gpColor-GreenHi gpColor-Orange gpColor-Red gpColor-RedHi gpColor-Yellow
gpBackground-DarkHard gpBackground-DarkMedium gpBackground-DarkSoft gpBackground-DarkSofter
gpBackground-LightHarder gpBackground-LightHard gpBackground-LightMedium
gpBackground-LightSoft gpBackground-LightSofter
gpBackground-Neutral-LightHarder gpBackground-Neutral-LightHard
gpBackground-Neutral-LightMedium gpBackground-Neutral-LightSoft
gpBackground-Neutral-LightSofter gpGradient-LibraryBackground
""".split())
css = re.sub(r"/\*.*?\*/", "", open(sys.argv[1]).read(), flags=re.S)
for name in re.findall(r"--([A-Za-z0-9-]+)\s*:", css):
    if name not in steam:
        print(f"--{name} is not one of Steam'"'"'s color names")
if css.count("{") != css.count("}"):
    print("the braces do not balance")
' "$(decky_theme sunset)/shared.css")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its CSS Loader theme folder is deleted, and the templates are kept
test_remove_deletes_the_decky_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/decky-theme/sunset/theme.json"
  assert_missing "$(decky_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/decky-theme/shared.css.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system with Decky Loader installed (a ~/homebrew folder)
# WHEN choosing Decky Loader and Blue Purple
# THEN the theme folder is linked into ~/homebrew/themes, and it explains how
#      to turn it on in CSS Loader, without saying Decky is missing
test_decky_links_the_theme() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/homebrew/plugins"
  install_app decky blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/homebrew/themes/Jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/decky-theme/blue-purple"
  assert_contains "choose CSS Loader"
  assert_contains "Turn on \"Jenerated Blue Purple\"."
  assert_not_contains "Decky Loader isn't installed yet"
}

# GIVEN a Linux system without Decky Loader (no ~/homebrew folder)
# WHEN choosing Decky Loader and Sunset
# THEN it says Decky Loader isn't installed and where to get it, and links the
#      theme anyway, ready for when it is
test_decky_explains_when_decky_is_missing() {
  fake_os Linux
  install_app decky sunset "y\n1\n"
  assert_status 0
  assert_contains "Decky Loader isn't installed yet"
  assert_contains "https://decky.xyz"
  assert_link "$SANDBOX/home/homebrew/themes/Jenerated-sunset" \
    "$SANDBOX/repo/app-themes/decky-theme/sunset"
}

run_tests
