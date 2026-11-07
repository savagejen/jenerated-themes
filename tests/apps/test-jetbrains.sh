#!/usr/bin/env bash
# Tests for JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-jetbrains.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
jetbrains_theme() { printf '%s' "$SANDBOX/repo/app-themes/jetbrains-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the plugin descriptor and editor scheme are valid XML and the UI theme
#      valid JSON, the theme builds on the New UI dark theme and names its
#      editor scheme, and all three use the palette's name and colors
test_jetbrains_theme_uses_the_palette() {
  generate sunset
  folder="$(jetbrains_theme sunset)"
  result="$("$PYTHON" -c '
import json, sys, xml.etree.ElementTree as ET
folder = sys.argv[1]
plugin = ET.parse(folder + "/META-INF/plugin.xml").getroot()
theme = json.load(open(folder + "/jenerated-sunset.theme.json"))
scheme = ET.parse(folder + "/jenerated-sunset.xml").getroot()
def attr(name, part):
    return scheme.find(f"attributes/option[@name=\"{name}\"]/value/option[@name=\"{part}\"]").get("value")
caret = scheme.find("colors/option[@name=\"CARET_COLOR\"]").get("value")
print(plugin.findtext("name"), plugin.findtext("id"), plugin.find("extensions/themeProvider").get("path"))
print(theme["name"], theme["parentTheme"], theme["editorScheme"], scheme.get("name"), scheme.get("parent_scheme"))
c = theme["colors"]
print(c["Gray1"], c["Gray2"], c["Blue6"], c["Green1"], c["Red7"])
print(caret, attr("TEXT", "BACKGROUND"), attr("DEFAULT_STRING", "FOREGROUND"), attr("CONSOLE_RED_OUTPUT", "FOREGROUND"))
' "$folder")"
  hex() { color "$1" | tr -d '#'; }
  expected="Jenerated Sunset com.github.savagejen.jenerated-themes.sunset /jenerated-sunset.theme.json
Jenerated Sunset ExperimentalDark /jenerated-sunset.xml Jenerated Sunset Darcula
$(color bg) $(color bg_sidebar) $(color accent) $(color green)1A $(color red)
$(hex accent) $(hex bg) $(hex green) $(hex term_red)"
  [ "$result" = "$expected" ] || fail "expected JetBrains theme values:
$expected
got:
$result"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its whole JetBrains theme folder is deleted, including the META-INF
#      folder inside it, and the templates are kept
test_remove_deletes_the_jetbrains_theme() {
  generate sunset
  remove sunset
  assert_status 0
  assert_contains "Removed app-themes/jetbrains-theme/sunset/META-INF/plugin.xml"
  assert_missing "$(jetbrains_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/jetbrains-theme/plugin.xml.tmpl"
}

# --- Tests: installing -------------------------------------------------------

JETBRAINS_DIR="app-themes/jetbrains-theme"

# GIVEN settings folders for IntelliJ IDEA and PyCharm 2026.2 and Android
#       Studio (under Google), plus JetBrains Toolbox's folder, which isn't an IDE
# WHEN choosing JetBrains Apps and Blue Purple
# THEN the plugin is linked into each IDE's plugins folder under
#      ~/.local/share, but not Toolbox's, and it says to restart and choose it
test_jetbrains_links_the_plugin_into_each_ide() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/JetBrains/IntelliJIdea2026.2" "$SANDBOX/home/.config/JetBrains/PyCharm2026.2" \
    "$SANDBOX/home/.config/JetBrains/Toolbox" "$SANDBOX/home/.config/Google/AndroidStudio2026.1"
  install_app jetbrains blue-purple "y\n1\n"
  assert_status 0
  for dir in JetBrains/IntelliJIdea2026.2 JetBrains/PyCharm2026.2 Google/AndroidStudio2026.1; do
    assert_link "$SANDBOX/home/.local/share/$dir/jenerated-blue-purple.jar" \
      "$SANDBOX/repo/app-themes/jetbrains-theme/jenerated-blue-purple.jar"
  done
  assert_missing "$SANDBOX/home/.local/share/JetBrains/Toolbox"
  assert_contains "Restart the IDE"
  assert_not_contains "Install Plugin from Disk"
}

# GIVEN a Mac with PyCharm 2026.2's settings folder
# WHEN choosing JetBrains Apps and Blue Purple
# THEN the plugin goes in the plugins folder inside it
test_jetbrains_on_macos_uses_the_plugins_folder() {
  fake_os Darwin
  mkdir -p "$SANDBOX/home/Library/Application Support/JetBrains/PyCharm2026.2"
  install_app jetbrains blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/JetBrains/PyCharm2026.2/plugins/jenerated-blue-purple.jar" \
    "$SANDBOX/repo/app-themes/jetbrains-theme/jenerated-blue-purple.jar"
}

# GIVEN the Sunset palette
# WHEN choosing JetBrains apps and Sunset
# THEN the theme is packaged as a plugin .jar holding its descriptor, UI theme
#      and editor scheme, each pointing at files in the .jar, and it explains
#      installing it from disk
test_jetbrains_packages_the_plugin() {
  install_app jetbrains sunset
  assert_status 0
  jar="$SANDBOX/repo/$JETBRAINS_DIR/jenerated-sunset.jar"
  assert_exists "$jar"
  result="$("$(find_python)" -c '
import json, sys, zipfile, xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
names = sorted(z.namelist())
plugin = ET.fromstring(z.read("META-INF/plugin.xml"))
theme_path = plugin.find("extensions/themeProvider").get("path").lstrip("/")
theme = json.loads(z.read(theme_path))
scheme_path = theme["editorScheme"].lstrip("/")
print(names, theme_path in names, scheme_path in names, theme["name"])
' "$jar")"
  [ "$result" = "['META-INF/plugin.xml', 'jenerated-sunset.theme.json', 'jenerated-sunset.xml'] True True Jenerated Sunset" ] ||
    fail "unexpected .jar contents: $result"
  assert_contains '"Install Plugin from Disk..."'
  assert_contains "IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm, GoLand,"
  assert_contains "$jar"
  assert_contains '"Jenerated Sunset" as the theme'
}

run_tests
