#!/usr/bin/env bash
# Tests for the git hooks in .githooks/.
#
# Usage: tests/hooks/test-hooks.sh [part of a test's name]
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
  sed -e "s|^short_name = .*|short_name = \"$1\"|" -e "s|^accent = \"#[0-9a-fA-F]*\"|accent = \"$2\"|" \
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
  git_sandbox
  run_hook
  assert_status 0
  [ -z "$OUTPUT" ] || fail "expected no output"
}

# GIVEN a staged palette whose accent is #0abab5, a listed color written in
#       lowercase
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file, line and color
test_a_listed_color_is_refused() {
  git_sandbox
  write_palette_with teal "#0abab5"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml
  line="$(grep -n '^accent = ' "$SANDBOX/repo/palettes/teal-palette.toml" | cut -d: -f1)"
  run_hook
  assert_status 1
  assert_contains "These palettes use colors listed in palettes/avoid-these.txt:"
  assert_contains "palettes/teal-palette.toml:$line:#0abab5"
}

# GIVEN a staged palette filed in palettes/Light whose accent is #0ABAB5
# WHEN running the pre-commit hook
# THEN it refuses the commit: filed palettes are checked too
test_a_listed_color_in_a_filed_palette_is_refused() {
  git_sandbox
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palettes/Light/teal-palette.toml"
  git -C "$SANDBOX/repo" add palettes/Light/teal-palette.toml
  run_hook
  assert_status 1
  assert_contains "palettes/Light/teal-palette.toml:"
}

# GIVEN a staged palette whose accent is #0ABAB6, one digit off a listed
#       color
# WHEN running the pre-commit hook
# THEN it allows the commit: only the exact codes are refused
test_a_nearby_shade_is_allowed() {
  git_sandbox
  write_palette_with teal "#0ABAB6"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml
  run_hook
  assert_status 0
}

# GIVEN a listed color outside palettes/, staged in the Palette Creator's
#       draft
# WHEN running the pre-commit hook
# THEN it allows the commit: the hook only checks palettes/
test_colors_outside_palettes_are_not_checked() {
  git_sandbox
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palette-creator/work-in-progress-palette.toml"
  git -C "$SANDBOX/repo" add -f palette-creator/work-in-progress-palette.toml
  run_hook
  assert_status 0
}

# GIVEN a staged palette with a listed color, changed to a nearby shade in
#       the working copy but not staged again
# WHEN running the pre-commit hook
# THEN it refuses the commit: the staged palette, which the commit will
#      hold, still has the listed color
test_a_listed_color_fixed_only_in_the_working_copy_is_refused() {
  git_sandbox
  write_palette_with teal "#0ABAB5"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml
  write_palette_with teal "#0ABAB6"
  run_hook
  assert_status 1
  assert_contains "palettes/teal-palette.toml:"
}

# GIVEN a palette with a listed color that isn't staged
# WHEN running the pre-commit hook
# THEN it allows the commit: the palette isn't part of it
test_a_listed_color_that_isnt_staged_is_not_checked() {
  git_sandbox
  write_palette_with teal "#0ABAB5"
  run_hook
  assert_status 0
}

# GIVEN a staged palette with a colon in its file name and a listed color
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the whole file name and the line
test_a_palette_with_a_colon_in_its_name_is_named_whole() {
  git_sandbox
  write_palette_with teal "#0ABAB5"
  mv "$SANDBOX/repo/palettes/teal-palette.toml" "$SANDBOX/repo/palettes/te:al-palette.toml"
  git -C "$SANDBOX/repo" add "palettes/te:al-palette.toml"
  line="$(grep -n '^accent = ' "$SANDBOX/repo/palettes/te:al-palette.toml" | cut -d: -f1)"
  run_hook
  assert_status 1
  assert_contains "palettes/te:al-palette.toml:$line:#0ABAB5"
}

# GIVEN an avoid list with only its comments, no colors, and a staged
#       palette
# WHEN running the pre-commit hook
# THEN it allows the commit: there is nothing to look for
test_an_avoid_list_with_no_colors_allows_the_commit() {
  grep '^#' "$SANDBOX/repo/palettes/avoid-these.txt" | grep -v -i -E '^#[0-9a-f]{6}$' \
    >"$SANDBOX/repo/palettes/avoid-these.new"
  mv "$SANDBOX/repo/palettes/avoid-these.new" "$SANDBOX/repo/palettes/avoid-these.txt"
  git_sandbox
  write_palette_with teal "#0ABAB5"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml
  run_hook
  assert_status 0
}

# GIVEN a staged palette, and a git whose search of the palettes fails
# WHEN running the pre-commit hook
# THEN it refuses the commit: a check that couldn't run isn't a pass
test_a_failed_color_search_refuses_the_commit() {
  git_sandbox
  write_palette_with teal "#0ABAB6"
  git -C "$SANDBOX/repo" add palettes/teal-palette.toml
  fake_command git "case \"\$*\" in
  *' grep --cached '*) echo 'fatal: search failed' >&2; exit 128 ;;
esac
exec $(command -v git) \"\$@\""
  PATH="$SANDBOX/bin:$PATH" run_hook
  assert_status 1
  assert_contains "The palettes couldn't be checked against palettes/avoid-these.txt"
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
  assert_contains "These file names and lines have forbidden symbols or emojis"
  assert_contains "  setup.sh:$line"
}

# GIVEN a staged change adding a line with an escape character to setup.sh
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file and line: control characters
#      are ASCII, but not printable
test_a_control_character_is_refused() {
  git_sandbox
  printf '# \033[31mred\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  line="$(wc -l <"$SANDBOX/repo/setup.sh" | tr -d ' ')"
  run_hook
  assert_status 1
  assert_contains "  setup.sh:$line"
}

# GIVEN a staged change adding a line indented with a tab to setup.sh
# WHEN running the pre-commit hook
# THEN it allows the commit: tabs are the one control character allowed
test_a_tab_is_allowed() {
  git_sandbox
  printf '\t# indented\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  run_hook
  assert_status 0
}

# GIVEN a staged change adding a line with a full-width "a" (written as its
#       UTF-8 bytes) to setup.sh
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file and line: it is a letter, but
#      it compatibility-normalizes to ASCII
test_a_letter_that_normalizes_to_ascii_is_refused() {
  git_sandbox
  printf '# \357\275\201\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  line="$(wc -l <"$SANDBOX/repo/setup.sh" | tr -d ' ')"
  run_hook
  assert_status 1
  assert_contains "  setup.sh:$line"
}

# GIVEN a staged change adding a line with a Cyrillic "a" (written as its
#       UTF-8 bytes) to setup.sh
# WHEN running the pre-commit hook
# THEN it allows the commit: it looks like the Latin "a", but it is a letter
#      of its own that doesn't normalize to ASCII
test_a_cyrillic_letter_is_allowed() {
  git_sandbox
  printf '# \320\260\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  run_hook
  assert_status 0
}

# GIVEN a python3 that fails without printing anything, standing in for the
#       symbol check crashing
# WHEN running the pre-commit hook
# THEN it refuses the commit: a check that couldn't finish isn't a pass
test_a_failed_symbol_check_refuses_the_commit() {
  git_sandbox
  fake_command python3 'exit 1'
  PATH="$SANDBOX/bin:$PATH" run_hook
  assert_status 1
  assert_contains "check-symbols.py failed"
}

# GIVEN a staged change to setup.sh, and a git that can't read its staged
#       version
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file and git's message
test_a_staged_file_git_cant_read_refuses_the_commit() {
  git_sandbox
  printf '# more\n' >>"$SANDBOX/repo/setup.sh"
  git -C "$SANDBOX/repo" add setup.sh
  fake_command git "case \"\$*\" in
  'cat-file blob :0:setup.sh') echo 'fatal: bad object' >&2; exit 128 ;;
esac
exec $(command -v git) \"\$@\""
  PATH="$SANDBOX/bin:$PATH" run_hook
  assert_status 1
  assert_contains "  setup.sh (couldn't be read: fatal: bad object)"
}

# GIVEN a git that can't list the staged files
# WHEN running the pre-commit hook
# THEN it refuses the commit, passing on git's message
test_staged_files_git_cant_list_refuse_the_commit() {
  git_sandbox
  fake_command git "case \"\$*\" in
  'diff --cached -z '*) echo 'fatal: index file corrupt' >&2; exit 128 ;;
esac
exec $(command -v git) \"\$@\""
  PATH="$SANDBOX/bin:$PATH" run_hook
  assert_status 1
  assert_contains "  (git couldn't list the staged files: fatal: index file corrupt)"
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

# GIVEN staged files holding an em dash, named with a double quote, a
#       backslash, and a tab (git quotes and escapes names like those)
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming each file: no name lets a file skip
#      the check
test_files_with_unusual_names_are_checked() {
  git_sandbox
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/q\"uote.txt"
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/back\\slash.txt"
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/$(printf 'ta\tb.txt')"
  git -C "$SANDBOX/repo" add -A
  run_hook
  assert_status 1
  assert_contains '  q"uote.txt:1'
  assert_contains '  back\slash.txt:1'
  assert_contains '  ta<U+0009>b.txt:1'
}

# GIVEN a staged file whose name has an escape character, holding an em
#       dash
# WHEN running the pre-commit hook
# THEN it refuses the commit, writing the escape character as <U+001B>
#      instead of sending it to the terminal
test_control_characters_in_names_are_shown_as_text() {
  git_sandbox
  name="$(printf 'e\033[31mred.txt')"
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/$name"
  git -C "$SANDBOX/repo" add "$name"
  run_hook
  assert_status 1
  assert_contains '  e<U+001B>[31mred.txt:1'
  assert_not_contains "$(printf '\033')"
}

# GIVEN staged files named with an em dash: a text file of plain ASCII, and
#       a binary file
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming both files: names follow the same rule
#      as contents, binary files included
test_symbols_in_file_names_are_refused() {
  git_sandbox
  printf 'plain\n' >"$SANDBOX/repo/$(printf 'a\342\200\224b.txt')"
  printf '\211PNG\r\n\032\n\000\000\377\376' >"$SANDBOX/repo/palettes/Screenshots/Dark/$(printf 'a\342\200\224b.png')"
  git -C "$SANDBOX/repo" add -A
  run_hook
  assert_status 1
  assert_contains "These file names and lines have forbidden symbols or emojis"
  assert_contains '  a<U+2014>b.txt (its name)'
  assert_contains '  palettes/Screenshots/Dark/a<U+2014>b.png (its name)'
  assert_not_contains 'a<U+2014>b.txt:1'
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

# GIVEN a committed symlink, replaced by a staged regular file holding an em
#       dash
# WHEN running the pre-commit hook
# THEN it refuses the commit: a file whose type changed is checked too
test_a_symlink_turned_into_a_file_is_checked() {
  ln -s setup.sh "$SANDBOX/repo/link-to-setup"
  git_sandbox
  rm "$SANDBOX/repo/link-to-setup"
  printf 'a \342\200\224 b\n' >"$SANDBOX/repo/link-to-setup"
  git -C "$SANDBOX/repo" add link-to-setup
  run_hook
  assert_status 1
  assert_contains "  link-to-setup:1"
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
  assert_contains "These file names and lines have forbidden symbols or emojis"
}

# --- Tests: dashes in file names ---------------------------------------------

# GIVEN a git that can't list the files being added
# WHEN running the pre-commit hook
# THEN it refuses the commit: a check that couldn't run isn't a pass
test_a_failed_list_of_added_files_refuses_the_commit() {
  git_sandbox
  fake_command git "case \"\$*\" in
  *'diff --cached --name-only'*) echo 'fatal: index file corrupt' >&2; exit 128 ;;
esac
exec $(command -v git) \"\$@\""
  PATH="$SANDBOX/bin:$PATH" run_hook
  assert_status 1
  assert_contains "couldn't be checked for underscores"
}

# GIVEN a staged new file with an underscore in its name
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the file and saying to use dashes
test_an_underscore_in_a_file_name_is_refused() {
  git_sandbox
  printf 'notes\n' >"$SANDBOX/repo/my_notes.txt"
  git -C "$SANDBOX/repo" add my_notes.txt
  run_hook
  assert_status 1
  assert_contains "These file names have underscores:"
  assert_contains "  my_notes.txt"
  assert_contains "Separate the words in file and folder names with dashes instead"
}

# GIVEN a staged new file in a new folder with an underscore in its name
# WHEN running the pre-commit hook
# THEN it refuses the commit: folder names are checked too
test_an_underscore_in_a_folder_name_is_refused() {
  git_sandbox
  mkdir -p "$SANDBOX/repo/app-themes/new_app-theme"
  printf 'theme\n' >"$SANDBOX/repo/app-themes/new_app-theme/theme.tmpl"
  git -C "$SANDBOX/repo" add app-themes/new_app-theme
  run_hook
  assert_status 1
  assert_contains "  app-themes/new_app-theme/theme.tmpl"
}

# GIVEN a file renamed to a name with an underscore, and staged
# WHEN running the pre-commit hook
# THEN it refuses the commit, naming the new name
test_a_rename_to_an_underscore_is_refused() {
  git_sandbox
  git -C "$SANDBOX/repo" mv tests/run.sh tests/run_all.sh
  run_hook
  assert_status 1
  assert_contains "  tests/run_all.sh"
}

# GIVEN a staged new module in jenerate_themes/ with an underscore, as
#       Python needs for a module it loads
# WHEN running the pre-commit hook
# THEN it allows the commit
test_underscores_in_the_python_package_are_allowed() {
  git_sandbox
  printf '"""A module."""\n' >"$SANDBOX/repo/jenerate_themes/new_module.py"
  git -C "$SANDBOX/repo" add jenerate_themes/new_module.py
  run_hook
  assert_status 0
  [ -z "$OUTPUT" ] || fail "expected no output"
}

run_tests
