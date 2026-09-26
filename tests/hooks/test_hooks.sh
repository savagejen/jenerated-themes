#!/usr/bin/env bash
# Tests for the git hooks in .githooks/.
#
# Usage: tests/hooks/test_hooks.sh
#
# Each test runs the hook from a throwaway copy of the repository, so the
# palettes it adds never touch the real one.

source "$(dirname "$0")/../lib.sh"

# run_hook -> runs the pre-commit hook in the sandbox and sets OUTPUT and
# STATUS.
run_hook() {
  OUTPUT="$(sh "$SANDBOX/repo/.githooks/pre-commit" 2>&1)"
  STATUS=$?
}

# write_palette_with slug accent -> writes palettes/<slug>-palette.toml, a
# copy of Sunset with the given accent color.
write_palette_with() {
  sed -e "s|^slug = .*|slug = \"$1\"|" -e "s|^accent = \"#[0-9a-fA-F]*\"|accent = \"$2\"|" \
    "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" >"$SANDBOX/repo/palettes/$1-palette.toml"
}

# git_sandbox -> makes the sandbox repository a git repository with
# everything committed, so tests can stage changes for the hook to check.
git_sandbox() {
  git -C "$SANDBOX/repo" init -q
  git -C "$SANDBOX/repo" add -A
  git -C "$SANDBOX/repo" -c user.name=Test -c user.email=test@example.com commit -q -m base
}

# --- Tests: the colors to avoid ----------------------------------------------

# GIVEN the palettes in palettes/
# WHEN running the pre-commit hook
# THEN it allows the commit, since none of them uses a color to avoid
test_the_published_palettes_avoid_the_listed_colors() {
  run_hook
  assert_status 0
  [ -z "$OUTPUT" ] || fail "expected no output"
}

# GIVEN a palette whose accent is #0abab5, a listed color written in
#       lowercase
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file, line and color
test_a_listed_color_is_refused() {
  write_palette_with teal "#0abab5"
  line="$(grep -n '^accent = ' "$SANDBOX/repo/palettes/teal-palette.toml" | cut -d: -f1)"
  run_hook
  assert_status 1
  assert_contains "These palettes use colors listed in palettes/avoid-these.txt:"
  assert_contains "palettes/teal-palette.toml:$line  #0abab5"
}

# GIVEN a palette filed in palettes/Light whose accent is #0ABAB5
# WHEN running the pre-commit hook
# THEN it refuses the commit: filed palettes are checked too
test_a_listed_color_in_a_filed_palette_is_refused() {
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palettes/Light/teal-palette.toml"
  run_hook
  assert_status 1
  assert_contains "palettes/Light/teal-palette.toml:"
}

# GIVEN a palette whose accent is #0ABAB6, one digit off a listed color
# WHEN running the pre-commit hook
# THEN it allows the commit: only the exact codes are refused
test_a_nearby_shade_is_allowed() {
  write_palette_with teal "#0ABAB6"
  run_hook
  assert_status 0
}

# GIVEN a listed color outside palettes/, in the Palette Creator's draft
# WHEN running the pre-commit hook
# THEN it allows the commit: the hook only checks palettes/
test_colors_outside_palettes_are_not_checked() {
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palette-creator/work-in-progress-palette.toml"
  run_hook
  assert_status 0
}

# GIVEN palettes/avoid-these.txt
# WHEN reading each line
# THEN every line is blank, a comment ("# ...") or a #rrggbb color, so a
#      mistyped color can't be silently skipped
test_every_line_of_the_list_is_a_color_or_a_comment() {
  OUTPUT="$(grep -n -v -E '^$|^#( .*)?$|^#[0-9A-Fa-f]{6}[[:space:]]*$' "$SANDBOX/repo/palettes/avoid-these.txt")"
  [ -z "$OUTPUT" ] || fail "expected only colors and comments, but these lines are neither"
}

# --- Tests: symbols stay ASCII -----------------------------------------------

# GIVEN a staged change adding a line with an ellipsis character (written
#       as its UTF-8 bytes) to setup.sh
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file and line
test_a_non_ascii_character_is_refused() {
  git_sandbox
  printf '# Wait\342\200\246\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  line="$(wc -l <"$SANDBOX/repo/setup.sh" | tr -d ' ')"
  run_hook
  assert_status 1
  assert_contains "These lines have forbidden symbols or emojis"
  assert_contains "  setup.sh:$line"
}

# GIVEN a staged palette named "Smorrebrod" with its Danish letters (o with
#       a stroke), a Japanese name, and French accents, written as UTF-8 bytes
# WHEN running the pre-commit hook
# THEN it allows the commit: letters in any language are fine
test_letters_in_any_language_are_allowed() {
  git_sandbox
  printf '# Sm\303\270rrebr\303\270d \346\241\234 Cr\303\250me br\303\273l\303\251e\n' \
    >>"$SANDBOX/repo/palettes/Dark/sunset-palette.toml"
  git -C "$SANDBOX/repo" add palettes/Dark/sunset-palette.toml
  run_hook
  assert_status 0
}

# GIVEN staged lines with a non-breaking space, a zero-width space, and a
#       byte that isn't valid UTF-8
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming each line
test_invisible_spaces_and_bad_bytes_are_refused() {
  git_sandbox
  printf 'a\302\240b\nc\342\200\213d\ne\377f\n' >"$SANDBOX/repo/notes.txt"
  git -C "$SANDBOX/repo" add notes.txt
  run_hook
  assert_status 1
  assert_contains "  notes.txt:1"
  assert_contains "  notes.txt:2"
  assert_contains "  notes.txt:3"
}

# GIVEN a staged file named smorrebrod.txt, with its Danish letters (git
#       quotes names like that by default), holding an em dash
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file as it is
test_a_file_with_letters_in_its_name_is_checked() {
  git_sandbox
  name="$(printf 'sm\303\270rrebr\303\270d.txt')"
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/$name"
  git -C "$SANDBOX/repo" add "$name"
  run_hook
  assert_status 1
  assert_contains "  $name:1"
}

# GIVEN an em dash in the working copy of README.md, but not in what's
#       staged
# WHEN running the pre-commit hook
# THEN it allows the commit: only what the commit will hold is checked
test_only_staged_content_is_checked() {
  git_sandbox
  printf 'a \342\200\224 b\n' >>"$SANDBOX/repo/README.md"
  run_hook
  assert_status 0
}

# GIVEN a staged binary file (a PNG, full of bytes above 0x7F)
# WHEN running the pre-commit hook
# THEN it allows the commit: binary files are skipped
test_binary_files_are_not_checked() {
  git_sandbox
  printf '\211PNG\r\n\032\n\000\000\377\376' >"$SANDBOX/repo/palettes/Screenshots/Dark/new.png"
  git -C "$SANDBOX/repo" add palettes/Screenshots/Dark/new.png
  run_hook
  assert_status 0
}

# GIVEN a staged palette with a listed color, and a staged non-ASCII line
# WHEN running the pre-commit hook
# THEN it refuses the commit, reporting both problems at once
test_both_problems_are_reported_together() {
  git_sandbox
  write_palette_with teal "#0abab5"
  printf '# \342\206\222\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml setup.sh
  run_hook
  assert_status 1
  assert_contains "These palettes use colors listed in palettes/avoid-these.txt:"
  assert_contains "These lines have forbidden symbols or emojis"
}

run_tests
