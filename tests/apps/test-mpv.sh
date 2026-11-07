#!/usr/bin/env bash
# Tests for mpv (media player): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-mpv.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
mpv_theme() { printf '%s' "$SANDBOX/repo/app-themes/mpv-theme/$1/jenerated-$1.conf"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN its mpv colors set the OSD text, its outline, the controller's
#      background and progress bar, and the console's focused item from the
#      palette
test_mpv_colors_use_the_palette() {
  generate sunset
  conf="$(mpv_theme sunset)"
  assert_file_contains "$conf" "osd-color=\"$(color text)\""
  assert_file_contains "$conf" "osd-border-color=\"$(color bg_chrome)\""
  assert_file_contains "$conf" "osd-back-color=\"#CC$(color bg_chrome | cut -c2-)\""
  assert_file_contains "$conf" "script-opts-append=\"osc-background_color=$(color bg_chrome)\""
  assert_file_contains "$conf" "script-opts-append=\"osc-timecode_color=$(color accent)\""
  assert_file_contains "$conf" "script-opts-append=\"console-focused_back_color=$(color accent)\""
}

# GIVEN the Sunset palette
# WHEN generating it and reading each setting as mpv would
# THEN every value is quoted (mpv reads an unquoted # as a comment), each
#      option is one mpv has (osd-border-color rather than 0.40's
#      osd-outline-color, which older versions don't know), each script
#      option is one the controller or console has, and each color is
#      #rrggbb (the controller reads exactly that) or, for the OSD, #aarrggbb
test_mpv_colors_follow_mpvs_rules() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
options = {"osd-color", "osd-border-color", "osd-back-color", "osd-selected-color",
           "osd-selected-outline-color", "script-opts-append"}
scripts = {
    "osc": {"background_color", "timecode_color", "title_color", "time_pos_color", "buttons_color",
            "small_buttonsL_color", "small_buttonsR_color", "top_buttons_color", "held_element_color",
            "time_pos_outline_color"},
    "console": {"focused_color", "focused_back_color", "match_color", "menu_outline_color"},
}
for line in open(sys.argv[1]).read().splitlines():
    if not line or line.startswith("#"):
        continue
    m = re.fullmatch(r"([a-z-]+)=\"([^\"]*)\"", line)
    if not m:
        print(f"not option=\"value\": {line}")
        continue
    option, value = m.groups()
    if option not in options:
        print(f"unknown option: {option}")
    elif option == "script-opts-append":
        script, _, rest = value.partition("-")
        key, _, color = rest.partition("=")
        if key not in scripts.get(script, set()):
            print(f"unknown script option: {script}-{key}")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            print(f"{script}-{key} is {color}, not #rrggbb")
    elif not re.fullmatch(r"#([0-9a-fA-F]{2})?[0-9a-fA-F]{6}", value):
        print(f"{option} is {value}, not #rrggbb or #aarrggbb")
' "$(mpv_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its mpv folder is deleted, and the template is kept
test_remove_deletes_the_mpv_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/mpv-theme/sunset/jenerated-sunset.conf"
  assert_missing "$SANDBOX/repo/app-themes/mpv-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/mpv-theme/colors.conf.tmpl"
}

# --- Tests: installing -------------------------------------------------------

MPV_LINE='include="~~/jenerated-colors.conf"'

# GIVEN a system where mpv has no settings file yet
# WHEN choosing mpv and Blue Purple
# THEN the colors are linked into ~/.config/mpv, and mpv.conf is created to
#      include them
test_mpv_creates_mpv_conf() {
  fake_os Linux
  install_app mpv blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/.config/mpv/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/mpv-theme/blue-purple/jenerated-blue-purple.conf"
  assert_file_contains "$SANDBOX/home/.config/mpv/mpv.conf" "$MPV_LINE"
  assert_contains "Restart mpv"
}

# GIVEN an mpv.conf of the user's own, whose last line has no line break
# WHEN choosing mpv and answering yes to loading the colors
# THEN the include goes at the end, on a line of its own, after the user's
#      settings
test_mpv_adds_the_colors_to_an_existing_mpv_conf() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/mpv"
  printf 'volume=70' >"$SANDBOX/home/.config/mpv/mpv.conf"
  install_app mpv blue-purple "y\n"
  assert_status 0
  expected="$(printf 'volume=70\n# Colors from Jenerated Themes\n%s' "$MPV_LINE")"
  assert_file_equals "$SANDBOX/home/.config/mpv/mpv.conf" "$expected"
}

# GIVEN an mpv.conf of the user's own
# WHEN choosing mpv and answering no to loading the colors
# THEN mpv.conf is left alone, and it shows the line to add by hand
test_mpv_leaves_mpv_conf_when_declined() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/mpv"
  printf 'volume=70\n' >"$SANDBOX/home/.config/mpv/mpv.conf"
  install_app mpv blue-purple "n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.config/mpv/mpv.conf" "volume=70"
  assert_contains "    $MPV_LINE"
}

# GIVEN mpv set up with Blue Purple
# WHEN choosing mpv and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset's colors, and mpv.conf isn't changed again
test_mpv_switching_palettes_repoints_the_link() {
  fake_os Linux
  install_app mpv blue-purple
  cp "$SANDBOX/home/.config/mpv/mpv.conf" "$SANDBOX/mpv-before.conf"
  install_app mpv sunset "y\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/mpv/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/mpv-theme/sunset/jenerated-sunset.conf"
  assert_same_file "$SANDBOX/home/.config/mpv/mpv.conf" "$SANDBOX/mpv-before.conf"
}

# GIVEN mpv installed through Flatpak, and on a Mac too
# WHEN choosing mpv
# THEN the Flatpak's settings folder gets the colors as well; and on a Mac
#      they go in ~/.config/mpv, where mpv looks there too
test_mpv_themes_the_flatpak_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/io.mpv.Mpv"
  install_app mpv blue-purple
  assert_status 0
  assert_file_contains "$SANDBOX/home/.var/app/io.mpv.Mpv/config/mpv/mpv.conf" "$MPV_LINE"
  assert_exists "$SANDBOX/home/.var/app/io.mpv.Mpv/config/mpv/jenerated-colors.conf"
  rm -rf "$SANDBOX/home/.config" "$SANDBOX/home/.var"
  fake_os Darwin
  install_app mpv blue-purple
  assert_status 0
  assert_file_contains "$SANDBOX/home/.config/mpv/mpv.conf" "$MPV_LINE"
}

run_tests
