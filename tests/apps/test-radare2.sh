#!/usr/bin/env bash
# Tests for radare2 and rizin: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-radare2.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

r2_theme() { printf '%s' "$SANDBOX/repo/app-themes/radare2-theme/jenerated-$1"; }
rizin_theme() { printf '%s' "$SANDBOX/repo/app-themes/rizin-theme/jenerated-$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating its radare2 and rizin themes
# THEN each is radare2 commands: comments, then "ecd" (back to the defaults),
#      then "ec <name> rgb:RRGGBB", with an optional background; comments are
#      Sunset's muted text, and the current line has its line highlight behind
#      it; radare2 calls addresses addr, rizin offset
test_r2_themes_follow_the_palette() {
  generate sunset
  hex() { color "$1" | tr -d '#'; }
  for theme in "$(r2_theme sunset)" "$(rizin_theme sunset)"; do
    OUTPUT="$(grep -v -e '^#' -e '^ecd$' "$theme" | grep -vE '^ec [a-z0-9._]+ rgb:[0-9a-fA-F]{6}( rgb:[0-9a-fA-F]{6})?$')"
    [ -z "$OUTPUT" ] || fail "these lines aren't radare2 color commands: $OUTPUT"
    [ "$(grep -v '^#' "$theme" | head -n 1)" = "ecd" ] || fail "expected ecd first in $theme"
    assert_file_contains "$theme" "ec comment rgb:$(hex text_muted)"
    assert_file_contains "$theme" "ec linehl rgb:$(hex text) rgb:$(hex bg_line_highlight)"
  done
  assert_file_contains "$(r2_theme sunset)" "ec addr rgb:"
  assert_file_not_contains "$(r2_theme sunset)" "ec offset "
  assert_file_contains "$(rizin_theme sunset)" "ec offset rgb:"
  assert_file_not_contains "$(rizin_theme sunset)" "ec addr "
  assert_file_contains "$(rizin_theme sunset)" "ec widget_sel rgb:"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN no ~/.radare2rc
# WHEN choosing radare2 and Blue Purple
# THEN the theme is linked into ~/.local/share/radare2/cons, and a new
#      ~/.radare2rc loads it with 24-bit color
test_radare2_links_the_theme_and_loads_it() {
  fake_os Linux
  install_app radare2 blue-purple "y\n1\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/radare2/cons/jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/radare2-theme/jenerated-blue-purple"
  assert_file_contains "$SANDBOX/home/.radare2rc" "e scr.color=3"
  assert_file_contains "$SANDBOX/home/.radare2rc" "eco jenerated-blue-purple"
}

# GIVEN ~/.radare2rc with your settings and Blue Purple's theme loaded
# WHEN choosing radare2 and Sunset
# THEN the line switches to Sunset's theme, without asking or adding another,
#      and your settings stay
test_radare2_switching_palettes_replaces_the_line() {
  fake_os Linux
  printf 'e asm.bytes=false\ne scr.color=3\neco jenerated-blue-purple\n' >"$SANDBOX/home/.radare2rc"
  install_app radare2 sunset "y\n1\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.radare2rc" "eco jenerated-sunset"
  assert_file_not_contains "$SANDBOX/home/.radare2rc" "eco jenerated-blue-purple"
  assert_file_contains "$SANDBOX/home/.radare2rc" "e asm.bytes=false"
  [ "$(grep -c '^eco ' "$SANDBOX/home/.radare2rc")" = "1" ] || fail "expected one eco line"
}

# GIVEN ~/.radare2rc with your settings
# WHEN choosing radare2 and Blue Purple, and answering no to loading it
# THEN the file is left alone, and it says what to add
test_radare2_leaves_its_rc_alone_when_declined() {
  fake_os Linux
  printf 'e asm.bytes=false\n' >"$SANDBOX/home/.radare2rc"
  cp "$SANDBOX/home/.radare2rc" "$SANDBOX/before"
  install_app radare2 blue-purple "y\n1\nn\n"
  assert_status 0
  assert_same_file "$SANDBOX/home/.radare2rc" "$SANDBOX/before"
  assert_contains "    eco jenerated-blue-purple"
}

# GIVEN no rizin startup file
# WHEN choosing rizin and Blue Purple
# THEN rizin's theme is linked into ~/.local/share/rizin/cons, and
#      ~/.config/rizin/rizinrc is started, loading it
test_rizin_links_its_own_theme() {
  fake_os Linux
  install_app rizin blue-purple "y\n1\ny\n"
  assert_status 0
  assert_link "$SANDBOX/home/.local/share/rizin/cons/jenerated-blue-purple" \
    "$SANDBOX/repo/app-themes/rizin-theme/jenerated-blue-purple"
  assert_file_contains "$SANDBOX/home/.config/rizin/rizinrc" "eco jenerated-blue-purple"
}

# GIVEN dark palettes and a light one
# WHEN choosing radare2
# THEN ALL THE PALETTES isn't offered, since its startup file loads one theme
test_radare2_has_no_all_the_palettes() {
  fake_os Linux
  dawn_palette Light
  run_setup "1\nradare2\n1\n1\n1\ny\n1\nn\n"
  assert_not_contains "ALL THE PALETTES"
}

run_tests
