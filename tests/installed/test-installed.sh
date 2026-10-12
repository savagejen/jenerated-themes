#!/usr/bin/env bash
# Tests for an installed copy of jenerate (pipx, or a .deb, .rpm or Arch
# package), as opposed to a clone: it reads templates and bundled palettes
# from its read-only package data, and writes themes, your palettes and the
# Palette Creator's draft to its data folder (see jenerate_themes/paths.py).
# make_installed, in tests/lib.sh, builds the installed copy.
#
# Usage: tests/installed/test-installed.sh [part of a test's name]

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ]; then
  printf 'skipped: jenerate needs Python 3.11 or later\n'
  exit 0
fi

# No test changes your desktop or clipboard; the system is Linux.
after_sandbox() {
  quiet_desktop
  fake_os Linux
  make_installed
  DATA="$SANDBOX/home/$INSTALLED_DATA_PATH"
  BUNDLED="$SANDBOX/site/jenerate_themes/data"
}

# site_listing -> prints every file in the installed copy, with its checksum.
site_listing() {
  (cd "$SANDBOX/site" && find . -type f -exec cksum {} + | sort)
}

# my_palette folder slug name -> writes a copy of Sunset with this slug and
# name into a folder.
my_palette() {
  mkdir -p "$1"
  sed -e "s/^name = .*/name = \"$3\"/" -e "s/^slug = .*/slug = \"$2\"/" \
    "$BUNDLED/palettes/Dark/sunset-palette.toml" >"$1/$2-palette.toml"
}

# --- Tests: palettes and generating ------------------------------------------

# GIVEN an installed copy
# WHEN listing the palettes
# THEN the bundled ones are listed, none generated yet
test_lists_the_bundled_palettes() {
  run_installed "" list
  assert_status 0
  assert_contains "  blue-purple "
  assert_contains "  sunset "
  assert_not_contains "* sunset"
}

# GIVEN an installed copy
# WHEN generating Sunset
# THEN its themes are written to the data folder, and the installed copy
#      itself is unchanged
test_generates_into_the_data_folder() {
  before="$(site_listing)"
  run_installed "" generate sunset
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$DATA/app-themes/tilix-theme/sunset.json"
  assert_exists "$DATA/app-themes/vs-code-theme/package.json"
  assert_file_contains "$DATA/app-themes/vs-code-theme/package.json" "jenerated-sunset-color-theme.json"
  [ "$(site_listing)" = "$before" ] || fail "expected the installed copy to be unchanged"
  run_installed "" list
  assert_contains "* sunset "
}

# GIVEN XDG_DATA_HOME set to a folder
# WHEN generating Sunset with an installed copy
# THEN its themes go in jenerate-themes in that folder
test_xdg_data_home_moves_the_data_folder() {
  OUTPUT="$(cd "$SANDBOX/elsewhere" && HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" \
    XDG_DATA_HOME="$SANDBOX/xdg" PYTHONDONTWRITEBYTECODE=1 jenerate generate sunset 2>&1)"
  STATUS=$?
  assert_status 0
  assert_exists "$SANDBOX/xdg/jenerate-themes/app-themes/tilix-theme/sunset.json"
  assert_missing "$DATA"
}

# GIVEN an installed copy, and Sunset generated
# WHEN removing Sunset
# THEN its files are deleted from the data folder, and Blue Purple's are kept
test_remove_deletes_only_its_files() {
  run_installed "" generate sunset blue-purple
  run_installed "" remove sunset
  assert_status 0
  assert_contains "Removed ~/$INSTALLED_DATA_PATH/app-themes/tilix-theme/sunset.json"
  assert_missing "$DATA/app-themes/tilix-theme/sunset.json"
  assert_missing "$DATA/app-themes/obsidian-theme/sunset"
  assert_exists "$DATA/app-themes/tilix-theme/blue-purple.json"
}

# GIVEN a palette file in the folder jenerate is run from
# WHEN generating it by its relative path
# THEN it's found there
test_palette_path_is_taken_from_where_it_runs() {
  my_palette "$SANDBOX/elsewhere" forest "Forest"
  run_installed "" generate ./forest-palette.toml
  assert_status 0
  assert_contains "Generated Forest (forest)"
  assert_exists "$DATA/app-themes/tilix-theme/forest.json"
}

# --- Tests: your palettes ----------------------------------------------------

# GIVEN a palette of your own in the data folder's palettes/Dark
# WHEN listing and generating it
# THEN it's listed with the bundled palettes, and generated like them
test_your_palette_is_listed_and_generated() {
  my_palette "$DATA/palettes/Dark" forest "Forest"
  run_installed "" list
  assert_contains "  forest "
  assert_contains "  sunset "
  run_installed "" generate forest
  assert_status 0
  assert_exists "$DATA/app-themes/tilix-theme/forest.json"
}

# GIVEN a palette of your own with a bundled palette's slug
# WHEN listing and generating it
# THEN yours replaces the bundled one, with no complaint about the slug
test_your_palette_replaces_a_bundled_one() {
  my_palette "$DATA/palettes/Dark" sunset "My Sunset"
  run_installed "" list
  assert_status 0
  assert_contains "My Sunset"
  [ "$(printf '%s\n' "$OUTPUT" | grep -c ' sunset ')" = 1 ] ||
    fail "expected sunset to be listed once"
  run_installed "" generate sunset
  assert_status 0
  assert_contains "Generated My Sunset (sunset)"
}

# GIVEN two palettes of your own with one slug, in Dark and Light
# WHEN generating it
# THEN it stops, naming both, as in a clone
test_two_of_your_palettes_with_one_slug_stop() {
  my_palette "$DATA/palettes/Dark" forest "Forest"
  my_palette "$DATA/palettes/Light" forest "Forest"
  run_installed "" generate forest
  assert_status 1
  assert_contains "is in more than one place"
}

# --- Tests: the pre-made Blue Purple -----------------------------------------

# GIVEN an installed copy
# WHEN installing Blue Purple into Tilix
# THEN the scheme is linked to the data folder's copy of the pre-made theme,
#      the same as the one the installed copy comes with
test_installs_the_pre_made_blue_purple() {
  run_installed "y\n1\n" install tilix blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$DATA/app-themes/tilix-theme/blue-purple.json"
  assert_same_file "$DATA/app-themes/tilix-theme/blue-purple.json" \
    "$BUNDLED/app-themes/tilix-theme/blue-purple.json"
}

# GIVEN Blue Purple set up from an installed copy
# WHEN the installed copy's Blue Purple changes (an upgrade), and jenerate runs
# THEN the data folder's copy is brought up to date
test_refreshes_blue_purple_after_an_upgrade() {
  run_installed "" generate blue-purple
  chmod u+w "$BUNDLED/app-themes/tilix-theme" "$BUNDLED/app-themes/tilix-theme/blue-purple.json"
  printf '{"upgraded": true}\n' >"$BUNDLED/app-themes/tilix-theme/blue-purple.json"
  chmod a-w "$BUNDLED/app-themes/tilix-theme" "$BUNDLED/app-themes/tilix-theme/blue-purple.json"
  run_installed "" list
  assert_status 0
  assert_same_file "$DATA/app-themes/tilix-theme/blue-purple.json" \
    "$BUNDLED/app-themes/tilix-theme/blue-purple.json"
}

# GIVEN an installed copy where Blue Purple was never set up
# WHEN jenerate runs
# THEN nothing is copied into the data folder
test_blue_purple_is_only_copied_when_needed() {
  run_installed "" list
  assert_missing "$DATA"
}

# GIVEN a palette of your own called blue-purple, with another background
# WHEN generating it
# THEN its themes are made from it, not copied from the pre-made ones
test_your_blue_purple_is_generated() {
  mkdir -p "$DATA/palettes/Dark"
  sed 's/^bg = "#[0-9a-fA-F]*"/bg = "#010203"/' "$BUNDLED/palettes/Dark/blue-purple-palette.toml" \
    >"$DATA/palettes/Dark/blue-purple-palette.toml"
  run_installed "" generate blue-purple
  assert_status 0
  assert_file_contains "$DATA/app-themes/tilix-theme/blue-purple.json" "#010203"
}

# --- Tests: a clone and an installed copy on one computer --------------------

# clone_install app palette answers -> installs from the sandbox's clone, the
# way ./jenerate does from a repository.
clone_install() {
  OUTPUT="$(cd "$SANDBOX/repo" && printf '%b' "$3" |
    in_sandbox "$PYTHON" ./jenerate install "$1" "$2" 2>&1)"
  STATUS=$?
}

# GIVEN VS Code's extension linked to a clone
# WHEN installing VS Code from an installed copy, and replacing the link
# THEN the question names both folders, it warns that VS Code will show the
#      installed copy's themes instead, and the link is replaced
test_vscode_from_a_clone_then_installed() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  clone_install vscode blue-purple "y\n1\n"
  run_installed "y\n1\ny\n" install vscode blue-purple
  assert_status 0
  assert_contains "linked to $SANDBOX/repo."
  assert_contains "VS Code will then show the themes generated in ~/$INSTALLED_DATA_PATH"
  assert_contains "Replace it with a link to ~/$INSTALLED_DATA_PATH?"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$DATA/app-themes/vs-code-theme"
}

# GIVEN VS Code's extension linked to an installed copy's data folder
# WHEN installing VS Code from a clone, and replacing the link
# THEN it says the same the other way around
test_vscode_from_installed_then_a_clone() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  run_installed "y\n1\n" install vscode blue-purple
  clone_install vscode blue-purple "y\n1\ny\n"
  assert_status 0
  assert_contains "linked to ~/$INSTALLED_DATA_PATH."
  assert_contains "VS Code will then show the themes generated in $SANDBOX/repo"
  assert_contains "Replace it with a link to $SANDBOX/repo?"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
}

# GIVEN Tilix's scheme linked to a clone
# WHEN installing it from an installed copy
# THEN the question names both folders, without the warning only links
#      shared by every palette get
test_tilix_from_a_clone_then_installed() {
  clone_install tilix blue-purple "y\n1\n"
  run_installed "y\n1\ny\n" install tilix blue-purple
  assert_status 0
  assert_contains "linked to $SANDBOX/repo."
  assert_not_contains "will then show"
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$DATA/app-themes/tilix-theme/blue-purple.json"
}

# --- Tests: the Palette Creator ----------------------------------------------

# GIVEN the Palette Creator started from an installed copy
# WHEN saving the draft as a new palette
# THEN the draft and the palette are in the data folder, and the message
#      names the data folder and the jenerate command
test_palette_creator_saves_to_the_data_folder() {
  command -v curl >/dev/null 2>&1 || return 0
  port="$("$PYTHON" -c '
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
')"
  (cd "$SANDBOX/elsewhere" && exec env HOME="$SANDBOX/home" XDG_DATA_HOME= \
    PALETTE_CREATOR_DIALOG=none JENERATE_COMMAND= PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH="$SANDBOX/site" "$PYTHON" -P -m jenerate_themes.creator.serve --no-browser \
    --port "$port" >"$SANDBOX/server.log" 2>&1) &
  server=$!
  trap 'kill "$server" 2>/dev/null; chmod -R u+w "$SANDBOX"; rm -rf "$SANDBOX"' EXIT
  for _ in $(seq 100); do
    curl -s -o /dev/null "http://127.0.0.1:$port/" && break
    "$PYTHON" -c 'import time; time.sleep(0.05)'
  done
  assert_exists "$DATA/palette-creator/work-in-progress-palette.toml"
  body="$(curl -s "http://127.0.0.1:$port/api/palette" | "$PYTHON" -c '
import json, sys
p = json.load(sys.stdin)["palette"]
p["name"], p["slug"] = "Forest", "forest"
print(json.dumps({"palette": p, "target": "palette", "filename": "forest-palette.toml"}))
')"
  OUTPUT="$(curl -s -X POST -H "Content-Type: application/json" --data-binary "$body" \
    "http://127.0.0.1:$port/api/save")"
  assert_exists "$DATA/palettes/Dark/forest-palette.toml"
  assert_contains "Saved ~/$INSTALLED_DATA_PATH/palettes/Dark/forest-palette.toml"
  assert_contains "jenerate generate forest"
}

run_tests
