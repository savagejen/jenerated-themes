#!/usr/bin/env bash
# Tests for VS Code (and Code - OSS, VSCodium): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-vscode.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

# --- Tests: installing -------------------------------------------------------

# GIVEN Code - OSS (or VSCodium) has run, so ~/.vscode-oss exists, but VS
#       Code hasn't
# WHEN choosing VS Code and Blue Purple
# THEN the extension is linked into ~/.vscode-oss/extensions, and not into
#      ~/.vscode
test_vscode_links_the_extension_for_code_oss() {
  mkdir -p "$SANDBOX/home/.vscode-oss"
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode-oss/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_missing "$SANDBOX/home/.vscode"
  assert_not_contains "open it once first"
}

# GIVEN both VS Code and Code - OSS have run
# WHEN choosing VS Code and Blue Purple
# THEN the extension is linked into both extensions folders
test_vscode_links_the_extension_for_both() {
  mkdir -p "$SANDBOX/home/.vscode" "$SANDBOX/home/.vscode-oss"
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_link "$SANDBOX/home/.vscode-oss/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
}

# GIVEN a search for Code - OSS
# WHEN searching "code-oss" and "codium"
# THEN both find the VS Code entry
test_vscode_is_found_as_code_oss_and_codium() {
  run_setup "1\ncode - oss\n0\n0\n"
  assert_contains "1) VS Code (and Code - OSS, VSCodium)"
  run_setup "1\ncodium\n0\n0\n"
  assert_contains "1) VS Code (and Code - OSS, VSCodium)"
}

# GIVEN no VS Code extension installed
# WHEN choosing VS Code and Blue Purple
# THEN the extension folder is linked into ~/.vscode/extensions, and it says
#      which theme to choose
test_vscode_links_the_extension() {
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_contains 'Choose "Jenerated Blue Purple"'
}

# GIVEN the extension is already linked to this repository
# WHEN choosing VS Code again
# THEN it says it's already installed and doesn't offer to replace it
test_vscode_already_linked_is_left_alone() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  ln -s "$SANDBOX/repo/app-themes/vs-code-theme" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_not_contains "Replace it"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering yes to replacing it
# THEN the copy is replaced with a link
test_vscode_replaces_an_old_copy_when_asked() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  install_app vscode blue-purple "y\n1\ny\n"
  assert_status 0
  assert_contains "An older install exists"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
}

# GIVEN the extension linked to some other folder
# WHEN choosing VS Code and accepting the default answer
# THEN the link points at this repository, and the other folder is kept
test_vscode_replaces_a_link_to_another_folder() {
  mkdir -p "$SANDBOX/home/.vscode/extensions" "$SANDBOX/elsewhere"
  ln -s "$SANDBOX/elsewhere" "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  install_app vscode blue-purple "y\n1\n\n"
  assert_status 0
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_exists "$SANDBOX/elsewhere"
}

# GIVEN an old copy of the extension folder
# WHEN choosing VS Code and answering no to replacing it
# THEN it exits with status 1 and the copy is untouched
test_vscode_keeps_an_old_copy_when_declined() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/jenerated-themes"
  touch "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
  install_app vscode blue-purple "y\n1\nn\n"
  assert_status 1
  assert_contains "left the existing install alone"
  assert_exists "$SANDBOX/home/.vscode/extensions/jenerated-themes/keep-me"
}

# GIVEN a packaged (.vsix) copy of the extension is installed
# WHEN choosing VS Code
# THEN it warns about the packaged copy so the two don't clash
test_vscode_warns_about_a_packaged_copy() {
  mkdir -p "$SANDBOX/home/.vscode/extensions/local.jenerated-themes-1.0.0"
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_contains "you also have a packaged copy installed (local.jenerated-themes-1.0.0, in $SANDBOX/home/.vscode/extensions)"
}

# GIVEN VS Code's .obsolete file lists only this extension
# WHEN choosing VS Code and pressing Enter once VS Code is closed
# THEN the .obsolete file is deleted
test_vscode_removes_obsolete_file_with_only_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  install_app vscode blue-purple "y\n1\n\n"
  assert_status 0
  assert_contains "marked as uninstalled"
  assert_missing "$SANDBOX/home/.vscode/extensions/.obsolete"
}

# GIVEN VS Code's .obsolete file lists this extension between two others
# WHEN choosing VS Code and pressing Enter once VS Code is closed
# THEN only this extension's entry is removed
test_vscode_keeps_other_obsolete_entries() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true,"local.jenerated-themes-1.0.0":true,"b.second-2.0.0":true}' \
    >"$SANDBOX/home/.vscode/extensions/.obsolete"
  install_app vscode blue-purple "y\n1\n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" \
    '{"a.first-1.0.0":true,"b.second-2.0.0":true}'
}

# GIVEN VS Code's .obsolete file lists this extension
# WHEN choosing VS Code, but the input ends instead of pressing Enter
# THEN it stops without changing .obsolete, since VS Code may still be open
test_vscode_stops_if_input_ends_before_enter() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"local.jenerated-themes-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  install_app vscode blue-purple "y\n1\n"
  assert_status 1
  assert_contains "stopped before changing its files"
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" '{"local.jenerated-themes-1.0.0":true}'
}

# GIVEN VS Code's .obsolete file lists only another extension
# WHEN choosing VS Code
# THEN it doesn't mention it and the file is unchanged
test_vscode_ignores_obsolete_file_without_this_extension() {
  mkdir -p "$SANDBOX/home/.vscode/extensions"
  printf '{"a.first-1.0.0":true}' >"$SANDBOX/home/.vscode/extensions/.obsolete"
  install_app vscode blue-purple "y\n1\n"
  assert_status 0
  assert_not_contains "marked as uninstalled"
  assert_file_equals "$SANDBOX/home/.vscode/extensions/.obsolete" '{"a.first-1.0.0":true}'
}

run_tests
