#!/usr/bin/env bash
# Tests for KDE Plasma (Plasma and KDE apps, Konsole, Kate): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-kde.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
kde_theme() { printf '%s' "$SANDBOX/repo/app-themes/kde-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# kde_ini file -> prints "section|key=value" for every entry in a KDE config
# file (a color scheme or Konsole scheme), read with Python's INI parser.
kde_ini() {
  "$PYTHON" -c '
import configparser, sys
cp = configparser.RawConfigParser(strict=True, comment_prefixes=("#",))
cp.optionxform = str
cp.read(sys.argv[1])
for s in cp.sections():
    for k, v in cp[s].items():
        print(f"{s}|{k}={v}")
' "$1"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Plasma color scheme is named after the palette, and uses Sunset's
#      colors, as r,g,b, for windows, views, buttons, selection and title bars
test_kde_color_scheme_uses_the_palette() {
  generate sunset
  entries="$(kde_ini "$(kde_theme sunset)/Jenerated-sunset.colors")"
  csv() { color_rgb "$1" | tr -d ' '; }
  for expected in "General|ColorScheme=Jenerated-sunset" "General|Name=Jenerated Sunset" \
    "Colors:Window|BackgroundNormal=$(csv bg_sidebar)" "Colors:View|BackgroundNormal=$(csv bg)" \
    "Colors:View|ForegroundNormal=$(csv text)" "Colors:Button|BackgroundNormal=$(csv bg_hover)" \
    "Colors:Selection|BackgroundNormal=$(csv accent)" "Colors:Header][Inactive|ForegroundNormal=$(csv text_muted)" \
    "WM|activeBackground=$(csv bg_chrome)"; do
    case "$entries" in
      *"$expected"*) ;;
      *) fail "expected the color scheme to have $expected" ;;
    esac
  done
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Konsole scheme has the 16 terminal colors (normal, faint and
#      intense), the background and foreground, and the palette's name
test_konsole_scheme_uses_the_palette() {
  generate sunset
  entries="$(kde_ini "$(kde_theme sunset)/Jenerated-sunset.colorscheme")"
  csv() { color_rgb "$1" | tr -d ' '; }
  count="$(printf '%s\n' "$entries" | grep -c '^Color[0-7]\(Faint\|Intense\)\?|Color=')"
  [ "$count" = "24" ] || fail "expected 24 terminal colors, got $count"
  for expected in "Background|Color=$(csv bg)" "Foreground|Color=$(csv text)" \
    "Color1|Color=$(csv term_red)" "Color1Intense|Color=$(csv term_bright_red)" \
    "General|Description=Jenerated Sunset"; do
    case "$entries" in
      *"$expected"*) ;;
      *) fail "expected the Konsole scheme to have $expected" ;;
    esac
  done
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Kate theme is valid JSON named after the palette, with the
#      palette's editor background, keywords and comments
test_kate_theme_uses_the_palette() {
  generate sunset
  theme="$(kde_theme sunset)/Jenerated-sunset.theme"
  assert_valid_json "$theme"
  result="$("$PYTHON" -c '
import json, sys
t = json.load(open(sys.argv[1]))
s = t["text-styles"]
print(t["metadata"]["name"], t["editor-colors"]["BackgroundColor"], s["Keyword"]["text-color"],
      s["Keyword"]["bold"], s["Comment"]["text-color"], s["Comment"]["italic"])
' "$theme")"
  expected="Jenerated Sunset $(color bg) $(color accent_soft) True $(color text_muted) True"
  [ "$result" = "$expected" ] || fail "expected Kate theme values '$expected', got '$result'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its KDE theme folder is deleted, and the templates are kept
test_remove_deletes_the_kde_themes() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/kde-theme/sunset/Jenerated-sunset.colors"
  assert_missing "$(kde_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/kde-theme/colors.tmpl"
}

# --- Tests: installing -------------------------------------------------------

KDE_DATA=".local/share"

# fake_plasma current-scheme -> fakes a working plasma-apply-colorscheme:
# --list-schemes lists Breeze schemes with the given one current, and
# applying a scheme records it in $SANDBOX/plasma-applied.
fake_plasma() {
  fake_command plasma-apply-colorscheme "if [ \"\$1\" = --list-schemes ]; then
  echo 'You have the following color schemes on your system:'
  for s in BreezeClassic BreezeDark BreezeLight; do
    if [ \"\$s\" = '$1' ]; then echo \" * \$s (current color scheme)\"; else echo \" * \$s\"; fi
  done
else
  printf '%s' \"\$1\" >\"$SANDBOX/plasma-applied\"
fi"
}

# GIVEN a Linux system that isn't running Plasma
# WHEN choosing KDE Plasma and Blue Purple
# THEN the color scheme, Konsole colors and Kate theme are linked where KDE
#      looks for them, and it explains how to turn each on
test_kde_links_the_themes() {
  fake_os Linux
  install_app kde blue-purple
  assert_status 0
  folder="$SANDBOX/repo/app-themes/kde-theme/blue-purple"
  assert_link "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-blue-purple.colors" "$folder/Jenerated-blue-purple.colors"
  assert_link "$SANDBOX/home/$KDE_DATA/konsole/Jenerated-blue-purple.colorscheme" "$folder/Jenerated-blue-purple.colorscheme"
  assert_link "$SANDBOX/home/$KDE_DATA/org.kde.syntax-highlighting/themes/Jenerated-blue-purple.theme" "$folder/Jenerated-blue-purple.theme"
  assert_contains "plasma-apply-colorscheme Jenerated-blue-purple"
  assert_contains "Edit Current Profile"
  assert_contains "Configure Kate"
  assert_not_contains "Switch Plasma"
}

# GIVEN Plasma, with Breeze Dark as the color scheme
# WHEN choosing KDE Plasma and Sunset, and answering yes to switching
# THEN Plasma is switched to Jenerated-sunset, and it says how to switch back
#      to Breeze Dark
test_kde_switches_the_color_scheme_when_asked() {
  fake_os Linux
  fake_plasma BreezeDark
  install_app kde sunset "y\n"
  assert_status 0
  assert_contains "Your Plasma color scheme is BreezeDark."
  assert_file_equals "$SANDBOX/plasma-applied" "Jenerated-sunset"
  assert_contains "To switch back: plasma-apply-colorscheme BreezeDark"
  assert_link "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-sunset.colors" \
    "$SANDBOX/repo/app-themes/kde-theme/sunset/Jenerated-sunset.colors"
}

# GIVEN Plasma
# WHEN choosing KDE Plasma and answering no to switching
# THEN the themes are installed but the color scheme is left alone
test_kde_leaves_the_color_scheme_when_declined() {
  fake_os Linux
  fake_plasma BreezeDark
  install_app kde blue-purple "n\n"
  assert_status 0
  assert_missing "$SANDBOX/plasma-applied"
  assert_contains "System Settings -> Colors & Themes -> Colors"
  assert_exists "$SANDBOX/home/$KDE_DATA/color-schemes/Jenerated-blue-purple.colors"
}

run_tests
