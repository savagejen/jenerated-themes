#!/usr/bin/env bash
# Tests for palette-creator/screenshots.py.
#
# Usage: tests/screenshots/test_screenshots.sh
#
# Each test runs screenshots.py from a throwaway copy of the repository, with
# HOME pointed at an empty folder. The README update is tested directly
# (--readme-only). A full run uses fake node and npm commands, so no browser
# or network is needed: the fake node checks the Palette Creator is running,
# then writes placeholder screenshots. Needs Python 3.11 or later and curl.

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ] || ! command -v curl >/dev/null 2>&1; then
  printf 'skipped: the screenshot tests need Python 3.11 or later and curl\n'
  exit 0
fi

README_REL="palettes/README.md"

# run_screenshots [options...] -> runs screenshots.py in the sandbox, and sets
# OUTPUT and STATUS.
run_screenshots() {
  OUTPUT="$(cd "$SANDBOX/repo" && HOME="$SANDBOX/home" XDG_CACHE_HOME= \
    PATH="$SANDBOX/bin:$PATH" "$PYTHON" palette-creator/screenshots.py "$@" 2>&1)"
  STATUS=$?
}

# add_palette slug name [screenshot] -> adds a palette copied from Sunset,
# described as "The <name> palette, for testing.", and with "screenshot", a
# placeholder screenshot of it. Both are put straight in palettes/ and
# palettes/Screenshots, not filed yet.
add_palette() {
  {
    printf '# The %s palette, for testing.\n' "$2"
    # Sunset's file from the end of its description on.
    sed -n '/^#$/,$p' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml"
  } | sed -e "s/^name = .*/name = \"$2\"/" -e "s/^slug = .*/slug = \"$1\"/" \
    >"$SANDBOX/repo/palettes/$1-palette.toml"
  [ "${3:-}" = "screenshot" ] && printf 'png' >"$SANDBOX/repo/palettes/Screenshots/$1.png"
  return 0
}

# fake_playwright -> fakes npm (it "installs" Playwright into the prefix it's
# given) and node (it records its arguments, checks the Palette Creator
# answers at the address it's given, and writes a placeholder screenshot for
# each palette).
fake_playwright() {
  fake_command npm "prefix=''
while [ \$# -gt 0 ]; do [ \"\$1\" = --prefix ] && prefix=\"\$2\"; shift; done
mkdir -p \"\$prefix/node_modules/playwright\" \"\$prefix/node_modules/.bin\"
printf '#!/bin/sh\nexit 0\n' >\"\$prefix/node_modules/.bin/playwright\"
chmod +x \"\$prefix/node_modules/.bin/playwright\"
touch \"$SANDBOX/npm-ran\""
  fake_command node "base=\"\$2\"; out=\"\$3\"; shift 3
curl -s \"\$base/api/palette\" >\"$SANDBOX/node-saw\" || exit 1
printf '%s\n' \"\$@\" >\"$SANDBOX/node-palettes\"
for f in \"\$@\"; do f=\"\${f##*/}\"; printf 'new png' >\"\$out/\${f%-palette.toml}.png\"; done"
}

# --- Tests: updating the README ----------------------------------------------

# GIVEN the repository's README and screenshots
# WHEN updating the README
# THEN nothing changes, and it says the README is up to date
test_readme_already_up_to_date() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "palettes/README.md is up to date"
  assert_same_file "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
}

# GIVEN a new dark Forest palette with a screenshot, neither filed yet
# WHEN updating the README
# THEN both are filed under Dark, and a section for Forest is added at the
#      end of the dark group, with its name, slug, description, screenshot and
#      key colors; nothing else in the README changes
test_readme_adds_a_section_for_a_new_palette() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  add_palette forest Forest screenshot
  run_screenshots --readme-only
  assert_status 0
  # Forest is a copy of Sunset, so it has Sunset's key colors.
  assert_contains "Moved palettes/forest-palette.toml to palettes/Dark/"
  assert_contains "Moved palettes/Screenshots/forest.png to palettes/Screenshots/Dark/"
  assert_contains "Updated palettes/README.md (added forest)"
  assert_exists "$SANDBOX/repo/palettes/Dark/forest-palette.toml"
  assert_exists "$SANDBOX/repo/palettes/Screenshots/Dark/forest.png"
  expected="### Forest

\`forest\`

The Forest palette, for testing.

![The Forest palette in the Palette Creator's preview](Screenshots/Dark/forest.png)

$(sed -n '/^### Sunset$/,$p' "$SANDBOX/repo/$README_REL" | grep -m1 '^Editor ')

</details>"
  actual="$(sed -n '/^### Forest$/,/^<\/details>$/p' "$SANDBOX/repo/$README_REL")"
  [ "$actual" = "$expected" ] || fail "unexpected Forest section:
$actual"
  [ "$(diff "$SANDBOX/before.md" "$SANDBOX/repo/$README_REL" | grep -c '^<')" = "0" ] ||
    fail "expected the rest of the README to be unchanged"
  [ "$(awk '/Dark palettes/{g="dark"} /Light palettes/{g="light"} /^### Forest$/{print g}' \
    "$SANDBOX/repo/$README_REL")" = "dark" ] || fail "expected Forest in the dark group"
}

# GIVEN a new light palette, Meringue (a copy of Candy), with a screenshot,
#       neither filed yet
# WHEN updating the README
# THEN both are filed under Light, and its section is added at the end of
#      the light group, after Candy
test_readme_adds_a_light_palette_to_the_light_group() {
  sed -e 's/^name = .*/name = "Meringue"/' -e 's/^slug = .*/slug = "meringue"/' \
    "$SANDBOX/repo/palettes/Light/candy-palette.toml" >"$SANDBOX/repo/palettes/meringue-palette.toml"
  printf 'png' >"$SANDBOX/repo/palettes/Screenshots/meringue.png"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "Updated palettes/README.md (added meringue)"
  assert_exists "$SANDBOX/repo/palettes/Light/meringue-palette.toml"
  assert_exists "$SANDBOX/repo/palettes/Screenshots/Light/meringue.png"
  assert_file_contains "$SANDBOX/repo/$README_REL" "](Screenshots/Light/meringue.png)"
  [ "$(awk '/Dark palettes/{g="dark"} /Light palettes/{g="light"} /^### /{last=g ": " $0} /^<\/details>$/ && g=="light"{print last}' \
    "$SANDBOX/repo/$README_REL")" = "light: ### Meringue" ] || fail "expected Meringue last in the light group"
}

# GIVEN a light palette filed in palettes/Dark, with its screenshot in
#       Screenshots/Dark and its README section in the dark group
# WHEN updating the README
# THEN the palette and screenshot move to the Light folders, and its section
#      moves to the light group, pointing at the moved screenshot
test_readme_files_a_palette_by_its_scheme() {
  add_palette dawn Dawn screenshot
  run_screenshots --readme-only
  sed -i 's/^scheme = .*//; s/^slug = "dawn"/&\nscheme = "light"/' "$SANDBOX/repo/palettes/Dark/dawn-palette.toml"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "Moved palettes/Dark/dawn-palette.toml to palettes/Light/"
  assert_contains "Moved palettes/Screenshots/Dark/dawn.png to palettes/Screenshots/Light/"
  assert_exists "$SANDBOX/repo/palettes/Light/dawn-palette.toml"
  assert_missing "$SANDBOX/repo/palettes/Dark/dawn-palette.toml"
  assert_exists "$SANDBOX/repo/palettes/Screenshots/Light/dawn.png"
  assert_file_contains "$SANDBOX/repo/$README_REL" "](Screenshots/Light/dawn.png)"
  [ "$(awk '/Dark palettes/{g="dark"} /Light palettes/{g="light"} /^### Dawn$/{print g}' \
    "$SANDBOX/repo/$README_REL")" = "light" ] || fail "expected Dawn in the light group"
}

# GIVEN the same slug in palettes/Dark and palettes/Light
# WHEN updating the README
# THEN it stops, naming both, and moves nothing
test_same_slug_twice_stops() {
  cp "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" "$SANDBOX/repo/palettes/Light/sunset-palette.toml"
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  run_screenshots --readme-only
  assert_status 1
  assert_contains "The palette 'sunset' is in more than one place: palettes/Dark/sunset-palette.toml, palettes/Light/sunset-palette.toml. Keep one of them."
  assert_same_file "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
}

# GIVEN a README from before the dark and light groups: ## sections, with
#       screenshots straight in Screenshots/
# WHEN updating it
# THEN each section moves into its group as a ### section, pointing at its
#      filed screenshot, and the intro stays first
test_readme_from_before_the_groups_is_converted() {
  printf '# Palettes\n\nIntro.\n\n## Candy\n\n`candy`\n\n![Candy](Screenshots/candy.png)\n\n## Sunset\n\n`sunset`\n\n![Sunset](Screenshots/sunset.png)\n' \
    >"$SANDBOX/repo/$README_REL"
  run_screenshots --readme-only
  assert_status 0
  assert_file_contains "$SANDBOX/repo/$README_REL" "# Palettes

Intro.

<details open>
<summary><h2>Dark palettes</h2></summary>

### Sunset

\`sunset\`

![Sunset](Screenshots/Dark/sunset.png)"
  assert_file_contains "$SANDBOX/repo/$README_REL" "<details open>
<summary><h2>Light palettes</h2></summary>

### Candy

\`candy\`

![Candy](Screenshots/Light/candy.png)"
  grep -qx '## Candy' "$SANDBOX/repo/$README_REL" && fail "expected no ## Candy heading left"
  return 0
}

# GIVEN a new palette without a screenshot
# WHEN updating the README
# THEN no section is added, and it says why
test_readme_skips_a_palette_without_a_screenshot() {
  add_palette forest Forest
  run_screenshots --readme-only
  assert_status 0
  assert_contains "No screenshot of forest, so it isn't added to palettes/README.md"
  assert_file_not_contains "$SANDBOX/repo/$README_REL" "## Forest"
}

# GIVEN Sunset's accent has changed
# WHEN updating the README
# THEN only Sunset's key colors line changes, to the new accent
test_readme_refreshes_key_colors() {
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/before.md"
  sed 's/^accent = "#[0-9a-fA-F]*"/accent = "#123456"/' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" >"$SANDBOX/sunset.toml"
  cp "$SANDBOX/sunset.toml" "$SANDBOX/repo/palettes/Dark/sunset-palette.toml"
  run_screenshots --readme-only
  assert_status 0
  changed="$(diff "$SANDBOX/before.md" "$SANDBOX/repo/$README_REL" | grep '^>')"
  case "$changed" in
    "> Editor "*"Accent \`#123456\`"*) ;;
    *) fail "expected only Sunset's key colors to change, got: $changed" ;;
  esac
  [ "$(diff "$SANDBOX/before.md" "$SANDBOX/repo/$README_REL" | grep -c '^[<>]')" = "2" ] ||
    fail "expected exactly one line to change"
}

# GIVEN Aurora's palette has been deleted, but its README section and
#       screenshot remain
# WHEN updating the README
# THEN both are reported, and neither is removed
test_readme_reports_palettes_that_are_gone() {
  rm "$SANDBOX/repo/palettes/Dark/aurora-palette.toml"
  run_screenshots --readme-only
  assert_status 0
  assert_contains "palettes/README.md has a section for aurora, which isn't a palette any more"
  assert_contains "palettes/Screenshots/Dark/aurora.png is of aurora, which isn't a palette any more"
  assert_file_contains "$SANDBOX/repo/$README_REL" "## Aurora"
  assert_exists "$SANDBOX/repo/palettes/Screenshots/Dark/aurora.png"
}

# GIVEN an empty README
# WHEN updating it
# THEN it gets a heading and a section for every palette with a screenshot
test_readme_is_started_when_empty() {
  : >"$SANDBOX/repo/$README_REL"
  run_screenshots --readme-only
  assert_status 0
  assert_file_contains "$SANDBOX/repo/$README_REL" "# Palettes"
  for file in "$SANDBOX"/repo/palettes/{Dark,Light}/*-palette.toml; do
    folder="$(basename "$(dirname "$file")")"
    assert_file_contains "$SANDBOX/repo/$README_REL" "](Screenshots/$folder/$(basename "$file" -palette.toml).png)"
  done
}

# GIVEN a new palette with a screenshot
# WHEN updating the README twice
# THEN the second time changes nothing
test_readme_update_is_repeatable() {
  add_palette forest Forest screenshot
  run_screenshots --readme-only
  cp "$SANDBOX/repo/$README_REL" "$SANDBOX/after-first.md"
  run_screenshots --readme-only
  assert_contains "palettes/README.md is up to date"
  assert_same_file "$SANDBOX/repo/$README_REL" "$SANDBOX/after-first.md"
}

# --- Tests: taking screenshots -----------------------------------------------

# GIVEN a new Forest palette, and fake node and npm
# WHEN taking screenshots
# THEN Playwright is "installed" into ~/.cache, the Palette Creator is running
#      while node takes the screenshots, every palette gets one, Forest gets a
#      README section, and the repository's own draft is never created
test_full_run_takes_screenshots_and_updates_the_readme() {
  fake_playwright
  add_palette forest Forest
  run_screenshots
  assert_status 0
  assert_exists "$SANDBOX/npm-ran"
  assert_exists "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/playwright"
  assert_file_contains "$SANDBOX/node-saw" '"palette"'
  for file in "$SANDBOX"/repo/palettes/{Dark,Light}/*-palette.toml; do
    folder="$(basename "$(dirname "$file")")"
    assert_file_equals "$SANDBOX/repo/palettes/Screenshots/$folder/$(basename "$file" -palette.toml).png" "new png"
  done
  assert_exists "$SANDBOX/repo/palettes/Dark/forest-palette.toml"
  assert_file_equals "$SANDBOX/repo/palettes/Screenshots/Light/candy.png" "new png"
  assert_contains "Updated palettes/README.md (added forest)"
  assert_missing "$SANDBOX/repo/palette-creator/work-in-progress-palette.toml"
}

# GIVEN fake node and npm
# WHEN taking screenshots of just Sunset, by slug
# THEN only Sunset's screenshot is retaken, and the others are left alone
test_named_palette_gets_the_only_screenshot() {
  fake_playwright
  cp "$SANDBOX/repo/palettes/Screenshots/Dark/blue-purple.png" "$SANDBOX/before.png"
  run_screenshots sunset
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "Dark/sunset-palette.toml"
  assert_file_equals "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "new png"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/Dark/blue-purple.png" "$SANDBOX/before.png"
}

# GIVEN fake node and npm
# WHEN taking screenshots of "sunset,blue-purple", then of "sunset" and
#      "blue-purple" as separate arguments
# THEN both ways retake just those two, in the order given
test_several_named_palettes_get_screenshots() {
  fake_playwright
  expected="$(printf 'Dark/sunset-palette.toml\nDark/blue-purple-palette.toml')"
  run_screenshots sunset,blue-purple
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "$expected"
  run_screenshots sunset blue-purple
  assert_status 0
  assert_file_equals "$SANDBOX/node-palettes" "$expected"
}

# GIVEN fake node and npm
# WHEN taking screenshots of a palette that doesn't exist, alongside Sunset
# THEN it stops, naming the missing one and listing the palettes, before
#      installing anything or taking any screenshot
test_unknown_palette_is_named_and_nothing_is_taken() {
  fake_playwright
  cp "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "$SANDBOX/before.png"
  run_screenshots sunset,nope
  assert_status 1
  assert_contains "No palette in palettes/ called nope (the palettes are: "
  assert_contains "sunset"
  assert_missing "$SANDBOX/npm-ran"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "$SANDBOX/before.png"
}

# GIVEN the screenshot script
# WHEN asking for --readme-only along with a palette
# THEN it refuses, since the README update always covers every palette
test_readme_only_takes_no_palettes() {
  run_screenshots --readme-only sunset
  assert_status 2
  assert_contains "leave out the palette names"
}

# GIVEN Playwright already installed in ~/.cache
# WHEN taking screenshots
# THEN npm isn't run again
test_full_run_reuses_an_installed_playwright() {
  fake_playwright
  mkdir -p "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/playwright" \
    "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin"
  printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin/playwright"
  chmod +x "$SANDBOX/home/.cache/jenerated-themes/playwright/node_modules/.bin/playwright"
  run_screenshots
  assert_status 0
  assert_missing "$SANDBOX/npm-ran"
  assert_file_equals "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "new png"
}

# GIVEN no node or npm
# WHEN taking screenshots
# THEN it stops, saying they're needed, before changing anything
test_full_run_needs_node() {
  mkdir -p "$SANDBOX/minbin"
  ln -s "$(command -v "$PYTHON")" "$SANDBOX/minbin/$PYTHON"
  cp "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "$SANDBOX/before.png"
  OUTPUT="$(cd "$SANDBOX/repo" && HOME="$SANDBOX/home" XDG_CACHE_HOME= PATH="$SANDBOX/minbin" \
    "$SANDBOX/minbin/$PYTHON" palette-creator/screenshots.py 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "Updating screenshots needs Node.js and npm (for Playwright)"
  assert_same_file "$SANDBOX/repo/palettes/Screenshots/Dark/sunset.png" "$SANDBOX/before.png"
}

run_tests
