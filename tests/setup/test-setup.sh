#!/usr/bin/env bash
# Tests for setup.sh itself: handing over to jenerate when Python 3.11 or
# later is there, installing Blue Purple without it, and its options (--help,
# and the maintainers' ones it hands over to maintainer-tools/).
#
# Usage: tests/setup/test-setup.sh [part of a test's name]
#
# Each test runs from a throwaway copy of the repository, with HOME pointed
# at an empty folder, so nothing outside the sandbox is touched.

source "$(dirname "$0")/../lib.sh"

after_sandbox() {
  quiet_desktop
}

# Makes every python look too old to run jenerate.py.
fake_no_python() {
  for py in python3 python3.13 python3.12 python3.11; do
    fake_command "$py" "exit 1"
  done
}

# sandbox_jenerate args... -> runs the sandbox repository's jenerate.py.
sandbox_jenerate() {
  (cd "$SANDBOX/repo" && "$(find_python)" jenerate.py "$@" >/dev/null 2>&1)
}

# --- Tests: without Python 3.11 or later, and where it's run from ------------

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --design
# THEN it stops, saying the Palette Creator needs Python, without starting it
test_palette_creator_needs_python() {
  stub_palette_creator
  fake_no_python
  run_setup "" --design
  assert_status 1
  assert_contains "the Palette Creator needs Python 3.11 or later"
  assert_missing "$SANDBOX/serve-ran"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --install=slack and saying yes to Blue Purple
# THEN it says Python wasn't found, and installs Blue Purple from the files
#      that come with the repository
test_blue_purple_works_without_python() {
  fake_no_python
  run_setup "y\n" --install=slack
  assert_status 0
  assert_contains "Python 3.11 or later wasn't found, so setup can only install Blue Purple,"
  assert_contains "Using the Blue Purple files that come with the repository."
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
}

# GIVEN no Python 3.11 or later
# WHEN asking for another palette than Blue Purple
# THEN it stops, saying that needs Python, and how to install Blue Purple
test_other_palettes_need_python() {
  fake_no_python
  run_setup "" --install=slack,sunset
  assert_status 1
  assert_contains "installing sunset needs Python 3.11 or later"
  assert_contains "--install=slack,blue-purple"
}

# GIVEN no Python 3.11 or later
# WHEN asking for an app whose install needs Python (fzf edits your shell's
#      settings)
# THEN it stops, listing the apps Blue Purple can be installed into
test_apps_beyond_linking_need_python() {
  fake_os Linux
  fake_no_python
  run_setup "" --install=fzf,blue-purple
  assert_status 1
  assert_contains "installing into fzf needs Python 3.11 or later"
  assert_contains "Without it, Blue Purple can be installed into:"
  assert_contains "tilix"
}

# GIVEN no Python 3.11 or later
# WHEN saying no to installing Blue Purple
# THEN it says to install Python, and installs nothing
test_without_python_declining_blue_purple() {
  fake_os Linux
  fake_no_python
  run_setup "n\n"
  assert_status 0
  assert_contains "Install Python 3.11 or later, then run ./setup.sh again."
  assert_not_contains "Which app do you want to theme?"
  assert_missing "$SANDBOX/home/.config"
}

# GIVEN no Python 3.11 or later, on Linux
# WHEN saying yes to Blue Purple
# THEN the app menu lists only the apps where installing is linking files
#      (or pasting a theme in): Tilix and VS Code, but not fzf or Firefox
test_without_python_menu_lists_the_simple_apps() {
  fake_os Linux
  fake_no_python
  run_setup "y\n"
  assert_contains "Which app do you want to theme?"
  assert_contains ") Tilix (terminal)"
  assert_contains ") VS Code (and Code - OSS, VSCodium)"
  assert_not_contains "fzf"
  assert_not_contains "Firefox"
}

# GIVEN no Python 3.11 or later, on Linux
# WHEN installing Blue Purple into Tilix, and linking
# THEN Blue Purple's committed scheme is linked into Tilix's folder
test_without_python_installs_blue_purple() {
  fake_os Linux
  fake_no_python
  run_setup "y\ny\n1\n" --install=tilix
  assert_status 0
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_contains "Run ./setup.sh again any time to theme another app."
}

# GIVEN the repository is in a folder with a space in its path
# WHEN installing Sunset for Tilix, the VS Code extension, and Blue Purple for
#      Obsidian
# THEN everything is generated there and each link points at the right place
test_repo_in_a_folder_with_spaces() {
  fake_os Linux
  mkdir -p "$SANDBOX/My Projects" "$SANDBOX/Notes/.obsidian"
  mv "$SANDBOX/repo" "$SANDBOX/My Projects/repo"
  local repo="$SANDBOX/My Projects/repo"
  SETUP="$repo/setup.sh"
  run_setup "1\ntilix\n1\n2\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-sunset.json" "$repo/app-themes/tilix-theme/sunset.json"
  assert_exists "$repo/app-themes/tilix-theme/sunset.json"
  run_setup "1\nvs code\n1\n1\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$repo/app-themes/vs-code-theme"
  run_setup "1\nobsidian\n1\n1\n$SANDBOX/Notes\ny\n1\n"
  assert_status 0
  assert_link "$SANDBOX/Notes/.obsidian/themes/Jenerated Blue Purple" "$repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --prep-commit
# THEN it exits with status 1, saying it needs Python, and changes nothing
test_prep_commit_needs_python() {
  sandbox_jenerate sunset
  cp "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/before.json"
  fake_no_python
  run_setup "" --prep-commit
  assert_status 1
  assert_contains "--prep-commit needs Python 3.11 or later"
  assert_same_file "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/before.json"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --update-screenshots
# THEN it exits with status 1, saying it needs Python
test_update_screenshots_needs_python() {
  fake_no_python
  run_setup "" --update-screenshots
  assert_status 1
  assert_contains "--update-screenshots needs Python 3.11 or later"
}

# GIVEN no Python 3.11 or later
# WHEN running setup.sh --version
# THEN it still prints the version, the same as jenerate --version gives
test_version_works_without_python() {
  version="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$SANDBOX/repo/jenerate_themes/__init__.py")"
  fake_no_python
  run_setup "" --version
  assert_status 0
  [ "$OUTPUT" = "jenerate-themes $version" ] || fail "expected 'jenerate-themes $version', got '$OUTPUT'"
}

# GIVEN a Linux system with no clipboard tool
# WHEN choosing Slack and Blue Purple
# THEN the theme string is printed, without claiming it was copied
test_slack_without_a_clipboard_tool_still_prints_the_string() {
  fake_os Linux
  rm -f "$SANDBOX"/bin/pbcopy "$SANDBOX"/bin/wl-copy "$SANDBOX"/bin/xclip "$SANDBOX"/bin/xsel
  # Hide any real clipboard tools by giving setup.sh a PATH without them.
  mkdir -p "$SANDBOX/minbin"
  for tool in bash sh sed head tr grep readlink rm ln mkdir mv cat dirname basename uname awk sort cut; do
    [ -e "$SANDBOX/bin/$tool" ] && continue
    ln -s "$(command -v "$tool")" "$SANDBOX/minbin/$tool"
  done
  fake_no_python
  OUTPUT="$(printf 'y\n' |
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$SANDBOX/minbin" WAYLAND_DISPLAY= \
      "$SANDBOX/minbin/bash" "$SANDBOX/repo/setup.sh" --install=slack 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
  assert_not_contains "Copied to your clipboard"
}

# --- Tests: its options: --help, and handing over --update-screenshots -------

# GIVEN Python but no Node.js
# WHEN running setup.sh --update-screenshots
# THEN it exits with status 1, saying it needs Node.js and npm, without
#      changing any screenshot
test_update_screenshots_needs_node() {
  local python
  python="$(find_python)"
  mkdir -p "$SANDBOX/minbin"
  for tool in bash dirname uname "$python"; do
    ln -s "$(command -v "$tool")" "$SANDBOX/minbin/$tool"
  done
  cp "$SANDBOX/repo/palettes/Screenshots/Dark/blue-purple.png" "$SANDBOX/before.png"
  OUTPUT="$(cd "$SANDBOX" && HOME="$SANDBOX/home" PATH="$SANDBOX/minbin" XDG_CACHE_HOME= \
    "$SANDBOX/minbin/bash" "$SANDBOX/repo/setup.sh" --update-screenshots 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "--update-screenshots needs Node.js and npm (for Playwright)"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/Dark/blue-purple.png" "$SANDBOX/before.png"
}

# GIVEN fake node and npm (node writes a placeholder screenshot per palette)
# WHEN running setup.sh --update-screenshots
# THEN it runs the screenshot script: every palette gets a new screenshot,
#      and the README is checked
test_update_screenshots_runs_the_screenshot_script() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\""
  fake_command node "out=\"\$3\"; shift 3
for f in \"\$@\"; do printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
  run_setup "" --update-screenshots
  assert_status 0
  assert_contains "Updating the palette screenshots"
  for file in "$SANDBOX"/repo/palettes/{Dark,Light}/*-palette.toml; do
    [ -f "$file" ] || continue
    folder="$(basename "$(dirname "$file")")"
    assert_file_equals "$SANDBOX/repo/palettes/Screenshots/$folder/$(basename "$file" -palette.toml).png" "new png"
  done
  assert_contains "palettes/README.md"
  assert_not_contains "Which app"
}

# GIVEN fake node and npm (node records the palettes it's asked for)
# WHEN running setup.sh --update-screenshots=sunset, and again with the
#      singular --update-screenshot=sunset,blue-purple
# THEN each runs the screenshot script for just the palettes named
test_update_screenshots_for_named_palettes() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\""
  fake_command node "out=\"\$3\"; shift 3
printf '%s\n' \"\$@\" >\"$SANDBOX/node-palettes\"
for f in \"\$@\"; do printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
  run_setup "" --update-screenshots=sunset
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "Dark/sunset-palette.toml"
  run_setup "" --update-screenshot=sunset,blue-purple
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "$(printf 'Dark/sunset-palette.toml\nDark/blue-purple-palette.toml')"
  assert_not_contains "Which app"
}

# GIVEN setup.sh
# WHEN running it with --update-screenshots= and no palette after the =
# THEN it stops, saying how to name one
test_update_screenshots_with_an_empty_list_is_an_error() {
  run_setup "" --update-screenshots=
  assert_status 1
  assert_contains "name the palettes to screenshot, like --update-screenshots=candy"
}

# GIVEN an option setup.sh doesn't know
# WHEN running setup.sh with it
# THEN it exits with status 1, naming the option, without showing the menu
test_unknown_option_is_an_error() {
  run_setup "" --bogus
  assert_status 1
  assert_contains "unknown option: --bogus (./setup.sh --help lists the options)"
  assert_not_contains "Which app"
}

# GIVEN setup.sh
# WHEN running it with --help, or -h
# THEN it lists every option, the maintainers' ones included, and exits
#      without showing the menu
test_help_lists_the_options() {
  for option in --help -h; do
    run_setup "" "$option"
    assert_status 0
    assert_contains "Usage: ./setup.sh [option]"
    assert_contains "-h, --help"
    assert_contains "--prep-commit"
    assert_contains "--update-screenshots "
    assert_contains "--update-screenshots=SLUGS"
    assert_not_contains "What would you like to do?"
  done
}

# GIVEN setup.sh
# WHEN reading its option handling
# THEN every option it accepts is in --help (so a new option isn't left out)
test_help_covers_every_option() {
  run_setup "" --help
  for option in $(sed -n '/^case "\${1:-}" in$/,/^esac$/p' "$SANDBOX/repo/setup.sh" |
    grep -o -- '--[a-z-]*' | sort -u); do
    case "$option" in
      --update-screenshot) continue ;; # the singular, accepted as a typo
    esac
    assert_contains "$option"
  done
}

run_tests
