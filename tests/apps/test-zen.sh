#!/usr/bin/env bash
# Tests for Zen Browser: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-zen.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
zen_theme() { printf '%s' "$SANDBOX/repo/app-themes/zen-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette, and a light palette
# WHEN generating them
# THEN Sunset's Zen stylesheet sets the window background (including on the
#      elements Zen's workspace themes color), Zen's accent, the text and
#      the selected tab from the palette, and marks it dark; the light
#      palette's is marked light; and its about: page stylesheet uses the
#      editor background
test_zen_theme_uses_the_palette() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  css="$(zen_theme sunset)/userChrome.css"
  assert_file_contains "$css" "#zen-browser-background,"
  assert_file_contains "$css" "--zen-main-browser-background: $(color bg_chrome) !important;"
  assert_file_contains "$css" "--zen-primary-color: $(color accent) !important;"
  assert_file_contains "$css" "--toolbox-textcolor: $(color text) !important;"
  assert_file_contains "$css" "--tab-selected-textcolor: $(color text_strong) !important;"
  assert_file_contains "$css" "color-scheme: dark !important;"
  assert_file_contains "$(zen_theme daylight)/userChrome.css" "color-scheme: light !important;"
  assert_file_contains "$(zen_theme sunset)/userContent.css" "--in-content-page-background: $(color bg) !important;"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Zen stylesheets without comments
# THEN every declaration is marked !important (Zen's own values would win
#      otherwise), and the braces balance
test_zen_theme_overrides_every_value() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
for path in sys.argv[1:]:
    css = re.sub(r"/\*.*?\*/", "", open(path).read(), flags=re.S)
    if css.count("{") != css.count("}"):
        print(f"{path}: the braces do not balance")
    for declaration in re.findall(r"[{;]\s*([a-z-]+\s*:[^;{}]*);", css):
        if not declaration.rstrip().endswith("!important"):
            print(f"{path}: {declaration.strip()} is not !important")
' "$(zen_theme sunset)/userChrome.css" "$(zen_theme sunset)/userContent.css")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Zen theme folder is deleted, and the templates are kept
test_remove_deletes_the_zen_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/zen-theme/sunset/userChrome.css"
  assert_missing "$(zen_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/zen-theme/userChrome.css.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# zen_profile root name path... -> writes root/profiles.ini listing a profile
# for each "name path" pair (paths relative to root), and creates their
# folders.
zen_profile() {
  local root="$1" n=0
  shift
  mkdir -p "$root"
  : >"$root/profiles.ini"
  while [ $# -gt 1 ]; do
    printf '[Profile%d]\nName=%s\nIsRelative=1\nPath=%s\n\n' "$n" "$1" "$2" >>"$root/profiles.ini"
    mkdir -p "$root/$2"
    n=$((n + 1))
    shift 2
  done
  printf '[General]\nStartWithLastProfile=1\n' >>"$root/profiles.ini"
}

ZEN_ROOT=".zen"

# GIVEN a Linux system with one Zen profile and no custom stylesheets
# WHEN choosing Zen Browser and Blue Purple
# THEN the theme's stylesheets are linked into the profile's chrome folder,
#      userChrome.css and userContent.css are created to import them, custom
#      stylesheets are turned on in user.js, and it says to restart Zen
test_zen_installs_the_theme_into_the_profile() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default (release)" "abc.Default (release)"
  install_app zen blue-purple
  assert_status 0
  profile="$SANDBOX/home/$ZEN_ROOT/abc.Default (release)"
  folder="$SANDBOX/repo/app-themes/zen-theme/blue-purple"
  assert_link "$profile/chrome/jenerated-userChrome.css" "$folder/userChrome.css"
  assert_link "$profile/chrome/jenerated-userContent.css" "$folder/userContent.css"
  assert_file_contains "$profile/chrome/userChrome.css" '@import "jenerated-userChrome.css";'
  assert_file_contains "$profile/chrome/userContent.css" '@import "jenerated-userContent.css";'
  assert_file_contains "$profile/user.js" 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
  assert_contains "Restart Zen"
}

# GIVEN a Zen profile with a userChrome.css of the user's own, and a user.js
#       whose last line has no line break
# WHEN choosing Zen Browser and answering yes to adding the theme
# THEN the import is added as the first line, the user's styles are kept
#      after it, and the setting goes on its own line in user.js
test_zen_adds_the_theme_to_an_existing_stylesheet() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  mkdir -p "$profile/chrome"
  printf '#nav-bar { opacity: 0.9; }\n' >"$profile/chrome/userChrome.css"
  printf 'user_pref("browser.startup.page", 3);' >"$profile/user.js"
  install_app zen blue-purple "y\n"
  assert_status 0
  expected="$(printf '@import "jenerated-userChrome.css";\n#nav-bar { opacity: 0.9; }')"
  assert_file_equals "$profile/chrome/userChrome.css" "$expected"
  expected="$(printf 'user_pref("browser.startup.page", 3);\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);')"
  assert_file_equals "$profile/user.js" "$expected"
}

# GIVEN a Zen profile with a userChrome.css of the user's own
# WHEN choosing Zen Browser and answering no to adding the theme
# THEN the stylesheet is left alone, and it shows the line to add by hand
test_zen_leaves_an_existing_stylesheet_when_declined() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  mkdir -p "$profile/chrome"
  printf '#nav-bar { opacity: 0.9; }\n' >"$profile/chrome/userChrome.css"
  install_app zen blue-purple "n\n"
  assert_status 0
  assert_file_equals "$profile/chrome/userChrome.css" "#nav-bar { opacity: 0.9; }"
  assert_contains '    @import "jenerated-userChrome.css";'
}

# GIVEN Zen with Blue Purple installed by jenerate
# WHEN choosing Zen Browser and Sunset, and answering yes to replacing the
#      old links
# THEN the links point to Sunset, and neither the imports nor the setting
#      are added twice
test_zen_switching_palettes_adds_nothing_twice() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Default" "abc.default"
  profile="$SANDBOX/home/$ZEN_ROOT/abc.default"
  install_app zen blue-purple
  install_app zen sunset "y\ny\n"
  assert_status 0
  assert_link "$profile/chrome/jenerated-userChrome.css" "$SANDBOX/repo/app-themes/zen-theme/sunset/userChrome.css"
  [ "$(grep -c jenerated-userChrome.css "$profile/chrome/userChrome.css")" = 1 ] || fail "expected one import in userChrome.css"
  [ "$(grep -c legacyUserProfileCustomizations "$profile/user.js")" = 1 ] || fail "expected the setting once in user.js"
}

# GIVEN two Zen profiles
# WHEN choosing Zen Browser and then the second profile
# THEN it lists both by name, and installs into the second one only
test_zen_asks_which_profile() {
  fake_os Linux
  zen_profile "$SANDBOX/home/$ZEN_ROOT" "Work" "aaa.work" "Personal" "bbb.personal"
  install_app zen blue-purple "2\n"
  assert_status 0
  assert_contains "Which Zen profile?"
  assert_contains "1) Work ($SANDBOX/home/$ZEN_ROOT/aaa.work)"
  assert_contains "2) Personal ($SANDBOX/home/$ZEN_ROOT/bbb.personal)"
  assert_exists "$SANDBOX/home/$ZEN_ROOT/bbb.personal/chrome/jenerated-userChrome.css"
  assert_missing "$SANDBOX/home/$ZEN_ROOT/aaa.work/chrome"
}

# GIVEN Zen profiles in the XDG config folder and in the folder Flatpak
#       gives Zen (and none in ~/.zen)
# WHEN choosing Zen Browser
# THEN both are offered
test_zen_finds_xdg_and_flatpak_profiles() {
  fake_os Linux
  zen_profile "$SANDBOX/home/.config/zen" "Native" "n.default"
  zen_profile "$SANDBOX/home/.var/app/app.zen_browser.zen/.zen" "Flatpak" "f.default"
  install_app zen blue-purple "2\n"
  assert_status 0
  assert_contains "Native ($SANDBOX/home/.config/zen/n.default)"
  assert_contains "Flatpak ($SANDBOX/home/.var/app/app.zen_browser.zen/.zen/f.default)"
  assert_exists "$SANDBOX/home/.var/app/app.zen_browser.zen/.zen/f.default/chrome/jenerated-userChrome.css"
}

# GIVEN a Mac with a Zen profile in Application Support
# WHEN choosing Zen Browser (also 10 on a Mac)
# THEN the theme is installed into that profile
test_zen_on_macos_uses_application_support() {
  fake_os Darwin
  zen_profile "$SANDBOX/home/Library/Application Support/zen" "Default" "Profiles/abc.default"
  install_app zen blue-purple
  assert_status 0
  assert_exists "$SANDBOX/home/Library/Application Support/zen/Profiles/abc.default/chrome/jenerated-userChrome.css"
}

# GIVEN Zen has never been opened (no profiles)
# WHEN choosing Zen Browser
# THEN it says to open Zen once first, and installs nothing
test_zen_explains_when_there_is_no_profile() {
  fake_os Linux
  install_app zen blue-purple
  assert_status 0
  assert_contains "Zen hasn't been opened yet"
  assert_missing "$SANDBOX/home/$ZEN_ROOT"
}

run_tests
