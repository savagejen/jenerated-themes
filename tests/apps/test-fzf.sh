#!/usr/bin/env bash
# Tests for fzf (fuzzy finder): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-fzf.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

fzf_theme() { printf '%s' "$SANDBOX/repo/app-themes/fzf-theme/$1/jenerated-$1"; }

# --- Tests: making the theme -------------------------------------------------

# fzf_colors file -> prints the name:color pairs of the --color option in a
# generated fzf file, one per line.
fzf_colors() {
  sed -n "s/.*'--color=\([^']*\)'.*/\1/p" "$1" | tr ',' '\n'
}

# GIVEN the Sunset palette
# WHEN generating it
# THEN the bash/zsh and fish files set the same colors, with the list text,
#      background, current line, matches, prompt and marker from the palette
test_fzf_colors_use_the_palette() {
  generate sunset
  colors="$(fzf_colors "$(fzf_theme sunset).sh")"
  for pair in "fg:$(color text_subtle)" "bg:$(color bg)" "fg+:$(color text_strong)" "bg+:$(color bg_selected)" \
    "hl:$(color magenta)" "prompt:$(color accent)" "marker:$(color green)"; do
    printf '%s\n' "$colors" | grep -qxF -- "$pair" || fail "expected $pair in the fzf colors"
  done
  [ "$colors" = "$(fzf_colors "$(fzf_theme sunset).fish")" ] || fail "expected the fish file to set the same colors"
}

# GIVEN the Sunset palette
# WHEN generating it and reading the color names it sets
# THEN each is one fzf 0.29 (Ubuntu 22.04) already knew: older versions
#      refuse the whole --color option over one name they don't know
test_fzf_colors_only_use_names_from_fzf_0_29() {
  generate sunset
  known=" fg bg hl fg+ bg+ hl+ gutter query disabled info border prompt pointer marker spinner header preview-fg preview-bg "
  for pair in $(fzf_colors "$(fzf_theme sunset).sh"); do
    case "$known" in
      *" ${pair%%:*} "*) ;;
      *) fail "${pair%%:*} is newer than fzf 0.29" ;;
    esac
  done
}

# GIVEN the Sunset palette, and FZF_DEFAULT_OPTS set to --layout=reverse
# WHEN a POSIX shell (dash if there is one) loads the generated file twice
# THEN FZF_DEFAULT_OPTS is the user's option followed by the colors, once
test_fzf_sh_adds_the_colors_once() {
  generate sunset
  shell="$(command -v dash || command -v sh)"
  opts="$(FZF_DEFAULT_OPTS=--layout=reverse "$shell" -c '. "$1"; . "$1"; printf %s "$FZF_DEFAULT_OPTS"' sh "$(fzf_theme sunset).sh")"
  expected="--layout=reverse --color=$(fzf_colors "$(fzf_theme sunset).sh" | paste -sd, -)"
  [ "$opts" = "$expected" ] || fail "expected '$expected', got '$opts'"
}

# GIVEN the Sunset palette, and fish
# WHEN fish loads the generated fish file twice, with FZF_DEFAULT_OPTS empty
# THEN FZF_DEFAULT_OPTS is just the colors, once
test_fzf_fish_adds_the_colors_once() {
  command -v fish >/dev/null 2>&1 || return 0
  generate sunset
  opts="$(fish --no-config -c 'set -gx FZF_DEFAULT_OPTS ""; source $argv[1]; source $argv[1]; printf %s $FZF_DEFAULT_OPTS' "$(fzf_theme sunset).fish")"
  expected="--color=$(fzf_colors "$(fzf_theme sunset).fish" | paste -sd, -)"
  [ "$opts" = "$expected" ] || fail "expected '$expected', got '$opts'"
}

# GIVEN the Sunset palette, and fzf
# WHEN fzf runs with the generated colors
# THEN it accepts them
test_fzf_accepts_the_colors() {
  command -v fzf >/dev/null 2>&1 || return 0
  generate sunset
  OUTPUT="$(printf 'apple\n' | FZF_DEFAULT_OPTS= sh -c '. "$1"; fzf --filter a' sh "$(fzf_theme sunset).sh" 2>&1)"
  [ "$OUTPUT" = "apple" ] || fail "expected fzf to accept the colors"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its fzf folder is deleted, and the templates are kept
test_remove_deletes_the_fzf_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/fzf-theme/sunset/jenerated-sunset.sh"
  assert_missing "$SANDBOX/repo/app-themes/fzf-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/fzf-theme/fzf.sh.tmpl"
}

# --- Tests: installing -------------------------------------------------------

FZF_LINE='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/jenerated-colors.sh"'

# GIVEN a bash user whose ~/.bashrc sets FZF_DEFAULT_OPTS, and whose last
#       line has no line break
# WHEN choosing fzf and Blue Purple, and answering yes to loading the colors
# THEN the colors file is linked into ~/.config/fzf, ~/.bashrc loads it on a
#      line of its own, and a shell reading ~/.bashrc has the user's option
#      followed by Blue Purple's colors
test_fzf_loads_the_colors_from_bashrc() {
  fake_os Linux
  printf 'export FZF_DEFAULT_OPTS="--layout=reverse"' >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash install_app fzf blue-purple "y\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/fzf/jenerated-colors.sh" \
    "$SANDBOX/repo/app-themes/fzf-theme/blue-purple/jenerated-blue-purple.sh"
  assert_file_contains "$SANDBOX/home/.bashrc" 'export FZF_DEFAULT_OPTS="--layout=reverse"'
  [ "$(grep -cxF -- "$FZF_LINE" "$SANDBOX/home/.bashrc")" = 1 ] || fail "expected ~/.bashrc to load the colors once"
  opts="$(HOME="$SANDBOX/home" XDG_CONFIG_HOME= bash -c '. ~/.bashrc; printf %s "$FZF_DEFAULT_OPTS"')"
  case "$opts" in
    "--layout=reverse --color=fg:"*) ;;
    *) fail "expected the user's option, then the colors, got: $opts" ;;
  esac
  assert_contains "Open a new terminal"
}

# GIVEN a zsh user with no ~/.zshrc yet
# WHEN choosing fzf and answering yes
# THEN ~/.zshrc is created, loading the colors
test_fzf_creates_zshrc_for_a_zsh_user() {
  fake_os Linux
  SHELL=/usr/bin/zsh install_app fzf blue-purple "y\n"
  assert_status 0
  assert_file_contains "$SANDBOX/home/.zshrc" "$FZF_LINE"
}

# GIVEN fzf set up with Blue Purple, loaded from ~/.bashrc
# WHEN choosing fzf and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset's colors, and ~/.bashrc isn't changed again
test_fzf_switching_palettes_repoints_the_link() {
  fake_os Linux
  : >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash install_app fzf blue-purple "y\n"
  cp "$SANDBOX/home/.bashrc" "$SANDBOX/bashrc-before"
  SHELL=/bin/bash install_app fzf sunset "y\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/fzf/jenerated-colors.sh" \
    "$SANDBOX/repo/app-themes/fzf-theme/sunset/jenerated-sunset.sh"
  assert_same_file "$SANDBOX/home/.bashrc" "$SANDBOX/bashrc-before"
  assert_not_contains "Load the colors in"
}

# GIVEN a fish user (a ~/.config/fish folder, and no bash or zsh files)
# WHEN choosing fzf
# THEN the fish colors are linked into fish's conf.d, which fish loads by
#      itself, and no startup file is changed
test_fzf_links_the_fish_colors() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/fish"
  SHELL=/usr/bin/fish install_app fzf blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/.config/fish/conf.d/jenerated-fzf.fish" \
    "$SANDBOX/repo/app-themes/fzf-theme/blue-purple/jenerated-blue-purple.fish"
  assert_missing "$SANDBOX/home/.bashrc"
  assert_missing "$SANDBOX/home/.zshrc"
  assert_contains "Open a new terminal"
}

# GIVEN a bash user, without fish
# WHEN choosing fzf and answering no to loading the colors
# THEN ~/.bashrc is left alone, and it shows the line to add by hand
test_fzf_shows_the_line_when_declined() {
  command -v fish >/dev/null 2>&1 && return 0  # fish would load the colors itself
  fake_os Linux
  printf '# my bashrc\n' >"$SANDBOX/home/.bashrc"
  SHELL=/bin/bash install_app fzf blue-purple "n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.bashrc" "# my bashrc"
  assert_contains "add this line to your shell's startup file"
  assert_contains "    $FZF_LINE"
}

run_tests
