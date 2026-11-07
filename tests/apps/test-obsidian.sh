#!/usr/bin/env bash
# Tests for Obsidian: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-obsidian.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

obsidian_theme() { printf '%s' "$SANDBOX/repo/app-themes/obsidian-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian manifest is valid JSON naming the theme Jenerated Sunset
test_obsidian_manifest_names_the_theme() {
  generate sunset
  assert_valid_json "$(obsidian_theme sunset)/manifest.json"
  assert_file_contains "$(obsidian_theme sunset)/manifest.json" '"name": "Jenerated Sunset"'
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian CSS has Sunset's accent (as hex and HSL), red as RGB and
#      background
test_obsidian_css_uses_the_palette() {
  generate sunset
  css="$(obsidian_theme sunset)/theme.css"
  IFS='|' read -r h s l <<<"$(color_hsl accent)"
  assert_file_contains "$css" "--color-accent: $(color accent);"
  assert_file_contains "$css" "--accent-h: $h;"
  assert_file_contains "$css" "--accent-s: $s%;"
  assert_file_contains "$css" "--accent-l: $l%;"
  assert_file_contains "$css" "--color-red-rgb: $(color_rgb red);"
  assert_file_contains "$css" "--background-primary: $(color bg);"
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Obsidian CSS has as many { as }
test_obsidian_css_braces_balance() {
  generate sunset
  css="$(obsidian_theme sunset)/theme.css"
  open="$(tr -cd '{' <"$css" | wc -c | tr -d ' ')"
  close="$(tr -cd '}' <"$css" | wc -c | tr -d ' ')"
  [ "$open" = "$close" ] || fail "expected balanced braces, got $open { and $close }"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Obsidian folder is deleted and the templates are kept
test_remove_deletes_the_obsidian_folder() {
  generate sunset
  remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/obsidian-theme/theme.css.tmpl"
}

# GIVEN Sunset has been generated and someone added a file to its Obsidian
#       folder
# WHEN removing Sunset
# THEN the generated files are deleted but the folder and the added file stay
test_remove_keeps_a_folder_with_other_files() {
  generate sunset
  echo mine >"$(obsidian_theme sunset)/notes.txt"
  remove sunset
  assert_status 0
  assert_missing "$(obsidian_theme sunset)/theme.css"
  assert_exists "$(obsidian_theme sunset)/notes.txt"
}

# --- Tests: installing -------------------------------------------------------

# make_vault path -> creates an Obsidian vault folder (with .obsidian inside).
make_vault() {
  mkdir -p "$1/.obsidian"
}

# know_vaults config vault... -> writes an Obsidian vault list (obsidian.json)
# at $SANDBOX/home/<config> listing the vaults.
know_vaults() {
  local config="$SANDBOX/home/$1" entries="" i=0
  shift
  for vault in "$@"; do
    i=$((i + 1))
    entries="$entries${entries:+,}\"id$i\":{\"path\":\"$vault\",\"ts\":1,\"open\":true}"
  done
  mkdir -p "$(dirname "$config")"
  printf '{"vaults":{%s}}' "$entries" >"$config"
}

LINUX_CONFIG=".config/obsidian/obsidian.json"

# vault_theme vault name -> where a palette's theme goes in a vault.
vault_theme() {
  printf '%s' "$1/.obsidian/themes/Jenerated $2"
}

# GIVEN one vault in Obsidian's vault list
# WHEN choosing Obsidian, Blue Purple and that vault
# THEN the vault and 'Another folder' are offered, the theme is linked into the
#      vault, and it says which theme to choose
test_obsidian_links_the_theme_into_a_known_vault() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
  assert_contains "2) Another folder (type its path)"
  assert_link "$(vault_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
  assert_contains 'choose "Jenerated Blue Purple"'
}

# GIVEN a known vault
# WHEN choosing Obsidian and Sunset
# THEN the theme's folder name matches the name in its manifest.json
test_obsidian_theme_folder_matches_its_manifest() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  install_app obsidian sunset "1\ny\n1\n"
  assert_status 0
  assert_file_contains "$(vault_theme "$SANDBOX/Notes" "Sunset")/manifest.json" \
    '"name": "Jenerated Sunset"'
  assert_exists "$(vault_theme "$SANDBOX/Notes" "Sunset")/theme.css"
}

# GIVEN three vaults in Obsidian's vault list, one of which no longer exists
# WHEN choosing Obsidian
# THEN only the two that exist are offered, followed by 'Another folder'
test_obsidian_lists_every_known_vault_that_exists() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/My Work"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes" "$SANDBOX/Gone" "$SANDBOX/My Work"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_contains ") $SANDBOX/Notes"
  assert_contains ") $SANDBOX/My Work"
  assert_not_contains "$SANDBOX/Gone"
  assert_contains "3) Another folder (type its path)"
}

# GIVEN a known vault with a space in its path
# WHEN choosing it
# THEN the theme is linked into it
test_obsidian_vault_with_spaces_in_its_path() {
  make_vault "$SANDBOX/My Work"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/My Work"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_status 0
  assert_link "$(vault_theme "$SANDBOX/My Work" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a Mac with Obsidian's vault list in ~/Library/Application Support
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_on_macos() {
  fake_os Darwin
  make_vault "$SANDBOX/Notes"
  know_vaults "Library/Application Support/obsidian/obsidian.json" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_status 0
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN Obsidian installed through Flatpak, with its vault list in the
#       folder Flatpak gives it
# WHEN choosing Obsidian
# THEN the vault is offered
test_obsidian_finds_vaults_from_flatpak() {
  make_vault "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_contains "1) $SANDBOX/Notes"
}

# GIVEN the same vault in two of Obsidian's vault lists
# WHEN choosing Obsidian
# THEN it's offered once
test_obsidian_lists_a_vault_known_twice_once() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  know_vaults ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_contains "2) Another folder"
}

# GIVEN no Obsidian vault list
# WHEN choosing Obsidian and typing a vault's path with a trailing slash
# THEN it asks for the path directly and links the theme into that vault
test_obsidian_asks_for_a_path_when_no_vaults_are_known() {
  make_vault "$SANDBOX/Notes"
  install_app obsidian blue-purple "$SANDBOX/Notes/\ny\n1\n"
  assert_status 0
  assert_contains "Path to your vault folder:"
  assert_not_contains "Another folder"
  assert_link "$(vault_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a known vault, and another vault in the home folder
# WHEN choosing 'Another folder' and typing ~/Vault
# THEN ~ is expanded and the theme is linked into that vault
test_obsidian_another_folder_expands_the_home_folder() {
  make_vault "$SANDBOX/Notes"
  make_vault "$SANDBOX/home/Vault"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  install_app obsidian blue-purple "2\n~/Vault\ny\n1\n"
  assert_status 0
  assert_link "$(vault_theme "$SANDBOX/home/Vault" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN a vault called Notes in the folder jenerate is run from
# WHEN typing the relative path Notes
# THEN the theme is linked into that vault, not looked for in the repository
test_obsidian_relative_path_is_relative_to_where_it_ran() {
  mkdir -p "$SANDBOX/work/Notes/.obsidian"
  RUN_FROM="$SANDBOX/work"
  install_app obsidian blue-purple "Notes\ny\n1\n"
  assert_status 0
  assert_link "$(vault_theme "$SANDBOX/work/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN no Obsidian vault list
# WHEN pressing Enter without typing a path
# THEN it exits with status 1, saying no vault was given
test_obsidian_empty_path_is_an_error() {
  install_app obsidian blue-purple "\n"
  assert_status 1
  assert_contains "no vault given"
}

# GIVEN no Obsidian vault list
# WHEN typing the path of a folder that doesn't exist
# THEN it exits with status 1, saying there's no folder there
test_obsidian_missing_folder_is_an_error() {
  install_app obsidian blue-purple "$SANDBOX/Nowhere\n"
  assert_status 1
  assert_contains "there's no folder at $SANDBOX/Nowhere"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering no
# THEN it exits with status 1 without creating anything in the folder
test_obsidian_asks_before_using_a_folder_that_isnt_a_vault() {
  mkdir -p "$SANDBOX/Plain"
  install_app obsidian blue-purple "$SANDBOX/Plain\nn\n"
  assert_status 1
  assert_contains "has no .obsidian folder"
  assert_missing "$SANDBOX/Plain/.obsidian"
}

# GIVEN a folder with no .obsidian folder in it
# WHEN typing its path and answering yes
# THEN the theme is linked into it
test_obsidian_uses_a_folder_that_isnt_a_vault_when_told_to() {
  mkdir -p "$SANDBOX/Plain"
  install_app obsidian blue-purple "$SANDBOX/Plain\ny\ny\n1\n"
  assert_status 0
  assert_link "$(vault_theme "$SANDBOX/Plain" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

# GIVEN the theme is already linked into a vault
# WHEN choosing the same vault again
# THEN it says it's already installed
test_obsidian_already_linked_is_left_alone() {
  make_vault "$SANDBOX/Notes"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\n"
  install_app obsidian blue-purple "1\ny\n1\n"
  assert_status 0
  assert_contains "Already installed"
}

# GIVEN an old copy of the theme in a vault
# WHEN choosing that vault and answering yes to replacing it
# THEN the copy is replaced with a link
test_obsidian_replaces_an_old_copy_when_asked() {
  make_vault "$SANDBOX/Notes"
  mkdir -p "$(vault_theme "$SANDBOX/Notes" "Blue Purple")"
  know_vaults "$LINUX_CONFIG" "$SANDBOX/Notes"
  install_app obsidian blue-purple "1\ny\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$(vault_theme "$SANDBOX/Notes" "Blue Purple")" "$SANDBOX/repo/app-themes/obsidian-theme/blue-purple"
}

run_tests
