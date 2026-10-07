#!/usr/bin/env bash
# Tests for Qt Creator: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-qtcreator.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
qtcreator_scheme() { printf '%s' "$SANDBOX/repo/app-themes/qtcreator-theme/jenerated-$1.xml"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Qt Creator color scheme as XML
# THEN it's named after the palette, and colors the editor, keywords,
#      strings and functions from the palette (as in the VS Code theme)
test_qtcreator_scheme_uses_the_palette() {
  generate sunset
  result="$("$PYTHON" -c '
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
s = {e.get("name"): e for e in root}
print(root.get("name"), s["Text"].get("foreground"), s["Text"].get("background"),
      s["Keyword"].get("foreground"), s["String"].get("foreground"), s["Function"].get("foreground"))
' "$(qtcreator_scheme sunset)")"
  expected="Jenerated Sunset $(color text) $(color bg) $(color accent_soft) $(color green) $(color accent_light)"
  [ "$result" = "$expected" ] || fail "expected '$expected', got '$result'"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its color scheme the way Qt Creator does
# THEN every style is one Qt Creator 20 names, each style appears once, and
#      it only uses attributes Qt Creator reads: #rrggbb colors, bold and
#      italic, and the underline styles it knows
test_qtcreator_scheme_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys, xml.etree.ElementTree as ET
known = set(["Text", "Link", "Selection", "LineNumber", "SearchResult", "SearchResultAlt1", "SearchResultAlt2", "SearchResultContainingFunction", "SearchScope", "Parentheses", "ParenthesesMismatch", "AutoComplete", "CurrentLine", "CurrentLineNumber", "Occurrences", "Occurrences.Unused", "Occurrences.Rename", "Number", "String", "Type", "Concept", "Namespace", "Local", "Parameter", "Global", "Field", "Static", "VirtualMethod", "Function", "Keyword", "PrimitiveType", "Operator", "Overloaded Operator", "Punctuation", "Preprocessor", "Macro", "Label", "Attribute", "Comment", "Doxygen.Comment", "Doxygen.Tag", "VisualWhitespace", "QmlLocalId", "QmlExternalId", "QmlTypeId", "QmlRootObjectProperty", "QmlScopeObjectProperty", "QmlExternalObjectProperty", "JsScopeVar", "JsImportVar", "JsGlobalVar", "QmlStateName", "Binding", "DisabledCode", "AddedLine", "RemovedLine", "DiffFile", "DiffLocation", "DiffFileLine", "DiffContextLine", "DiffSourceLine", "DiffSourceChar", "DiffDestLine", "DiffDestChar", "LogChangeLine", "LogAuthorName", "LogCommitDate", "LogCommitHash", "LogCommitSubject", "LogDecoration", "Error", "ErrorContext", "Warning", "WarningContext", "Info", "InfoContext", "Declaration", "FunctionDefinition", "OutputArgument", "StaticMember", "CocoCodeAdded", "CocoPartiallyCovered", "CocoNotCovered", "CocoFullyCovered", "CocoManuallyValidated", "CocoDeadCode", "CocoExecutionCountTooLow", "CocoNotCoveredInfo", "CocoCoveredInfo", "CocoManuallyValidatedInfo"])
underlines = {"NoUnderline", "SingleUnderline", "DashUnderline", "DotLine", "DashDotLine", "DashDotDotLine", "WaveUnderline"}
root = ET.parse(sys.argv[1]).getroot()
if root.tag != "style-scheme" or root.get("version") != "1.0":
    print("not a version 1.0 style-scheme")
seen = set()
for style in root:
    name = style.get("name")
    if name not in known:
        print(f"{name} is not a Qt Creator style")
    if name in seen:
        print(f"{name} appears twice")
    seen.add(name)
    for attr, value in style.attrib.items():
        if attr in ("foreground", "background", "underlineColor"):
            if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
                print(f"{name} {attr} is {value}")
        elif attr in ("bold", "italic"):
            if value != "true":
                print(f"{name} {attr} is {value}")
        elif attr == "underlineStyle":
            if value not in underlines:
                print(f"{name} has underline style {value}")
        elif attr != "name":
            print(f"{name} has attribute {attr}")
' "$(qtcreator_scheme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Qt Creator color scheme is deleted, and the template is kept
test_remove_deletes_the_qtcreator_scheme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/qtcreator-theme/jenerated-sunset.xml"
  assert_missing "$(qtcreator_scheme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/qtcreator-theme/color-scheme.xml.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Qt Creator installed the usual way and through Flatpak
# WHEN choosing Qt Creator and Blue Purple
# THEN the color scheme is linked into both styles folders, and it explains
#      where to choose it, and to pick Qt Creator's own dark theme to match
test_qtcreator_links_the_color_scheme() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/io.qt.QtCreator"
  install_app qtcreator blue-purple "y\n1\n"
  assert_status 0
  for dir in "$SANDBOX/home/.config/QtProject/qtcreator/styles" \
    "$SANDBOX/home/.var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles"; do
    assert_link "$dir/jenerated-blue-purple.xml" "$SANDBOX/repo/app-themes/qtcreator-theme/jenerated-blue-purple.xml"
  done
  assert_contains "Text Editor -> Font & Colors"
  assert_contains 'Choose "Jenerated Blue Purple" as the Color Scheme.'
  assert_contains "Dark or Light theme"
}

# GIVEN a Mac
# WHEN choosing Qt Creator
# THEN the color scheme goes in ~/.config/QtProject, where Qt Creator keeps
#      its settings on a Mac too
test_qtcreator_on_macos_uses_dot_config() {
  fake_os Darwin
  install_app qtcreator blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/QtProject/qtcreator/styles/jenerated-blue-purple.xml" \
    "$SANDBOX/repo/app-themes/qtcreator-theme/jenerated-blue-purple.xml"
}

run_tests
