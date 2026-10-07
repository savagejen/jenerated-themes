# Shared helpers for the shell tests. Source it from a test file, define
# test_* functions, then call run_tests at the end.
#
# Each test runs in a subshell with its own sandbox:
#   $SANDBOX/repo  a copy of the repository as git sees it (generated files
#                  other than the committed Blue Purple ones are left out)
#   $SANDBOX/home  an empty home folder
#   $SANDBOX/bin   fake commands, put first on PATH by the test's run helper
# If the test file defines after_sandbox, it runs once the sandbox is ready.
#
# Run a test file with part of a test's name to run only the tests whose
# names contain it, like tests/apps/test-quassel.sh flatpak.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"

# This file is sourced with no arguments of its own, so $1 is the test
# file's first argument: the part of a test's name to run only those for.
TEST_FILTER="${1:-}"

# --- Sandbox -----------------------------------------------------------------

make_sandbox() {
  SANDBOX="$(mktemp -d "$TMP_BASE/jenerated-tests.XXXXXX")"
  mkdir -p "$SANDBOX/repo" "$SANDBOX/home" "$SANDBOX/bin"
  # Tracked files plus new ones that aren't ignored: the repository as it
  # would be committed, without anyone's locally generated palettes. (Files
  # deleted but still tracked are skipped.) One tar copies them all, which is
  # much faster than copying file by file.
  git -C "$REPO" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' file; do
      [ -f "$REPO/$file" ] && printf '%s\0' "$file"
    done |
    (cd "$REPO" && tar --null -T - -cf -) | tar -xf - -C "$SANDBOX/repo"
}

# fake_command name body -> puts a script called `name` in $SANDBOX/bin.
fake_command() {
  printf '#!/bin/sh\n%s\n' "$2" >"$SANDBOX/bin/$1"
  chmod +x "$SANDBOX/bin/$1"
}

# Finds a Python new enough (3.11+) to run jenerate.py, or prints nothing.
find_python() {
  for py in python3 python3.13 python3.12 python3.11; do
    if command -v "$py" >/dev/null 2>&1 &&
      "$py" -c 'import tomllib' >/dev/null 2>&1; then
      printf '%s' "$py"
      return
    fi
  done
}

# --- Assertions --------------------------------------------------------------
# Output assertions check $OUTPUT and $STATUS, set by the test's run helper.

FAILED=0

fail() {
  printf '    FAIL: %s\n' "$1"
  FAILED=1
}

assert_status() {
  [ "$STATUS" -eq "$1" ] || fail "expected exit status $1, got $STATUS"
}

assert_contains() {
  case "$OUTPUT" in
    *"$1"*) ;;
    *) fail "expected output to contain: $1" ;;
  esac
}

assert_not_contains() {
  case "$OUTPUT" in
    *"$1"*) fail "expected output not to contain: $1" ;;
  esac
}

# assert_link path target
assert_link() {
  if [ ! -L "$1" ]; then
    fail "expected a symlink at $1"
  elif [ "$(readlink "$1")" != "$2" ]; then
    fail "expected $1 -> $2, got -> $(readlink "$1")"
  fi
}

assert_exists() {
  [ -e "$1" ] || fail "expected $1 to exist"
}

assert_missing() {
  [ ! -e "$1" ] || fail "expected $1 not to exist"
}

# assert_file_equals path expected
assert_file_equals() {
  if [ ! -f "$1" ]; then
    fail "expected file $1"
  elif [ "$(cat "$1")" != "$2" ]; then
    fail "expected $1 to contain '$2', got '$(cat "$1")'"
  fi
}

# assert_file_contains path text
assert_file_contains() {
  if [ ! -f "$1" ]; then
    fail "expected file $1"
  elif ! grep -qF -- "$2" "$1"; then
    fail "expected $1 to contain: $2"
  fi
}

# assert_file_not_contains path text
assert_file_not_contains() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    fail "expected $1 not to contain: $2"
  fi
}

# assert_same_file actual expected
assert_valid_json() {
  "${PYTHON:-$(find_python)}" -m json.tool "$1" >/dev/null 2>&1 || fail "expected $1 to be valid JSON"
}

assert_same_file() {
  cmp -s "$1" "$2" || fail "expected $1 to match $2"
}

# --- Running the app in the sandbox -----------------------------------------

# quiet_desktop -> for after_sandbox: every clipboard tool writes to a file, so
# tests never touch the real one, and gsettings and plasma-apply-colorscheme
# don't work, so no test changes your desktop's theme. Keeps only the Blue
# Purple and Sunset palettes, whatever else is in palettes/, so the menus
# number them 1 and 2.
quiet_desktop() {
  for tool in pbcopy wl-copy xclip xsel; do
    fake_command "$tool" "cat > \"$SANDBOX/clipboard\""
  done
  fake_command gsettings "exit 1"
  fake_command plasma-apply-colorscheme "exit 1"
  find "$SANDBOX/repo/palettes" -name '*.toml' ! -name 'blue-purple-palette.toml' \
    ! -name 'sunset-palette.toml' -delete
}

# fake_os Linux|Darwin -> makes `uname -s` report that OS.
fake_os() {
  fake_command uname "echo $1"
}

# in_sandbox command... -> runs the command with the sandbox's home folder and
# fake commands. The settings that point apps at other folders (ZDOTDIR,
# RSTUDIO_CONFIG_HOME, SPYDER_CONFDIR, VEILAMP_DATA_DIR) are cleared, so the
# tests never touch your real ones; a test that needs one set uses
# TEST_ZDOTDIR, TEST_RSTUDIO_CONFIG_HOME, TEST_SPYDER_CONFDIR or
# TEST_VEILAMP_DATA_DIR instead.
in_sandbox() {
  HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WAYLAND_DISPLAY= XDG_DATA_HOME= \
    XDG_CACHE_HOME= XDG_CONFIG_HOME= JENERATE_COMMAND= \
    ZDOTDIR="${TEST_ZDOTDIR:-}" RSTUDIO_CONFIG_HOME="${TEST_RSTUDIO_CONFIG_HOME:-}" \
    SPYDER_CONFDIR="${TEST_SPYDER_CONFDIR:-}" VEILAMP_DATA_DIR="${TEST_VEILAMP_DATA_DIR:-}" \
    "$@"
}

# run_setup "1\nanswers" [options...] -> runs setup.sh with the options, feeding
# it the answers (use \n between them) from its first menu, and sets OUTPUT and
# STATUS. It runs from $RUN_FROM (default $SANDBOX), and runs $SETUP (default
# the sandbox repository's setup.sh).
run_setup() {
  local answers="$1"
  shift
  OUTPUT="$(cd "${RUN_FROM:-$SANDBOX}" && printf '%b' "$answers" |
    in_sandbox bash "${SETUP:-$SANDBOX/repo/setup.sh}" "$@" 2>&1)"
  STATUS=$?
}

# wait_for file -> waits up to two seconds for a file (from a command the app
# started in the background).
wait_for() {
  for _ in $(seq 40); do
    [ -e "$1" ] && return 0
    "$(find_python)" -c 'import time; time.sleep(0.05)'
  done
}

# Replaces the sandbox's serve.py with a stub that records its folder and
# arguments in $SANDBOX/serve-ran, then exits.
stub_palette_creator() {
  cat >"$SANDBOX/repo/jenerate_themes/creator/serve.py" <<EOF
import os, sys
with open("$SANDBOX/serve-ran", "w") as f:
    f.write(os.getcwd() + "|" + " ".join(sys.argv[1:]))
print("stub server running")
EOF
}

# --- Palettes and colors ----------------------------------------------------

# dawn_palette [folder] -> adds Dawn, a light copy of Sunset, to palettes/ (or
# a folder in it).
dawn_palette() {
  sed -e 's/^name = .*/name = "Dawn"/' -e 's/^slug = .*/slug = "dawn"/' \
    -e 's/^bg = "#[0-9a-fA-F]*"/bg = "#fbfbfd"/' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/${1:+$1/}dawn-palette.toml"
}

# write_light_palette slug name [extra lines...] -> writes a palette copied
# from Sunset but with a near-white editor background, plus any extra lines
# (which go before [colors]).
write_light_palette() {
  local slug="$1" name="$2"
  shift 2
  {
    sed -n '1,/^\[colors\]/{/^\[colors\]/!p}' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" |
      sed -e "s|^name = .*|name = \"$name\"|" -e "s|^slug = .*|slug = \"$slug\"|"
    for line in "$@"; do printf '%s\n' "$line"; done
    sed -n '/^\[colors\]/,$p' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" |
      sed 's/^bg = "#[0-9a-fA-F]*"/bg = "#fbfbfd"/'
  } >"$SANDBOX/repo/palettes/$slug-palette.toml"
}

# Tests read expected colors from the palette itself, so palettes can be
# changed without changing the tests.
#   color key [palette]     -> the color's #rrggbb, following references
#   color_rgb key [palette] -> its "r, g, b"
#   color_hsl key [palette] -> its "h|s|l" (whole degrees and percents)
# The palette defaults to palettes/Dark/sunset-palette.toml in the sandbox.
color_forms() {
  "${PYTHON:-$(find_python)}" -c '
import colorsys, sys, tomllib
form, key, path = sys.argv[1:]
colors = tomllib.load(open(path, "rb"))["colors"]
value = colors[key]
while not value.startswith("#"):
    value = colors[value]
r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
print({"hex": value, "rgb": f"{r}, {g}, {b}",
       "hsl": f"{round(h * 360) % 360}|{round(s * 100)}|{round(l * 100)}"}[form])
' "$1" "$2" "${3:-$SANDBOX/repo/palettes/Dark/sunset-palette.toml}"
}
color() { color_forms hex "$@"; }
color_rgb() { color_forms rgb "$@"; }
color_hsl() { color_forms hsl "$@"; }

# --- Runner ------------------------------------------------------------------

# Runs every test_* function, each in its own subshell and sandbox, and exits
# non-zero if any failed. On failure, prints the last $OUTPUT.
run_tests() {
  local passed=0 failed=0 test marker changed
  # Tests work on throwaway copies; anything in the real repository that
  # changes while they run means a test reached outside its sandbox.
  marker="$(mktemp "$TMP_BASE/jenerated-tests-start.XXXXXX")"
  for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
    case "$test" in *"$TEST_FILTER"*) ;; *) continue ;; esac
    if (
      make_sandbox
      trap 'rm -rf "$SANDBOX"' EXIT
      if declare -F after_sandbox >/dev/null; then after_sandbox; fi
      OUTPUT=""
      "$test"
      if [ "$FAILED" -ne 0 ]; then
        printf '    output:\n'
        printf '%s\n' "$OUTPUT" | sed 's/^/      | /'
      fi
      exit "$FAILED"
    ); then
      printf 'ok    %s\n' "$test"
      passed=$((passed + 1))
    else
      printf 'FAIL  %s\n' "$test"
      failed=$((failed + 1))
    fi
  done

  changed="$(find "$REPO" -newer "$marker" -type f ! -path "$REPO/.git/*" ! -path '*/__pycache__/*' 2>/dev/null)"
  rm -f "$marker"
  if [ -n "$changed" ]; then
    printf '\nFAIL  these files in the repository changed while the tests ran (a test\n'
    printf '      reached outside its sandbox, or they were edited meanwhile):\n'
    printf '%s\n' "$changed" | sed 's/^/        /'
    failed=$((failed + 1))
  fi

  printf '\n%d passed, %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ]
}
