#!/usr/bin/env bash
# Tests for RStudio: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-rstudio.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
rstudio_theme() { printf '%s' "$SANDBOX/repo/app-themes/rstudio-theme/jenerated-$1.rstheme"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette, and a light palette
# WHEN generating them and reading each theme's header with the regular
#      expressions RStudio itself uses
# THEN each is named after its palette and marked dark or light to match
test_rstudio_theme_header() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  result="$("$PYTHON" -c '
import re, sys
for path in sys.argv[1:]:
    text = open(path).read()
    name = re.search(r"rs-theme-name\s*:\s*([^\*]+?)\s*(?:\*|$)", text, re.M).group(1)
    dark = re.search(r"rs-theme-is-dark\s*:\s*([^\*]+?)\s*(?:\*|$)", text, re.M).group(1)
    print(f"{name}|{dark}")
' "$(rstudio_theme sunset)" "$(rstudio_theme daylight)")"
  expected="Jenerated Sunset|TRUE
Jenerated Daylight|FALSE"
  [ "$result" = "$expected" ] || fail "expected:
$expected
got:
$result"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN its RStudio theme colors the editor, strings, keywords and functions
#      from the palette (as in the VS Code theme), and the console's 16
#      colors are the palette's terminal colors
test_rstudio_theme_uses_the_palette() {
  generate sunset
  theme="$(rstudio_theme sunset)"
  OUTPUT="$("$PYTHON" -c '
import re, sys
css = open(sys.argv[1]).read()
def color_of(selector, prop="color"):
    m = re.search(r"(?:^|\n)" + re.escape(selector) + r"[^{]*\{([^}]*)\}", css)
    return re.search(prop + r"\s*:\s*([^;\n]+)", m.group(1)).group(1).strip() if m else None
print(color_of(".ace_editor, .ace_editor_theme .profvis-flamegraph, .ace_editor_theme", "background-color"),
      color_of(".ace_string"), color_of(".ace_keyword"), color_of(".ace_entity.ace_name.ace_function"))
' "$theme")"
  expected="$(color bg) $(color green) $(color accent_soft) $(color accent_light)"
  [ "$OUTPUT" = "$expected" ] || fail "expected '$expected'"
  assert_file_contains "$theme" ".xtermColor1 { color: $(color term_red) !important; }"
  assert_file_contains "$theme" ".xtermColor12 { color: $(color term_bright_blue) !important; }"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN its RStudio theme has the rules RStudio adds to every theme (the
#      keyword rule for uncolored text, a bracket border, chunk, debug and
#      find lines, the terminal), all 256 console colors, and balanced braces
test_rstudio_theme_has_rstudios_rules() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
css = open(sys.argv[1]).read()
for rule in (".nocolor.ace_editor .ace_line span", ".ace_marker-layer .ace_bracket", ".ace_marker-layer .ace_foreign_line",
             ".ace_marker-layer .ace_active_debug_line", ".ace_marker-layer .ace_find_line", ".ace_console_error",
             ".terminal {", ".terminal .xterm-viewport", ".xtermInvertColor"):
    if rule not in css:
        print(f"missing {rule}")
if not re.search(r"\.ace_marker-layer \.ace_bracket \{[^}]*border:", css):
    print("the bracket rule has no border (RStudio needs one)")
for n in range(256):
    for kind in ("Color", "BgColor"):
        if f".xterm{kind}{n} " not in css:
            print(f"missing .xterm{kind}{n}")
if css.count("{") != css.count("}"):
    print("the braces do not balance")
' "$(rstudio_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its RStudio theme is deleted, and the template is kept
test_remove_deletes_the_rstudio_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/rstudio-theme/jenerated-sunset.rstheme"
  assert_missing "$(rstudio_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/rstudio-theme/theme.rstheme.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN RStudio's settings in the usual place
# WHEN choosing RStudio and Blue Purple
# THEN the theme is linked into ~/.config/rstudio/themes, and it explains
#      where to choose it
test_rstudio_links_the_theme() {
  fake_os Linux
  install_app rstudio blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/rstudio/themes/jenerated-blue-purple.rstheme" \
    "$SANDBOX/repo/app-themes/rstudio-theme/jenerated-blue-purple.rstheme"
  assert_contains "Tools -> Global Options -> Appearance"
  assert_contains 'Choose "Jenerated Blue Purple" as the Editor theme'
}

# GIVEN RSTUDIO_CONFIG_HOME set to another folder, as RStudio allows
# WHEN choosing RStudio
# THEN the theme goes in that folder's themes folder instead
test_rstudio_uses_rstudio_config_home() {
  fake_os Darwin
  TEST_RSTUDIO_CONFIG_HOME="$SANDBOX/home/rs-config" install_app rstudio blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/rs-config/themes/jenerated-blue-purple.rstheme" \
    "$SANDBOX/repo/app-themes/rstudio-theme/jenerated-blue-purple.rstheme"
  assert_missing "$SANDBOX/home/.config/rstudio"
}

run_tests
