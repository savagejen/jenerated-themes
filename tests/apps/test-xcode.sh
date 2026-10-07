#!/usr/bin/env bash
# Tests for Xcode: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-xcode.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
xcode_theme() { printf '%s' "$SANDBOX/repo/app-themes/xcode-theme/jenerated-$1.xccolortheme"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Xcode theme as a property list
# THEN it's a valid plist with the editor's background, caret and selection,
#      and strings, keywords and functions in the palette's colors (as in the
#      VS Code theme), each as red, green, blue and alpha from 0 to 1
test_xcode_theme_uses_the_palette() {
  generate sunset
  result="$("$PYTHON" -c '
import plistlib, sys
t = plistlib.load(open(sys.argv[1], "rb"))
s = t["DVTSourceTextSyntaxColors"]
print(t["DVTSourceTextBackground"], t["DVTSourceTextInsertionPointColor"], t["DVTSourceTextSelectionColor"],
      s["xcode.syntax.string"], s["xcode.syntax.keyword"], s["xcode.syntax.identifier.function"], sep="|")
' "$(xcode_theme sunset)")"
  f() { color_rgb "$1" | awk -F', ' '{printf "%.4f %.4f %.4f 1", $1/255, $2/255, $3/255}'; }
  expected="$(f bg)|$(f accent)|$(f selection)|$(f green)|$(f accent_soft)|$(f accent_light)"
  [ "$result" = "$expected" ] || fail "expected '$expected', got '$result'"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Xcode theme
# THEN it has every code color Xcode themes have, a font for each one but the
#      regex ones (as Xcode's own themes do), and every color is four numbers
#      from 0 to 1
test_xcode_theme_has_every_code_color() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import plistlib, re, sys
syntax = """attribute character comment comment.doc comment.doc.keyword declaration.other declaration.type
identifier.class identifier.class.system identifier.constant identifier.constant.system identifier.function
identifier.function.system identifier.macro identifier.macro.system identifier.type identifier.type.system
identifier.variable identifier.variable.system keyword mark markup.code number plain preprocessor regex
regex.capturename regex.charname regex.number regex.other string url""".split()
t = plistlib.load(open(sys.argv[1], "rb"))
colors, fonts = t["DVTSourceTextSyntaxColors"], t["DVTSourceTextSyntaxFonts"]
for key in syntax:
    if f"xcode.syntax.{key}" not in colors:
        print(f"missing color xcode.syntax.{key}")
    if not key.startswith("regex") and f"xcode.syntax.{key}" not in fonts:
        print(f"missing font xcode.syntax.{key}")
number = r"(0|1)(\.\d+)?"
for key, value in list(colors.items()) + [(k, v) for k, v in t.items() if k.endswith("Color") or k == "DVTSourceTextBackground"]:
    if not re.fullmatch(rf"{number} {number} {number} 1", value):
        print(f"{key} is {value!r}")
if t.get("DVTFontAndColorVersion") != 1:
    print("DVTFontAndColorVersion is not 1")
' "$(xcode_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Xcode theme is deleted, and the template is kept
test_remove_deletes_the_xcode_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/xcode-theme/jenerated-sunset.xccolortheme"
  assert_missing "$(xcode_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/xcode-theme/theme.xccolortheme.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a Mac
# WHEN choosing Xcode and Blue Purple
# THEN the theme is linked into Xcode's themes folder under the palette's
#      name (which Xcode lists it by), and it explains how to choose it
test_xcode_links_the_theme_on_macos() {
  fake_os Darwin
  install_app xcode blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Developer/Xcode/UserData/FontAndColorThemes/Jenerated Blue Purple.xccolortheme" \
    "$SANDBOX/repo/app-themes/xcode-theme/jenerated-blue-purple.xccolortheme"
  assert_contains 'Themes, and'
  assert_contains 'choose "Jenerated Blue Purple".'
}

# GIVEN a Linux system
# WHEN searching the app menu for Xcode
# THEN it isn't offered, since Xcode only runs on a Mac
test_xcode_is_only_offered_on_macos() {
  fake_os Linux
  run_setup "1\nxcode\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'No app matches "xcode".'
}

run_tests
