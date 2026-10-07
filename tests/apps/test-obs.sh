#!/usr/bin/env bash
# Tests for OBS Studio (streaming and recording): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-obs.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
obs_style() { printf '%s' "$SANDBOX/repo/app-themes/obs-theme/jenerated-$1.ovt"; }

# --- Tests: making the theme -------------------------------------------------

# obs_var path name -> prints the value of an OBS style's --name variable.
obs_var() { sed -n "s/^ *--$2: *\(.*\);$/\1/p" "$1"; }

# GIVEN the Sunset palette and a light palette
# WHEN generating them
# THEN each OBS style is named after its palette, builds on OBS's Yami theme
#      for Sunset and Yami's Light style for the light palette (marked dark
#      and light to match), and colors the docks, text, focus outlines and
#      audio meters from the palette
test_obs_style_uses_the_palette() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  style="$(obs_style sunset)"
  assert_file_contains "$style" "name: 'Jenerated Sunset';"
  assert_file_contains "$style" "id: 'com.jenerated.sunset';"
  assert_file_contains "$style" "extends: 'com.obsproject.Yami';"
  assert_file_contains "$style" "dark: 'true';"
  assert_file_contains "$(obs_style daylight)" "extends: 'com.obsproject.Yami.Light';"
  assert_file_contains "$(obs_style daylight)" "dark: 'false';"
  for pair in "bg_base bg" "text text" "primary accent" "input_border_focus accent" "palette_link accent_soft"; do
    set -- $pair
    [ "$(obs_var "$style" "$1")" = "$(color "$2")" ] ||
      fail "expected --$1 to be $(color "$2"), got '$(obs_var "$style" "$1")'"
  done
  assert_file_contains "$style" "qproperty-foregroundNominalColor: $(color green);"
  assert_file_contains "$style" "qproperty-backgroundNominalColor: rgba($(color_rgb green | tr -d ' '),0.3);"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its OBS style the way OBS 30 and later do
# THEN it has the metadata OBS needs for a style (a name, an id and the theme
#      it extends, each quoted), every variable is a #rrggbb color (the only
#      form OBS reads besides rgb()), it sets every color in the ramps Yami's
#      stylesheet uses, and each rgba() in the stylesheet is valid
test_obs_style_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
text = open(sys.argv[1]).read()
meta = re.search(r"@OBSThemeMeta \{(.*?)\}", text, re.S)
if not meta:
    print("no @OBSThemeMeta block")
else:
    fields = dict(re.findall(r"(\w+): \x27([^\x27]*)\x27;", meta.group(1)))
    for key in ("name", "id", "extends", "dark"):
        if key not in fields:
            print(f"meta has no {key}")
    if fields.get("dark") not in ("true", "false"):
        print("dark is not true or false")
block = re.search(r"@OBSThemeVars \{(.*?)\n\}", text, re.S)
if not block:
    print("no @OBSThemeVars block")
    sys.exit()
body = re.sub(r"/\*.*?\*/", "", block.group(1), flags=re.S)
names = set()
for line in filter(None, (l.strip() for l in body.splitlines())):
    m = re.fullmatch(r"--([a-zA-Z0-9_]+): (#[0-9a-fA-F]{6});", line)
    if not m:
        print(f"not a color variable: {line}")
    else:
        names.add(m.group(1))
ramps = {f"{hue}{i}" for hue in ("grey",) for i in range(1, 9)}
ramps |= {f"{hue}{i}" for hue in ("blue", "red", "pink", "purple", "teal", "green", "yellow") for i in range(1, 7)}
ramps |= {f"{hue}{i}" for hue in ("white", "black") for i in range(1, 6)}
for name in sorted(ramps - names):
    print(f"--{name} is not set")
rest = text[block.end():]
if rest.count("{") != rest.count("}"):
    print("unbalanced braces in the stylesheet")
for args in re.findall(r"rgba\(([^)]*)\)", rest):
    parts = args.split(",")
    if len(parts) != 4 or not all(p.isdigit() and int(p) < 256 for p in parts[:3]) or not 0 <= float(parts[3]) <= 1:
        print(f"bad rgba({args})")
if "var(--" in rest:
    print("the stylesheet uses a variable")
' "$(obs_style sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its OBS style is deleted, and the template is kept
test_remove_deletes_the_obs_style() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/obs-theme/jenerated-sunset.ovt"
  assert_missing "$(obs_style sunset)"
  assert_exists "$SANDBOX/repo/app-themes/obs-theme/style.ovt.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN OBS Studio installed the usual way and through Flatpak
# WHEN choosing OBS Studio and Blue Purple
# THEN the style is linked into both themes folders, and it explains where
#      to choose it
test_obs_links_the_style() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/com.obsproject.Studio"
  install_app obs blue-purple "y\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/obs-studio/themes" \
    "$SANDBOX/home/.var/app/com.obsproject.Studio/config/obs-studio/themes"; do
    assert_link "$dir/jenerated-blue-purple.ovt" "$SANDBOX/repo/app-themes/obs-theme/jenerated-blue-purple.ovt"
  done
  assert_contains "Settings -> Appearance"
  assert_contains 'Choose Yami as the Theme, and "Jenerated Blue Purple" as the Style.'
}

# GIVEN a Mac
# WHEN choosing OBS Studio
# THEN the style goes in ~/Library/Application Support/obs-studio/themes
test_obs_on_macos_uses_application_support() {
  fake_os Darwin
  install_app obs blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/obs-studio/themes/jenerated-blue-purple.ovt" \
    "$SANDBOX/repo/app-themes/obs-theme/jenerated-blue-purple.ovt"
}

run_tests
