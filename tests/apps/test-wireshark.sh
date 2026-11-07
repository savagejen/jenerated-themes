#!/usr/bin/env bash
# Tests for Wireshark (network analyzer): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-wireshark.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

wireshark_rules() { printf '%s' "$SANDBOX/repo/app-themes/wireshark-theme/$1/colorfilters"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Wireshark coloring rules
# THEN every rule line is @name@filter@[r,g,b][r,g,b] with channels from 0 to
#      65535, bad TCP is Sunset's red behind its background color, TCP is its
#      function color on its background, and the last rule matches every
#      packet ("frame") in its text and background colors
test_wireshark_rules_use_the_palette() {
  generate sunset
  rules="$(wireshark_rules sunset)"
  OUTPUT="$(grep '^@' "$rules" | grep -vE '^@[^@]+@[^@]+@\[[0-9]{1,5},[0-9]{1,5},[0-9]{1,5}\]\[[0-9]{1,5},[0-9]{1,5},[0-9]{1,5}\]$')"
  [ -z "$OUTPUT" ] || fail "these rules aren't in Wireshark's format: $OUTPUT"
  rgb16() { color_rgb "$1" | tr -d ' ' | awk -F, '{ print $1 * 257 "," $2 * 257 "," $3 * 257 }'; }
  assert_file_contains "$rules" "@Bad TCP@tcp.analysis.flags && !tcp.analysis.window_update && !tcp.analysis.keep_alive && !tcp.analysis.keep_alive_ack@[$(rgb16 red)][$(rgb16 bg)]"
  assert_file_contains "$rules" "@TCP@tcp@[$(rgb16 bg)][$(rgb16 accent_light)]"
  [ "$(grep '^@' "$rules" | tail -n 1)" = "@Everything else@frame@[$(rgb16 bg)][$(rgb16 text)]" ] ||
    fail "expected the catch-all rule last"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN its Wireshark rules have Wireshark's default rules' names and filters,
#      in the same order (the template's rules, minus the catch-all at the end)
test_wireshark_rules_keep_the_default_filters() {
  generate sunset
  count="$(grep -c '^@' "$(wireshark_rules sunset)")"
  [ "$count" = "21" ] || fail "expected Wireshark's 20 default rules plus the catch-all, got $count"
  assert_file_contains "$(wireshark_rules sunset)" "@Checksum Errors@eth.fcs.status==\"Bad\" || ip.checksum.status==\"Bad\""
  assert_file_contains "$(wireshark_rules sunset)" "@HTTP@http || tcp.port == 80 || http2 || http3@"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Linux
# WHEN choosing Wireshark and Blue Purple
# THEN the coloring rules are linked into a "Jenerated Blue Purple" profile in
#      Wireshark's config folder, leaving the Default profile alone, and it
#      says how to switch to the profile
test_wireshark_makes_a_profile() {
  fake_os Linux
  install_app wireshark blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/wireshark/profiles/Jenerated Blue Purple/colorfilters" \
    "$SANDBOX/repo/app-themes/wireshark-theme/blue-purple/colorfilters"
  assert_missing "$SANDBOX/home/.config/wireshark/colorfilters"
  assert_contains 'choose "Jenerated Blue Purple"'
  assert_contains "View -> Colorize Packet List"
}

# GIVEN a ~/.wireshark folder from an older Wireshark, and the Flatpak
# WHEN choosing Wireshark and Blue Purple
# THEN the profile goes in ~/.wireshark (which Wireshark still uses then),
#      and in the Flatpak's config folder, not in ~/.config/wireshark
test_wireshark_uses_an_old_folder_and_the_flatpak() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.wireshark" "$SANDBOX/home/.var/app/org.wireshark.Wireshark"
  install_app wireshark blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.wireshark/profiles/Jenerated Blue Purple/colorfilters" \
    "$SANDBOX/repo/app-themes/wireshark-theme/blue-purple/colorfilters"
  assert_link "$SANDBOX/home/.var/app/org.wireshark.Wireshark/config/wireshark/profiles/Jenerated Blue Purple/colorfilters" \
    "$SANDBOX/repo/app-themes/wireshark-theme/blue-purple/colorfilters"
  assert_missing "$SANDBOX/home/.config/wireshark"
}

run_tests
