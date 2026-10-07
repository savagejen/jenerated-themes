#!/usr/bin/env bash
# Tests for Insomnia (API client): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-insomnia.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
insomnia_plugin() { printf '%s' "$SANDBOX/repo/app-themes/insomnia-theme/$1/insomnia-plugin-jenerated-$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN its Insomnia plugin's package.json is valid JSON naming the plugin
#      insomnia-plugin-jenerated-sunset, with an insomnia section that
#      declares no permissions (a theme needs none)
test_insomnia_plugin_package_json() {
  generate sunset
  result="$("$PYTHON" -c '
import json, sys
p = json.load(open(sys.argv[1]))
print(p["name"], p["main"], p["insomnia"]["name"], p["insomnia"]["permissions"])
' "$(insomnia_plugin sunset)/package.json")"
  expected="insomnia-plugin-jenerated-sunset index.js Jenerated Sunset {'modules': [], 'capabilities': []}"
  [ "$result" = "$expected" ] || fail "expected '$expected', got '$result'"
}

# GIVEN the Sunset palette, and Node.js
# WHEN generating it and loading its plugin the way Insomnia would
# THEN it exports one theme, named in lowercase without spaces (as Insomnia
#      requires), whose every block has a default color, with the palette's
#      background, text, accent (Insomnia's "surprise") and sidebar
test_insomnia_plugin_exports_the_theme() {
  command -v node >/dev/null 2>&1 || return 0
  generate sunset
  OUTPUT="$(node -e '
const themes = require(process.argv[1]).themes;
if (themes.length !== 1) console.log(`expected one theme, got ${themes.length}`);
const t = themes[0];
if (t.name !== t.name.replace(/\s/g, "-").toLowerCase()) console.log(`invalid theme name ${t.name}`);
const blocks = [t.theme, ...Object.values(t.theme.styles)];
for (const block of blocks)
  for (const part of ["background", "foreground", "highlight"])
    if (block[part] && !block[part].default) console.log(`a ${part} block has no default`);
console.log([t.name, t.displayName, t.theme.background.default, t.theme.foreground.default,
  t.theme.background.surprise, t.theme.styles.sidebar.background.default].join(" "));
' "$(insomnia_plugin sunset)/index.js" 2>&1)"
  expected="jenerated-sunset Jenerated Sunset $(color bg) $(color text) $(color accent) $(color bg_sidebar)"
  [ "$OUTPUT" = "$expected" ] || fail "expected '$expected'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Insomnia folder is deleted, and the templates are kept
test_remove_deletes_the_insomnia_plugin() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/insomnia-theme/sunset/insomnia-plugin-jenerated-sunset/index.js"
  assert_missing "$SANDBOX/repo/app-themes/insomnia-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/insomnia-theme/index.js.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN Insomnia without plugins
# WHEN choosing Insomnia and Blue Purple
# THEN Blue Purple's plugin is copied (not linked: Insomnia ignores links to
#      folders elsewhere) into Insomnia's plugins folder, and it explains how
#      to reload plugins and choose the theme
test_insomnia_copies_the_plugin() {
  fake_os Linux
  install_app insomnia blue-purple
  assert_status 0
  plugin="$SANDBOX/home/.config/Insomnia/plugins/insomnia-plugin-jenerated-blue-purple"
  [ -d "$plugin" ] && [ ! -L "$plugin" ] || fail "expected a copied plugin folder at $plugin"
  assert_same_file "$plugin/index.js" \
    "$SANDBOX/repo/app-themes/insomnia-theme/blue-purple/insomnia-plugin-jenerated-blue-purple/index.js"
  assert_exists "$plugin/package.json"
  assert_contains "-> Plugins and choose Reload."
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN Blue Purple's plugin copied before, with a file from an older version
#       in it, and another plugin of the user's own
# WHEN choosing Insomnia and Blue Purple again, then Sunset
# THEN Blue Purple's folder is replaced by a fresh copy, Sunset's plugin is
#      added beside it, and the other plugin is left alone
test_insomnia_replaces_its_own_plugin() {
  fake_os Linux
  plugins="$SANDBOX/home/.config/Insomnia/plugins"
  mkdir -p "$plugins/insomnia-plugin-jenerated-blue-purple" "$plugins/insomnia-plugin-other"
  printf 'old\n' >"$plugins/insomnia-plugin-jenerated-blue-purple/stale.js"
  printf '{}\n' >"$plugins/insomnia-plugin-other/package.json"
  install_app insomnia blue-purple
  install_app insomnia sunset
  assert_status 0
  assert_missing "$plugins/insomnia-plugin-jenerated-blue-purple/stale.js"
  assert_exists "$plugins/insomnia-plugin-jenerated-blue-purple/index.js"
  assert_exists "$plugins/insomnia-plugin-jenerated-sunset/index.js"
  assert_file_equals "$plugins/insomnia-plugin-other/package.json" "{}"
}

# GIVEN Insomnia installed through Flatpak and through Snap, and on a Mac
# WHEN choosing Insomnia
# THEN each of their plugins folders gets the plugin; and on a Mac it goes in
#      Application Support
test_insomnia_themes_flatpak_snap_and_macos() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/rest.insomnia.Insomnia" "$SANDBOX/home/snap/insomnia"
  install_app insomnia blue-purple
  assert_status 0
  for dir in "$SANDBOX/home/.config/Insomnia/plugins" \
    "$SANDBOX/home/.var/app/rest.insomnia.Insomnia/config/Insomnia/plugins" \
    "$SANDBOX/home/snap/insomnia/current/.config/Insomnia/plugins"; do
    assert_exists "$dir/insomnia-plugin-jenerated-blue-purple/index.js"
  done
  fake_os Darwin
  install_app insomnia blue-purple
  assert_status 0
  assert_exists "$SANDBOX/home/Library/Application Support/Insomnia/plugins/insomnia-plugin-jenerated-blue-purple/index.js"
}

run_tests
