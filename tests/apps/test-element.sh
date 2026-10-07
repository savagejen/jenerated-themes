#!/usr/bin/env bash
# Tests for Element (Matrix chat): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-element.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
element_theme() { printf '%s' "$SANDBOX/repo/app-themes/element-theme/$1/jenerated-$1.json"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette, and a light palette
# WHEN generating them
# THEN each Element theme is valid JSON named after the palette and marked
#      dark or light, with the timeline, room list and accent from the
#      palette in both its colors and its Compound tokens, and 8 username
#      and avatar colors
test_element_theme_uses_the_palette() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  result="$("$PYTHON" -c '
import json, sys
for path in sys.argv[1:]:
    t = json.load(open(path))
    c, k = t["colors"], t["compound"]
    print(t["name"], t["is_dark"], c["timeline-background-color"], c["roomlist-background-color"],
          c["accent-color"], k["--cpd-color-bg-canvas-default"], k["--cpd-color-text-primary"],
          k["--cpd-color-bg-action-primary-rest"], len(c["username-colors"]), len(c["avatar-background-colors"]))
' "$(element_theme sunset)" "$(element_theme daylight)")"
  expected="Jenerated Sunset True $(color bg) $(color bg_sidebar) $(color accent) $(color bg) $(color text) $(color accent) 8 8
Jenerated Daylight False #fbfbfd $(color bg_sidebar) $(color accent) #fbfbfd $(color text) $(color accent) 8 8"
  [ "$result" = "$expected" ] || fail "expected:
$expected"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Element theme
# THEN every Compound token it sets is a real semantic token of Compound
#      10.2 (Element ignores unknown ones), and every color is #rrggbb, or
#      #rrggbbaa for the see-through ones
test_element_theme_uses_real_compound_tokens() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import json, re, sys
tokens = set("""bg-accent-hovered bg-accent-pressed bg-accent-rest bg-accent-selected bg-action-primary-disabled
bg-action-primary-hovered bg-action-primary-pressed bg-action-primary-rest bg-action-secondary-hovered
bg-action-secondary-pressed bg-action-secondary-rest bg-action-tertiary-hovered bg-action-tertiary-rest
bg-action-tertiary-selected bg-badge-accent bg-badge-critical bg-badge-default bg-badge-info bg-badge-primary
bg-badge-secondary bg-canvas-default bg-canvas-default-level-1 bg-canvas-disabled bg-critical-hovered
bg-critical-primary bg-critical-subtle bg-critical-subtle-hovered bg-decorative-1 bg-decorative-2 bg-decorative-3
bg-decorative-4 bg-decorative-5 bg-decorative-6 bg-info-subtle bg-subtle-primary bg-subtle-secondary
bg-subtle-secondary-level-0 bg-success-subtle border-accent-primary border-accent-subtle border-critical-hovered
border-critical-primary border-critical-subtle border-disabled border-focused border-info-subtle
border-interactive-hovered border-interactive-primary border-interactive-secondary border-success-subtle
icon-accent-primary icon-accent-tertiary icon-critical-primary icon-disabled icon-info-primary icon-on-solid-primary
icon-primary icon-quaternary icon-secondary icon-success-primary icon-tertiary text-action-accent
text-action-primary text-badge-accent text-badge-info text-critical-primary text-decorative-1 text-decorative-2
text-decorative-3 text-decorative-4 text-decorative-5 text-decorative-6 text-disabled text-info-primary
text-link-external text-on-solid-primary text-primary text-secondary text-success-primary""".split())
t = json.load(open(sys.argv[1]))
for token, value in t["compound"].items():
    if token.removeprefix("--cpd-color-") not in tokens:
        print(f"{token} is not a Compound token")
    if not re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", value):
        print(f"{token} is {value}")
for name, value in t["colors"].items():
    for v in value if isinstance(value, list) else [value]:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", v):
            print(f"{name} has {v}")
' "$(element_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Element folder is deleted, and the template is kept
test_remove_deletes_the_element_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/element-theme/sunset/jenerated-sunset.json"
  assert_missing "$SANDBOX/repo/app-themes/element-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/element-theme/theme.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Element Desktop without a config.json of its own
# WHEN choosing Element and Blue Purple
# THEN ~/.config/Element/config.json is created with Blue Purple's theme as
#      a custom theme, and it says to restart Element and choose the theme
test_element_creates_config_json() {
  fake_os Linux
  install_app element blue-purple
  assert_status 0
  result="$("$(find_python)" -c '
import json, sys
c = json.load(open(sys.argv[1]))
print([t["name"] for t in c["setting_defaults"]["custom_themes"]])
' "$SANDBOX/home/.config/Element/config.json")"
  [ "$result" = "['Jenerated Blue Purple']" ] || fail "expected just Blue Purple's theme, got $result"
  assert_missing "$SANDBOX/home/.config/Element/config.json.before-jenerated"
  assert_contains "Restart Element"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN an Element config.json with a homeserver, another setting, someone
#       else's custom theme, and a Jenerated theme from before
# WHEN choosing Element and Sunset
# THEN the file is backed up, and keeps the homeserver, the setting and the
#      other theme, with the old Jenerated theme replaced by Sunset's
test_element_keeps_the_rest_of_config_json() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/Element"
  printf '%s\n' '{"default_server_config": {"m.homeserver": {"base_url": "https://matrix.example.org"}},' \
    ' "setting_defaults": {"showHiddenEventsInTimeline": true, "custom_themes": [' \
    '  {"name": "Other Theme", "is_dark": true, "colors": {}},' \
    '  {"name": "Jenerated Blue Purple", "is_dark": true, "colors": {}}]}}' \
    >"$SANDBOX/home/.config/Element/config.json"
  cp "$SANDBOX/home/.config/Element/config.json" "$SANDBOX/original.json"
  install_app element sunset
  assert_status 0
  result="$("$(find_python)" -c '
import json, sys
c = json.load(open(sys.argv[1]))
d = c["setting_defaults"]
print(c["default_server_config"]["m.homeserver"]["base_url"], d["showHiddenEventsInTimeline"],
      [t["name"] for t in d["custom_themes"]])
' "$SANDBOX/home/.config/Element/config.json")"
  [ "$result" = "https://matrix.example.org True ['Other Theme', 'Jenerated Sunset']" ] || fail "got $result"
  assert_same_file "$SANDBOX/home/.config/Element/config.json.before-jenerated" "$SANDBOX/original.json"
}

# GIVEN an Element config.json that isn't valid JSON
# WHEN choosing Element
# THEN it stops, saying it couldn't update the file, and leaves it as it was
test_element_stops_on_a_broken_config_json() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/Element"
  printf '{"brand": "Element",\n' >"$SANDBOX/home/.config/Element/config.json"
  install_app element blue-purple
  assert_status 1
  assert_contains "couldn't update $SANDBOX/home/.config/Element/config.json (is it valid JSON?)"
  assert_file_equals "$SANDBOX/home/.config/Element/config.json" '{"brand": "Element",'
}

# GIVEN Element installed through Flatpak, and on a Mac
# WHEN choosing Element
# THEN the Flatpak's settings folder gets the theme too; and on a Mac it
#      goes in Application Support
test_element_themes_the_flatpak_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/im.riot.Riot"
  install_app element blue-purple
  assert_status 0
  assert_file_contains "$SANDBOX/home/.var/app/im.riot.Riot/config/Element/config.json" "Jenerated Blue Purple"
  assert_file_contains "$SANDBOX/home/.config/Element/config.json" "Jenerated Blue Purple"
  fake_os Darwin
  install_app element blue-purple
  assert_status 0
  assert_file_contains "$SANDBOX/home/Library/Application Support/Element/config.json" "Jenerated Blue Purple"
}

run_tests
