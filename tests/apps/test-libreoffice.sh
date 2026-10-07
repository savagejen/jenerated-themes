#!/usr/bin/env bash
# Tests for LibreOffice (Writer, Calc, Impress and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-libreoffice.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
libreoffice_theme() { printf '%s' "$SANDBOX/repo/app-themes/libreoffice-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# libreoffice_colors folder -> prints the theme's scheme name, then each entry
# as "Name #rrggbb [visible]", one per line.
libreoffice_colors() {
  "$PYTHON" -c '
import sys, xml.etree.ElementTree as ET
OOR = "{http://openoffice.org/2001/registry}"
scheme = ET.parse(sys.argv[1] + "/theme.xcu").getroot().find("node/node/node")
print(scheme.get(OOR + "name"))
for entry in scheme:
    props = {p.get(OOR + "name"): p.findtext("value") for p in entry}
    print(entry.get(OOR + "name"), "#%06x" % int(props["Color"]), props.get("IsVisible", "")) 
' "$1" | sed 's/ *$//'
}

# GIVEN the Sunset palette
# WHEN generating it and reading its LibreOffice theme's colors
# THEN the scheme is named after the palette, and the page, text, window,
#      selections, menus and spelling marks come from the palette
test_libreoffice_theme_uses_the_palette() {
  generate sunset
  colors="$(libreoffice_colors "$(libreoffice_theme sunset)")"
  [ "$(printf '%s\n' "$colors" | head -1)" = "Jenerated Sunset" ] ||
    fail "expected the scheme 'Jenerated Sunset', got '$(printf '%s\n' "$colors" | head -1)'"
  for pair in "DocColor bg" "FontColor text" "AppBackground bg_chrome" "WindowColor bg_sidebar" \
    "WindowTextColor text" "AccentColor bg_selected" "MenuColor bg_widget" "Spell red" \
    "CalcValue orange"; do
    set -- $pair
    expected="$1 $(color "$2" | tr 'A-F' 'a-f')"
    printf '%s\n' "$colors" | grep -qx "$expected" ||
      fail "expected '$expected', got '$(printf '%s\n' "$colors" | grep "^$1 ")'"
  done
}

# GIVEN the Sunset palette
# WHEN generating it and reading its LibreOffice extension the way
#      LibreOffice does
# THEN the settings file adds one scheme under Office.UI's ColorSchemes, with
#      each of LibreOffice's color entries once, each a color from 0 to
#      0xffffff, and IsVisible exactly where LibreOffice has one; the
#      manifest lists that settings file as configuration data, and the
#      description gives the extension an id and a name
test_libreoffice_theme_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import sys, xml.etree.ElementTree as ET
folder = sys.argv[1]
names = sys.argv[2].split()
visible = {"Links", "LinksVisited", "Shadow", "WriterFieldShadings", "WriterIdxShadings", "WriterDirectCursor", "CalcHiddenColRow", "CalcTextOverflow", "DrawGrid"}
OOR = "{http://openoffice.org/2001/registry}"
root = ET.parse(folder + "/theme.xcu").getroot()
if (root.tag, root.get(OOR + "name"), root.get(OOR + "package")) != (OOR + "component-data", "UI", "org.openoffice.Office"):
    print("not Office.UI configuration data")
path = [root.find("node"), root.find("node/node")]
if [n.get(OOR + "name") if n is not None else None for n in path] != ["ColorScheme", "ColorSchemes"]:
    print("the scheme is not under ColorScheme/ColorSchemes")
schemes = root.findall("node/node/node")
if len(schemes) != 1 or schemes[0].get(OOR + "op") != "replace":
    print("expected one scheme, added with oor:op=replace")
seen = []
for entry in schemes[0]:
    name = entry.get(OOR + "name")
    seen.append(name)
    props = {p.get(OOR + "name"): p.findtext("value") for p in entry}
    if name not in names:
        print(f"{name} is not a LibreOffice color entry")
    if not props.get("Color", "").isdigit() or int(props["Color"]) > 0xFFFFFF:
        print(f"{name} Color is {props.get('Color')}")
    if ("IsVisible" in props) != (name in visible):
        print(f"{name} has the wrong IsVisible")
    if "IsVisible" in props and props["IsVisible"] not in ("true", "false"):
        print(f"{name} IsVisible is {props['IsVisible']}")
    if set(props) - {"Color", "IsVisible"}:
        print(f"{name} has other properties")
for name in names:
    if seen.count(name) != 1:
        print(f"{name} appears {seen.count(name)} times")
M = "{http://openoffice.org/2001/manifest}"
entries = ET.parse(folder + "/META-INF/manifest.xml").getroot().findall(M + "file-entry")
if [(e.get(M + "full-path"), e.get(M + "media-type")) for e in entries] != [("theme.xcu", "application/vnd.sun.star.configuration-data")]:
    print("the manifest does not list theme.xcu as configuration data")
D = "{http://openoffice.org/extensions/description/2006}"
desc = ET.parse(folder + "/description.xml").getroot()
if desc.find(D + "identifier").get("value") != "com.jenerated.libreoffice.sunset":
    print("unexpected identifier")
if desc.findtext(D + "display-name/" + D + "name") != "Jenerated Sunset":
    print("unexpected display name")
' "$(libreoffice_theme sunset)" "DocColor DocBoundaries AppBackground TableBoundaries FontColor Links LinksVisited Spell Grammar SmartTags Shadow WriterTextGrid WriterBaselineGrid WriterFieldShadings WriterIdxShadings WriterDirectCursor WriterSectionBoundaries WriterHeaderFooterMark WriterPageBreaks WriterNonPrintChars HTMLSGML HTMLComment HTMLKeyword HTMLUnknown CalcGrid CalcCellFocus CalcDBFocus CalcPageBreak CalcPageBreakManual CalcPageBreakAutomatic CalcHiddenColRow CalcTextOverflow CalcComments CalcDetective CalcDetectiveError CalcReference CalcNotesBackground CalcValue CalcFormula CalcText CalcProtectedBackground DrawGrid BASICEditor BASICIdentifier BASICComment BASICNumber BASICString BASICOperator BASICKeyword BASICError SQLIdentifier SQLNumber SQLString SQLOperator SQLKeyword SQLParameter SQLComment WindowColor WindowTextColor BaseColor ButtonColor ButtonTextColor AccentColor DisabledColor DisabledTextColor ShadowColor SeparatorColor FaceColor ActiveColor ActiveTextColor ActiveBorderColor FieldColor MenuBarColor MenuBarTextColor MenuBarHighlightColor MenuBarHighlightTextColor MenuColor MenuTextColor MenuHighlightColor MenuHighlightTextColor MenuBorderColor InactiveColor InactiveTextColor InactiveBorderColor")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its LibreOffice extension folder is deleted, and the templates are kept
test_remove_deletes_the_libreoffice_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/libreoffice-theme/sunset/theme.xcu"
  assert_missing "$(libreoffice_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/libreoffice-theme/theme.xcu.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN LibreOffice's unopkg, and LibreOffice closed
# WHEN choosing LibreOffice and Blue Purple
# THEN it packages the theme as an .oxt holding the extension's files,
#      installs it with "unopkg add --force", and explains where to turn it on
test_libreoffice_installs_the_extension() {
  fake_os Linux
  fake_command pgrep "exit 1"
  fake_command unopkg "printf '%s\\n' \"\$@\" >\"$SANDBOX/unopkg-args\""
  install_app libreoffice blue-purple
  assert_status 0
  oxt="$SANDBOX/repo/app-themes/libreoffice-theme/jenerated-blue-purple.oxt"
  result="$("$(find_python)" -c '
import sys, zipfile
print(sorted(zipfile.ZipFile(sys.argv[1]).namelist()))
' "$oxt")"
  [ "$result" = "['META-INF/manifest.xml', 'description.txt', 'description.xml', 'theme.xcu']" ] ||
    fail "unexpected .oxt contents: $result"
  assert_file_equals "$SANDBOX/unopkg-args" "add
--force
$oxt"
  assert_contains "Installed."
  assert_contains "LibreOffice -> Appearance"
  assert_contains 'Tick "Enable application theming", choose "Jenerated Blue Purple" as the'
}

# GIVEN LibreOffice's unopkg, and LibreOffice open
# WHEN choosing LibreOffice
# THEN it doesn't run unopkg (which needs LibreOffice closed), and explains
#      adding the .oxt in Tools -> Extensions instead
test_libreoffice_open_adds_the_extension_by_hand() {
  fake_os Linux
  fake_command pgrep "exit 0"
  fake_command unopkg "touch \"$SANDBOX/unopkg-ran\""
  install_app libreoffice blue-purple
  assert_status 0
  assert_missing "$SANDBOX/unopkg-ran"
  assert_contains "Tools -> Extensions, click Add"
  assert_contains "app-themes/libreoffice-theme/jenerated-blue-purple.oxt"
}

run_tests
