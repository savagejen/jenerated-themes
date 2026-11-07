#!/usr/bin/env bash
# Tests for Mattermost: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-mattermost.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
mattermost_theme() { printf '%s' "$SANDBOX/repo/app-themes/mattermost-theme/$1.json"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette, and a light palette
# WHEN generating them
# THEN each Mattermost theme is valid JSON with every color Mattermost's
#      custom theme editor has (plus mentionBj, the older spelling of
#      mentionBg that its own themes still set), each a #rrggbb color from
#      the palette, and a code theme that suits the palette: Monokai for
#      dark, GitHub for light
test_mattermost_theme_has_every_color() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  OUTPUT="$("$PYTHON" -c '
import json, re, sys
keys = """sidebarBg sidebarText sidebarUnreadText sidebarTextHoverBg sidebarTextActiveBorder
sidebarTextActiveColor sidebarHeaderBg sidebarHeaderTextColor sidebarTeamBarBg onlineIndicator
awayIndicator dndIndicator mentionBg mentionBj mentionColor centerChannelBg centerChannelColor
newMessageSeparator linkColor buttonBg buttonColor errorTextColor mentionHighlightBg
mentionHighlightLink""".split()
for path, code in ((sys.argv[1], "monokai"), (sys.argv[2], "github")):
    t = json.load(open(path))
    for key in keys:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", t.get(key, "")):
            print(f"{path}: {key} is {t.get(key)}")
    extra = set(t) - set(keys) - {"type", "codeTheme"}
    if extra:
        print(f"{path}: unknown keys {sorted(extra)}")
    kind, code_theme = t.get("type"), t.get("codeTheme")
    if kind != "custom" or code_theme != code:
        print(f"{path}: type {kind}, codeTheme {code_theme}")
' "$(mattermost_theme sunset)" "$(mattermost_theme daylight)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
  theme="$(mattermost_theme sunset)"
  assert_file_contains "$theme" "\"centerChannelBg\": \"$(color bg)\""
  assert_file_contains "$theme" "\"sidebarBg\": \"$(color bg_sidebar)\""
  assert_file_contains "$theme" "\"buttonBg\": \"$(color accent)\""
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Mattermost theme is deleted, and the template is kept
test_remove_deletes_the_mattermost_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/mattermost-theme/sunset.json"
  assert_missing "$(mattermost_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/mattermost-theme/theme.json.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Mattermost and Blue Purple
# THEN it prints Blue Purple's Mattermost theme on one line, as valid JSON
#      with the palette's colors, copies it to the clipboard, and explains
#      where to paste it
test_mattermost_prints_and_copies_the_theme() {
  fake_os Linux
  install_app mattermost blue-purple
  assert_status 0
  assert_contains "(Copied to your clipboard.)"
  assert_contains "Copy and paste to share theme colors"
  result="$("$(find_python)" -c '
import json, sys
theme = json.loads(open(sys.argv[1]).read())
print(theme["type"], theme["centerChannelBg"], theme["codeTheme"])
' "$SANDBOX/clipboard")"
  [ "$result" = "custom #12131c monokai" ] || fail "expected the clipboard to hold Blue Purple's theme, got: $result"
  line="$(printf '%s\n' "$OUTPUT" | grep '^{ "type": "custom"')"
  [ "$line" = "$(cat "$SANDBOX/clipboard")" ] || fail "expected the printed theme, on one line, to be what was copied"
}

run_tests
