#!/usr/bin/env bash
# Tests for Spyder: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-spyder.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
spyder_theme() { printf '%s' "$SANDBOX/repo/app-themes/spyder-theme/jenerated-$1.ini"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Spyder theme as Spyder reads its
#      settings
# THEN it has a name and every color a Spyder syntax theme has: the editor's
#      as #rrggbb, and the code colors as (#rrggbb, bold, italic), with the
#      palette's colors (as in the VS Code theme)
test_spyder_theme_has_every_color() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import ast, configparser, re, sys
p = configparser.ConfigParser(interpolation=None, comment_prefixes=(";",))
p.optionxform = str
p.read(sys.argv[1])
t = p["appearance"]
plain = "background currentline currentcell occurrence ctrlclick sideareas matched_p unmatched_p".split()
code = "normal keyword builtin definition comment string number instance magic".split()
name = t.get("name")
if name != "Jenerated Sunset":
    print(f"name is {name}")
for key in plain:
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", t.get(key, "")):
        print(f"{key} is {t.get(key)!r}")
for key in code:
    try:
        color, bold, italic = ast.literal_eval(t.get(key, ""))
        ok = re.fullmatch(r"#[0-9a-fA-F]{6}", color) and isinstance(bold, bool) and isinstance(italic, bool)
    except (ValueError, SyntaxError, TypeError):
        ok = False
    if not ok:
        print(f"{key} is {t.get(key)!r}")
extra = set(t) - set(plain) - set(code) - {"name"}
if extra:
    print(f"unknown keys {sorted(extra)}")
' "$(spyder_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
  theme="$(spyder_theme sunset)"
  assert_file_contains "$theme" "background = $(color bg)"
  assert_file_contains "$theme" "keyword = ('$(color accent_soft)', False, False)"
  assert_file_contains "$theme" "string = ('$(color green)', False, False)"
  assert_file_contains "$theme" "comment = ('$(color text_muted)', False, True)"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Spyder theme is deleted, and the template is kept
test_remove_deletes_the_spyder_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/spyder-theme/jenerated-sunset.ini"
  assert_missing "$(spyder_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/spyder-theme/scheme.ini.tmpl"
}

# --- Tests: installing -------------------------------------------------------

SPYDER_INI=".config/spyder-py3/config/spyder.ini"

# spyder_ini path -> writes a small spyder.ini with a custom theme of the
# user's own (custom-0) and an editor setting.
spyder_ini() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '[main]' 'version = 87.2.0' '' '[appearance]' 'selected = spyder/dark' \
    "custom_names = ['custom-0']" 'custom-0/name = My Theme' 'custom-0/background = #000000' \
    '' '[editor]' 'wrap = True' >"$1"
}

# spyder_value ini option -> prints an [appearance] option from spyder.ini.
spyder_value() {
  "$(find_python)" -c '
import configparser, sys
p = configparser.ConfigParser(interpolation=None)
p.optionxform = str
p.read(sys.argv[1])
print(p["appearance"].get(sys.argv[2], ""))
' "$1" "$2"
}

# GIVEN Spyder's settings with a custom theme of the user's own, and Spyder
#       closed
# WHEN choosing Spyder and Blue Purple, and answering yes to making it the
#      current theme
# THEN spyder.ini is backed up, Blue Purple becomes the next custom theme
#      (custom-1, keeping the user's custom-0) and is selected, and the rest
#      of the file is kept
test_spyder_adds_and_selects_the_theme() {
  fake_os Linux
  fake_command pgrep "exit 1"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  cp "$ini" "$SANDBOX/original.ini"
  install_app spyder blue-purple "y\n"
  assert_status 0
  assert_same_file "$ini.before-jenerated" "$SANDBOX/original.ini"
  [ "$(spyder_value "$ini" custom_names)" = "['custom-0', 'custom-1']" ] || fail "expected custom-0 and custom-1"
  [ "$(spyder_value "$ini" custom-1/name)" = "Jenerated Blue Purple" ] || fail "expected custom-1 to be Blue Purple"
  [ "$(spyder_value "$ini" custom-0/name)" = "My Theme" ] || fail "expected the user's theme to be kept"
  [ "$(spyder_value "$ini" selected)" = "custom-1" ] || fail "expected Blue Purple to be selected"
  assert_file_contains "$ini" "custom-1/normal = ('#DBDEE1', False, False)"
  assert_file_contains "$ini" "wrap = True"
}

# GIVEN Blue Purple added to Spyder before
# WHEN choosing Spyder and Blue Purple again, and answering no to selecting it
# THEN it updates the same custom theme instead of adding another, and the
#      current theme is left alone
test_spyder_updates_its_own_theme() {
  fake_os Linux
  fake_command pgrep "exit 1"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  install_app spyder blue-purple "n\n"
  install_app spyder blue-purple "n\n"
  assert_status 0
  [ "$(spyder_value "$ini" custom_names)" = "['custom-0', 'custom-1']" ] || fail "expected no third custom theme"
  [ "$(spyder_value "$ini" selected)" = "spyder/dark" ] || fail "expected the current theme to be left alone"
  assert_contains "Syntax"
}

# GIVEN Spyder's settings, and Spyder running
# WHEN choosing Spyder
# THEN its settings are left alone, and it says to close Spyder first
test_spyder_waits_while_spyder_is_open() {
  fake_os Linux
  fake_command pgrep "exit 0"
  ini="$SANDBOX/home/$SPYDER_INI"
  spyder_ini "$ini"
  cp "$ini" "$SANDBOX/original.ini"
  install_app spyder blue-purple
  assert_status 0
  assert_contains "Spyder is open"
  assert_same_file "$ini" "$SANDBOX/original.ini"
}

# GIVEN Spyder has never been opened (no spyder.ini)
# WHEN choosing Spyder
# THEN it says to open Spyder once first, and creates nothing
test_spyder_explains_before_first_run() {
  fake_os Linux
  fake_command pgrep "exit 1"
  install_app spyder blue-purple
  assert_status 0
  assert_contains "Spyder hasn't been opened yet"
  assert_missing "$SANDBOX/home/.config/spyder-py3"
}

# GIVEN a Mac with Spyder's settings, and SPYDER_CONFDIR pointing elsewhere
#       on Linux
# WHEN choosing Spyder
# THEN the Mac's ~/.spyder-py3 and the SPYDER_CONFDIR folder get the theme
test_spyder_on_macos_and_with_spyder_confdir() {
  fake_command pgrep "exit 1"
  fake_os Darwin
  spyder_ini "$SANDBOX/home/.spyder-py3/config/spyder.ini"
  install_app spyder blue-purple "n\n"
  assert_status 0
  [ "$(spyder_value "$SANDBOX/home/.spyder-py3/config/spyder.ini" custom-1/name)" = "Jenerated Blue Purple" ] ||
    fail "expected the theme in ~/.spyder-py3"
  fake_os Linux
  spyder_ini "$SANDBOX/home/spyder-conf/config/spyder.ini"
  TEST_SPYDER_CONFDIR="$SANDBOX/home/spyder-conf" install_app spyder blue-purple "n\n"
  assert_status 0
  [ "$(spyder_value "$SANDBOX/home/spyder-conf/config/spyder.ini" custom-1/name)" = "Jenerated Blue Purple" ] ||
    fail "expected the theme in the SPYDER_CONFDIR folder"
}

run_tests
