#!/usr/bin/env bash
# Tests for Godot: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-godot.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
godot_theme() { printf '%s' "$SANDBOX/repo/app-themes/godot-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Godot script editor theme as an INI
#      file
# THEN it has a [color_theme] section setting the background, text,
#      keywords, strings and GDScript colors from the palette
test_godot_theme_uses_the_palette() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import configparser, sys
c = configparser.ConfigParser(comment_prefixes=(";",), interpolation=None)
c.optionxform = str
c.read(sys.argv[1])
t = c["color_theme"]
for key in ("background_color", "text_color", "keyword_color", "string_color", "gdscript/node_path_color"):
    print(key, t[key].strip(chr(34)))
' "$(godot_theme sunset)/Jenerated-sunset.tet")"
  expected="background_color $(color bg)
text_color $(color text)
keyword_color $(color accent)
string_color $(color green)
gdscript/node_path_color $(color yellow)"
  [ "$OUTPUT" = "$expected" ] || fail "expected:
$expected"
}

# GIVEN the Sunset palette
# WHEN generating it and reading every key in its Godot theme
# THEN each is one of Godot's text editor color settings (so a typo can't
#      silently do nothing), and each value is a quoted #rrggbb or #rrggbbaa
test_godot_theme_only_sets_godots_color_settings() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
godot = set("""
symbol_color keyword_color control_flow_keyword_color base_type_color engine_type_color
user_type_color comment_color doc_comment_color string_color string_placeholder_color
background_color completion_background_color completion_selected_color
completion_existing_color completion_scroll_color completion_scroll_hovered_color
completion_font_color text_color line_number_color safe_line_number_color caret_color
caret_background_color text_selected_color selection_color brace_mismatch_color
current_line_color line_length_guideline_color word_highlighted_color number_color
function_color member_variable_color mark_color warning_color bookmark_color
breakpoint_color executing_line_color code_folding_color folded_code_region_color
search_result_color search_result_border_color warning_underline_color
error_underline_color gdscript/function_definition_color gdscript/global_function_color
gdscript/node_path_color gdscript/node_reference_color gdscript/annotation_color
gdscript/string_name_color comment_markers/critical_color comment_markers/warning_color
comment_markers/notice_color
""".split())
for line in open(sys.argv[1]).read().splitlines():
    if not line.strip() or line.startswith(";") or line == "[color_theme]":
        continue
    key, _, value = line.partition("=")
    if key not in godot:
        print(f"{key} is not one of Godot'"'"'s text editor color settings")
    if not re.fullmatch(r"\"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?\"", value):
        print(f"{key} has {value}, not a quoted color")
' "$(godot_theme sunset)/Jenerated-sunset.tet")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN the Sunset palette, and a light palette
# WHEN generating them
# THEN each one's Godot settings use its sidebar as the base color and its
#      accent, as 0-to-1 numbers, choose its script editor theme, and use
#      Godot's dark contrast (0.3) for Sunset and its light one (-0.06) for
#      the light palette
test_godot_settings_use_the_palette() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  settings="$(godot_theme sunset)/editor-settings.cfg"
  float() { color_rgb "$@" | awk -F', ' '{printf "%.4f, %.4f, %.4f", $1/255, $2/255, $3/255}'; }
  assert_file_contains "$settings" 'interface/theme/color_preset = "Custom"'
  assert_file_contains "$settings" 'interface/theme/preset = "Custom"'
  assert_file_contains "$settings" "interface/theme/base_color = Color($(float bg_sidebar), 1)"
  assert_file_contains "$settings" "interface/theme/accent_color = Color($(float accent), 1)"
  assert_file_contains "$settings" "interface/theme/contrast = 0.3"
  assert_file_contains "$settings" 'text_editor/theme/color_theme = "Jenerated-sunset"'
  assert_file_contains "$settings" ";   Interface > Theme > Base Color: $(color bg_sidebar)"
  assert_file_contains "$(godot_theme daylight)/editor-settings.cfg" "interface/theme/contrast = -0.06"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Godot theme folder is deleted, and the templates are kept
test_remove_deletes_the_godot_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/godot-theme/sunset/Jenerated-sunset.tet"
  assert_missing "$(godot_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/godot-theme/text-editor.tet.tmpl"
}

# --- Tests: installing -------------------------------------------------------

GODOT_CFG=".config/godot"

# godot_settings path -> writes a small Godot editor settings file with the
# default color preset, base color and script editor theme.
godot_settings() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '[gd_resource type="EditorSettings" format=3]' '' '[resource]' \
    'interface/theme/color_preset = "Default"' \
    'interface/theme/base_color = Color(0.14, 0.14, 0.14, 1)' \
    'text_editor/theme/color_theme = "Default"' >"$1"
}

# GIVEN a Linux system where Godot has never been opened (no settings)
# WHEN choosing Godot and Blue Purple
# THEN the script editor theme is linked where Godot looks for it, and it
#      explains that Godot has to be opened first, with the settings to
#      change by hand
test_godot_links_the_theme_and_explains_before_first_run() {
  fake_os Linux
  fake_command pgrep "exit 1"
  install_app godot blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
  assert_contains "Godot hasn't been opened yet"
  assert_contains "Interface > Theme > Color Preset: Custom"
  assert_contains "Text Editor > Theme > Color Theme: Jenerated-blue-purple"
}

# GIVEN Godot's settings for 4.5 and 4.6, and Godot closed
# WHEN choosing Godot and Blue Purple, and answering yes to setting colors
# THEN the 4.6 settings are backed up, then get Blue Purple's settings (each
#      key once, replacing the old line or added), 4.5's are left alone, and
#      it says how to go back
test_godot_sets_the_editor_colors_when_asked() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.5.tres"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  install_app godot blue-purple "y\n"
  assert_status 0
  settings="$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  assert_same_file "$settings.before-jenerated" "$SANDBOX/original.tres"
  while IFS= read -r line; do
    case "$line" in ";"* | "") continue ;; esac
    [ "$(grep -cxF -- "$line" "$settings")" = 1 ] || fail "expected one line '$line' in $settings"
  done <"$SANDBOX/repo/app-themes/godot-theme/blue-purple/editor-settings.cfg"
  assert_file_not_contains "$settings" "Color(0.14, 0.14, 0.14, 1)"
  assert_file_contains "$settings" "[resource]"
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.5.tres" "$SANDBOX/original.tres"
  assert_contains "Updated $settings"
  assert_contains "cp \"$settings.before-jenerated\" \"$settings\""
}

# GIVEN Godot's script editor theme already linked, but to an old copy
#       elsewhere
# WHEN choosing Godot and Blue Purple, and answering yes to replacing it and
#      then no to changing the settings
# THEN the link is replaced after asking (the question reads the answer
#      typed, not jenerate's own list of folders)
test_godot_asks_before_replacing_an_old_link() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  mkdir -p "$SANDBOX/home/$GODOT_CFG/text_editor_themes" "$SANDBOX/old"
  : >"$SANDBOX/old/Jenerated-blue-purple.tet"
  ln -s "$SANDBOX/old/Jenerated-blue-purple.tet" "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet"
  install_app godot blue-purple "y\nn\n"
  assert_status 0
  assert_contains "Replace it with a link to $SANDBOX/repo?"
  assert_link "$SANDBOX/home/$GODOT_CFG/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
}

# GIVEN Godot's settings, already set to Blue Purple by jenerate
# WHEN choosing Godot and Sunset, and answering yes again
# THEN the settings get Sunset's, and the backup is still the settings from
#      before any palette
test_godot_keeps_the_first_backup() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  install_app godot blue-purple "y\n"
  install_app godot sunset "y\n"
  assert_status 0
  settings="$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  assert_file_contains "$settings" 'text_editor/theme/color_theme = "Jenerated-sunset"'
  assert_file_not_contains "$settings" "Jenerated-blue-purple"
  assert_same_file "$settings.before-jenerated" "$SANDBOX/original.tres"
}

# GIVEN Godot's settings, and Godot closed
# WHEN choosing Godot and answering no to setting colors
# THEN the settings are left alone, with no backup, and the settings to
#      change by hand are shown
test_godot_leaves_the_settings_when_declined() {
  fake_os Linux
  fake_command pgrep "exit 1"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  install_app godot blue-purple "n\n"
  assert_status 0
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  assert_missing "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres.before-jenerated"
  assert_contains "Interface > Theme > Color Preset: Custom"
}

# GIVEN Godot's settings, and Godot running
# WHEN choosing Godot
# THEN it doesn't offer to change the settings (Godot would overwrite them
#      when it closes), says to close it first, and shows the settings to
#      change by hand
test_godot_waits_while_godot_is_open() {
  fake_os Linux
  fake_command pgrep "exit 0"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  cp "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  install_app godot blue-purple
  assert_status 0
  assert_contains "Godot is open"
  assert_not_contains "Set Godot's editor colors"
  assert_same_file "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres" "$SANDBOX/original.tres"
  assert_contains "Interface > Theme > Base Color:"
}

# GIVEN Godot installed through Flatpak, with its own settings, as well as
#       the usual settings folder
# WHEN choosing Godot and answering yes
# THEN the theme is linked into both, and both settings files are updated
test_godot_themes_the_flatpak_too() {
  fake_os Linux
  fake_command pgrep "exit 1"
  flatpak="$SANDBOX/home/.var/app/org.godotengine.Godot/config/godot"
  godot_settings "$flatpak/editor_settings-4.6.tres"
  godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-4.6.tres"
  install_app godot blue-purple "y\n"
  assert_status 0
  for dir in "$SANDBOX/home/$GODOT_CFG" "$flatpak"; do
    assert_link "$dir/text_editor_themes/Jenerated-blue-purple.tet" \
      "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
    assert_file_contains "$dir/editor_settings-4.6.tres" 'text_editor/theme/color_theme = "Jenerated-blue-purple"'
  done
}

# GIVEN Godot settings named editor_settings-4.tres (before 4.3),
#       -4.9.tres and -4.10.tres
# WHEN choosing Godot and answering yes
# THEN the newest, 4.10's, is the one updated
test_godot_updates_the_newest_settings() {
  fake_os Linux
  fake_command pgrep "exit 1"
  for version in 4 4.9 4.10; do
    godot_settings "$SANDBOX/home/$GODOT_CFG/editor_settings-$version.tres"
  done
  install_app godot blue-purple "y\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.10.tres" "Jenerated-blue-purple"
  assert_file_not_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.9.tres" "Jenerated"
  assert_file_not_contains "$SANDBOX/home/$GODOT_CFG/editor_settings-4.tres" "Jenerated"
}

# GIVEN a Mac with Godot's settings
# WHEN choosing Godot (also 9 on a Mac) and answering yes
# THEN the theme is linked into Godot's folder in Application Support, and
#      its settings are updated
test_godot_on_macos_uses_application_support() {
  fake_os Darwin
  fake_command pgrep "exit 1"
  dir="$SANDBOX/home/Library/Application Support/Godot"
  godot_settings "$dir/editor_settings-4.6.tres"
  install_app godot blue-purple "y\n"
  assert_status 0
  assert_link "$dir/text_editor_themes/Jenerated-blue-purple.tet" \
    "$SANDBOX/repo/app-themes/godot-theme/blue-purple/Jenerated-blue-purple.tet"
  assert_file_contains "$dir/editor_settings-4.6.tres" 'text_editor/theme/color_theme = "Jenerated-blue-purple"'
}

run_tests
