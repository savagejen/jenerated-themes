#!/usr/bin/env bash
# Tests for maintainer-tools/prep-commit.py, run as ./setup.sh --prep-commit
# (as CONTRIBUTING.md says to).
#
# Usage: tests/maintainer-tools/test-prep-commit.sh [part of a test's name]
#
# Each test runs from a throwaway copy of the repository, with HOME pointed
# at an empty folder, so nothing outside the sandbox is touched.

source "$(dirname "$0")/../lib.sh"

after_sandbox() {
  quiet_desktop
}

# sandbox_jenerate args... -> runs the sandbox repository's jenerate.py.
sandbox_jenerate() {
  (cd "$SANDBOX/repo" && "$(find_python)" jenerate.py "$@" >/dev/null 2>&1)
}

# --- Tests: preparing a commit ----------------------------------------------

# The generated files git tracks: Blue Purple's defaults.
BLUE_PURPLE_FILES="app-themes/vs-code-theme/themes/jenerated-blue-purple-color-theme.json
app-themes/ptyxis-theme/blue-purple.palette
app-themes/slack-theme/blue-purple.txt
app-themes/obsidian-theme/blue-purple/theme.css
app-themes/obsidian-theme/blue-purple/manifest.json
app-themes/tilix-theme/blue-purple.json"

# Fails unless package.json matches the one git has (staged, or else
# committed).
assert_package_json_is_committed() {
  git -C "$REPO" show :app-themes/vs-code-theme/package.json >"$SANDBOX/committed-package.json"
  assert_same_file "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "$SANDBOX/committed-package.json"
}

# GIVEN Sunset has been generated, so package.json lists it
# WHEN running setup.sh --prep-commit
# THEN package.json matches the committed one again, Sunset's files are kept,
#      and it says how to list Sunset in VS Code again
test_prep_commit_resets_package_json() {
  sandbox_jenerate sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_package_json_is_committed
  assert_exists "$SANDBOX/repo/app-themes/tilix-theme/sunset.json"
  assert_contains "./jenerate.py sunset"
}

# GIVEN Blue Purple's generated files have been removed
# WHEN running setup.sh --prep-commit
# THEN every Blue Purple file is back, matching what's committed
test_prep_commit_restores_removed_blue_purple_files() {
  sandbox_jenerate --remove blue-purple
  run_setup "" --prep-commit
  assert_status 0
  for rel in $BLUE_PURPLE_FILES; do
    assert_same_file "$SANDBOX/repo/$rel" "$REPO/$rel"
  done
  assert_package_json_is_committed
}

# GIVEN nothing but Blue Purple is generated
# WHEN running setup.sh --prep-commit
# THEN it succeeds, package.json is unchanged, and there's no hint about
#      other themes
test_prep_commit_on_a_clean_repository() {
  run_setup "" --prep-commit
  assert_status 0
  assert_package_json_is_committed
  assert_not_contains "Your other themes"
}

# GIVEN Sunset and a Forest palette have both been generated
# WHEN running setup.sh --prep-commit
# THEN the hint lists both, ready to paste into jenerate.py
test_prep_commit_lists_every_other_generated_theme() {
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^short_name = .*/short_name = "forest"/' \
    "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  sandbox_jenerate forest,sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_contains "./jenerate.py forest,sunset"
}

# GIVEN package.json.tmpl has been changed (a new version), and Sunset is
#       generated
# WHEN running setup.sh --prep-commit
# THEN package.json keeps the change but lists only Blue Purple
test_prep_commit_keeps_package_json_template_changes() {
  sed 's/"version": "1.0.0"/"version": "1.1.0"/' \
    "$SANDBOX/repo/app-themes/vs-code-theme/package.json.tmpl" >"$SANDBOX/package.json.tmpl"
  cp "$SANDBOX/package.json.tmpl" "$SANDBOX/repo/app-themes/vs-code-theme/package.json.tmpl"
  sandbox_jenerate sunset
  run_setup "" --prep-commit
  assert_status 0
  assert_file_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" '"version": "1.1.0"'
  assert_file_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" '"label": "Jenerated Blue Purple"'
  assert_file_not_contains "$SANDBOX/repo/app-themes/vs-code-theme/package.json" "Sunset"
}

# GIVEN a template has been changed
# WHEN running setup.sh --prep-commit
# THEN Blue Purple's generated file picks up the change, ready to commit
test_prep_commit_regenerates_blue_purple_from_changed_templates() {
  printf '{{accent}}|{{name}}\n' >"$SANDBOX/repo/app-themes/slack-theme/slack-theme.txt.tmpl"
  run_setup "" --prep-commit
  assert_status 0
  assert_file_equals "$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt" "#5865F3|Blue Purple"
}

EXAMPLE_ZIP="app-themes/vivaldi-theme/jenerated-blue-purple.zip"
EXAMPLE_JAR="app-themes/jetbrains-theme/jenerated-blue-purple.jar"

# package_matches_folder package folder -> fails unless the package holds
# exactly the folder's files, with the same contents.
package_matches_folder() {
  "$(find_python)" -c '
import os, sys, zipfile
package, folder = sys.argv[1:]
z = zipfile.ZipFile(package)
files = {os.path.relpath(os.path.join(d, n), folder): open(os.path.join(d, n), "rb").read()
         for d, _, names in os.walk(folder) for n in names}
sys.exit(0 if {i: z.read(i) for i in z.namelist()} == files else 1)
' "$1" "$2" || fail "expected $1 to hold exactly the files in $2"
}

# GIVEN the Vivaldi and JetBrains templates have changed
# WHEN running setup.sh --prep-commit
# THEN the example packages are rebuilt from Blue Purple's regenerated files
test_prep_commit_rebuilds_the_example_packages() {
  sed 's/"radius": 6/"radius": 9/' "$SANDBOX/repo/app-themes/vivaldi-theme/settings.json.tmpl" >"$SANDBOX/vivaldi.tmpl"
  cp "$SANDBOX/vivaldi.tmpl" "$SANDBOX/repo/app-themes/vivaldi-theme/settings.json.tmpl"
  # Blue Purple is dark, so its JetBrains theme comes from the dark template.
  sed 's/"author": "Jenerated Themes"/"author": "Someone Else"/' "$SANDBOX/repo/app-themes/jetbrains-theme/theme-dark.json.tmpl" >"$SANDBOX/theme.tmpl"
  cp "$SANDBOX/theme.tmpl" "$SANDBOX/repo/app-themes/jetbrains-theme/theme-dark.json.tmpl"
  run_setup "" --prep-commit
  assert_status 0
  assert_contains "Rebuilt $EXAMPLE_ZIP"
  assert_contains "Rebuilt $EXAMPLE_JAR"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/app-themes/vivaldi-theme/blue-purple"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_JAR" "$SANDBOX/repo/app-themes/jetbrains-theme/blue-purple"
  unzip_text="$("$(find_python)" -c 'import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read("settings.json").decode())' "$SANDBOX/repo/$EXAMPLE_ZIP")"
  case "$unzip_text" in
    *'"radius": 9'*) ;;
    *) fail "expected the rebuilt Vivaldi example to have the template's change" ;;
  esac
  unzip_text="$("$(find_python)" -c 'import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read("jenerated-blue-purple.theme.json").decode())' "$SANDBOX/repo/$EXAMPLE_JAR")"
  case "$unzip_text" in
    *'"author": "Someone Else"'*) ;;
    *) fail "expected the rebuilt JetBrains example to have the template's change" ;;
  esac
}

# GIVEN the example packages have been deleted
# WHEN running setup.sh --prep-commit
# THEN they're made again
test_prep_commit_restores_deleted_example_packages() {
  rm -f "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/$EXAMPLE_JAR"
  run_setup "" --prep-commit
  assert_status 0
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_ZIP" "$SANDBOX/repo/app-themes/vivaldi-theme/blue-purple"
  package_matches_folder "$SANDBOX/repo/$EXAMPLE_JAR" "$SANDBOX/repo/app-themes/jetbrains-theme/blue-purple"
}

# GIVEN the repository's example packages
# WHEN running setup.sh --prep-commit, twice
# THEN the packages are byte for byte the same as the repository's each time,
#      so git only sees them change when their contents do
test_prep_commit_example_packages_are_reproducible() {
  run_setup "" --prep-commit
  assert_same_file "$SANDBOX/repo/$EXAMPLE_ZIP" "$REPO/$EXAMPLE_ZIP"
  assert_same_file "$SANDBOX/repo/$EXAMPLE_JAR" "$REPO/$EXAMPLE_JAR"
  run_setup "" --prep-commit
  assert_same_file "$SANDBOX/repo/$EXAMPLE_ZIP" "$REPO/$EXAMPLE_ZIP"
  assert_same_file "$SANDBOX/repo/$EXAMPLE_JAR" "$REPO/$EXAMPLE_JAR"
}

run_tests
