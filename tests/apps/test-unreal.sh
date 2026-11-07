#!/usr/bin/env bash
# Tests for Unreal Engine: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-unreal.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
unreal_theme() { printf '%s' "$SANDBOX/repo/app-themes/unreal-theme/jenerated-$1.json"; }

# --- Tests: making the theme -------------------------------------------------

# unreal_colors path -> prints the theme's colors as "Name #rrggbb alpha", one
# per line, converting Unreal's linear-light values back to sRGB.
unreal_colors() {
  "$PYTHON" -c '
import json, re, sys
def srgb(v):
    return round(255 * (v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055))
for key, value in json.load(open(sys.argv[1]))["Colors"].items():
    r, g, b, a = (float(x) for x in re.findall(r"=([0-9.]+)", value))
    print(key.split("::")[1], "#%02x%02x%02x" % (srgb(r), srgb(g), srgb(b)), a)
' "$1"
}

# GIVEN the Sunset palette
# WHEN generating it and turning its Unreal Engine theme's colors back into
#      sRGB
# THEN it's named after the palette, and the panels, text, primary buttons,
#      selections and errors come out as the palette's own colors
test_unreal_theme_uses_the_palette() {
  generate sunset
  name="$("$PYTHON" -c 'import json, sys; print(json.load(open(sys.argv[1]))["DisplayName"])' "$(unreal_theme sunset)")"
  [ "$name" = "Jenerated Sunset" ] || fail "expected DisplayName 'Jenerated Sunset', got '$name'"
  colors="$(unreal_colors "$(unreal_theme sunset)")"
  for pair in "Panel bg" "Foreground text" "Primary accent" "Select accent" \
    "SelectInactive bg_selected" "Error red" "AccentFolder accent_soft"; do
    set -- $pair
    expected="$1 $(color "$2" | tr 'A-F' 'a-f') 1.0"
    printf '%s\n' "$colors" | grep -qx "$expected" ||
      fail "expected '$expected', got '$(printf '%s\n' "$colors" | grep "^$1 ")'"
  done
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Unreal Engine theme the way Unreal 5
#      does
# THEN it has a numeric Version, an Id in a form Unreal parses, a
#      DisplayName, and a Colors object whose keys are every one of Unreal's
#      named style colors (EStyleColor::...), once each, with values in the
#      "(R=..,G=..,B=..,A=..)" form, each from 0 to 1
test_unreal_theme_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import json, re, sys
names = ["Black", "Background", "Title", "WindowBorder", "Foldout", "Input", "InputOutline", "Recessed", "Panel", "Header", "Dropdown", "DropdownOutline", "Hover", "Hover2", "White", "White25", "Highlight", "Primary", "PrimaryHover", "PrimaryPress", "Secondary", "Foreground", "ForegroundHover", "ForegroundInverted", "ForegroundHeader", "Select", "SelectInactive", "SelectParent", "SelectHover", "Notifications", "AccentBlue", "AccentPurple", "AccentPink", "AccentRed", "AccentOrange", "AccentYellow", "AccentGreen", "AccentBrown", "AccentBlack", "AccentGray", "AccentWhite", "AccentFolder", "Warning", "Error", "Success"]
def unique(pairs):
    keys = [k for k, _ in pairs]
    for k in set(keys):
        if keys.count(k) > 1:
            print(f"{k} appears twice")
    return dict(pairs)
theme = json.load(open(sys.argv[1]), object_pairs_hook=unique)
if not isinstance(theme.get("Version"), (int, float)):
    print("Version is not a number")
if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", str(theme.get("Id"))):
    print("Id is not a GUID:", theme.get("Id"))
if not isinstance(theme.get("DisplayName"), str):
    print("DisplayName is not a string")
colors = theme["Colors"]
for key in set(colors) - {"EStyleColor::" + n for n in names}:
    print(f"{key} is not one of Unreal'"'"'s style colors")
for name in names:
    value = colors.get("EStyleColor::" + name)
    if value is None:
        print(f"{name} is missing")
        continue
    m = re.fullmatch(r"\(R=([0-9.]+),G=([0-9.]+),B=([0-9.]+),A=([0-9.]+)\)", value)
    if not m:
        print(f"{name} is {value}")
    elif not all(0 <= float(x) <= 1 for x in m.groups()):
        print(f"{name} is out of range: {value}")
' "$(unreal_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN the Sunset and Blue Purple palettes
# WHEN generating both
# THEN their Unreal Engine themes have different Ids, so Unreal lists both
test_unreal_themes_have_their_own_ids() {
  generate sunset blue-purple
  ids="$(cat "$(unreal_theme sunset)" "$(unreal_theme blue-purple)" | grep '"Id"' | sort -u | wc -l)"
  [ "$ids" -eq 2 ] || fail "expected 2 different Ids, got $ids"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Unreal Engine theme is deleted, and the template is kept
test_remove_deletes_the_unreal_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/unreal-theme/jenerated-sunset.json"
  assert_missing "$(unreal_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/unreal-theme/theme.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Linux
# WHEN choosing Unreal Engine and Blue Purple
# THEN the theme is linked into Unreal's folder for your own themes, in
#      ~/.config/Epic, and it explains where to choose it and to duplicate it
#      before editing
test_unreal_links_the_theme() {
  fake_os Linux
  install_app unreal blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/Epic/UnrealEngine/Slate/Themes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/unreal-theme/jenerated-blue-purple.json"
  assert_contains "Editor Preferences -> General -> Appearance"
  assert_contains 'choose "Jenerated Blue Purple" as the Active Theme.'
  assert_contains "choose Duplicate"
}

# GIVEN a Mac
# WHEN choosing Unreal Engine
# THEN the theme goes in ~/Library/Application Support/Epic, where Unreal
#      keeps your settings on a Mac
test_unreal_on_macos_uses_application_support() {
  fake_os Darwin
  install_app unreal blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/Epic/UnrealEngine/Slate/Themes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/unreal-theme/jenerated-blue-purple.json"
}

run_tests
