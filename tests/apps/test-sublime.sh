#!/usr/bin/env bash
# Tests for Sublime Text: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-sublime.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
sublime_scheme() { printf '%s' "$SANDBOX/repo/app-themes/sublime-theme/jenerated-$1.sublime-color-scheme"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN its Sublime Text color scheme is valid JSON named after the palette,
#      with the editor's background, text, caret and selection, and strings,
#      keywords and functions in the palette's colors (as in the VS Code theme)
test_sublime_scheme_uses_the_palette() {
  generate sunset
  result="$("$PYTHON" -c '
import json, sys
t = json.load(open(sys.argv[1]))
g = t["globals"]
by_name = {r["name"]: r for r in t["rules"]}
print(t["name"], g["background"], g["foreground"], g["caret"], g["selection"],
      by_name["String"]["foreground"], by_name["Keyword"]["foreground"], by_name["Function"]["foreground"])
' "$(sublime_scheme sunset)")"
  expected="Jenerated Sunset $(color bg) $(color text) $(color accent) $(color selection) $(color green) $(color accent_soft) $(color accent_light)"
  [ "$result" = "$expected" ] || fail "expected '$expected', got '$result'"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its color scheme
# THEN every global is one Sublime Text's docs list, colors are #rrggbb, and
#      every rule has a scope and uses only the font styles Sublime Text knows
test_sublime_scheme_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import json, re, sys
known = set("""background foreground invisibles caret line_highlight block_caret block_caret_border
block_caret_underline block_caret_corner_style block_caret_corner_radius misspelling fold_marker
minimap_border accent popup_css phantom_css sheet_css gutter gutter_foreground gutter_foreground_highlight
line_diff_width line_diff_added line_diff_modified line_diff_deleted selection selection_foreground
selection_border selection_border_width inactive_selection inactive_selection_border
inactive_selection_foreground selection_corner_style selection_corner_radius highlight find_highlight
find_highlight_foreground scroll_highlight scroll_selected_highlight rulers guide active_guide stack_guide
brackets_options brackets_foreground bracket_contents_options bracket_contents_foreground tags_options
tags_foreground shadow shadow_width""".split())
options = {"brackets_options", "tags_options", "bracket_contents_options"}
styles = {"bold", "italic", "glow", "underline", "stippled_underline", "squiggly_underline"}
t = json.load(open(sys.argv[1]))
for key, value in t["globals"].items():
    if key not in known:
        print(f"{key} is not a Sublime Text global")
    elif key not in options and not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        print(f"{key} is {value}")
for rule in t["rules"]:
    name = rule.get("name")
    if not rule.get("scope"):
        print(f"rule {name} has no scope")
    for part in rule.get("font_style", "").split():
        if part not in styles:
            print(f"rule {name} has font style {part}")
    for key in ("foreground", "background"):
        if key in rule and not re.fullmatch(r"#[0-9a-fA-F]{6}", rule[key]):
            print(f"rule {name} {key} is {rule[key]}")
' "$(sublime_scheme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Sublime Text color scheme is deleted, and the template is kept
test_remove_deletes_the_sublime_scheme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/sublime-theme/jenerated-sunset.sublime-color-scheme"
  assert_missing "$(sublime_scheme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/sublime-theme/color-scheme.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Sublime Text 4
# WHEN choosing Sublime Text and Blue Purple
# THEN the color scheme is linked into its Packages/User folder, and it says
#      to choose the scheme and the Adaptive theme from the command palette
test_sublime_links_the_color_scheme() {
  fake_os Linux
  install_app sublime blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/sublime-text/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
    "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
  assert_missing "$SANDBOX/home/.config/sublime-text-3"
  assert_contains '"UI: Select Color Scheme", then "Jenerated Blue Purple"'
  assert_contains '"Adaptive"'
}

# GIVEN Sublime Text 3's folder, and Sublime Text installed through Flatpak
#       and through Snap
# WHEN choosing Sublime Text
# THEN each of their Packages/User folders gets the color scheme too
test_sublime_themes_st3_flatpak_and_snap() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/sublime-text-3" "$SANDBOX/home/.var/app/com.sublimetext.three" \
    "$SANDBOX/home/snap/sublime-text"
  install_app sublime blue-purple "y\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/sublime-text" "$SANDBOX/home/.config/sublime-text-3" \
    "$SANDBOX/home/.var/app/com.sublimetext.three/config/sublime-text" \
    "$SANDBOX/home/snap/sublime-text/current/.config/sublime-text"; do
    assert_link "$dir/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
      "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
  done
}

# GIVEN a Mac
# WHEN choosing Sublime Text
# THEN the color scheme goes in Application Support
test_sublime_on_macos_uses_application_support() {
  fake_os Darwin
  install_app sublime blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/Sublime Text/Packages/User/jenerated-blue-purple.sublime-color-scheme" \
    "$SANDBOX/repo/app-themes/sublime-theme/jenerated-blue-purple.sublime-color-scheme"
}

run_tests
