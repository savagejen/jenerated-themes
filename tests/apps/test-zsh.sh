#!/usr/bin/env bash
# Tests for zsh (syntax highlighting and suggestions): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-zsh.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
zsh_theme() { printf '%s' "$SANDBOX/repo/app-themes/zsh-theme/$1/jenerated-$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the zsh file colors commands, strings, options and unknown commands
#      from the palette, and dims suggestions like comments; and the
#      fast-syntax-highlighting theme uses the same colors
test_zsh_colors_use_the_palette() {
  generate sunset
  zsh="$(zsh_theme sunset).zsh"
  assert_file_contains "$zsh" "ZSH_HIGHLIGHT_STYLES[command]='fg=$(color accent_light)'"
  assert_file_contains "$zsh" "ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=$(color green)'"
  assert_file_contains "$zsh" "ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=$(color orange)'"
  assert_file_contains "$zsh" "ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=$(color red),bold'"
  assert_file_contains "$zsh" "ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=$(color text_muted)'"
  ini="$(zsh_theme sunset).ini"
  assert_file_contains "$ini" "command           = $(color accent_light)"
  assert_file_contains "$ini" "single-quoted-argument = $(color green)"
  assert_file_contains "$ini" "unknown-token    = $(color red),bold"
}

# GIVEN the Sunset palette
# WHEN generating it and reading the zsh-syntax-highlighting styles it sets
# THEN each is one the plugin documents, and each value is none, or fg=, bg=
#      and attributes with #rrggbb colors
test_zsh_styles_are_zsh_syntax_highlighting_styles() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
styles = set("""unknown-token reserved-word alias suffix-alias global-alias builtin function command
precommand commandseparator hashed-command autodirectory path path_pathseparator path_prefix
path_prefix_pathseparator globbing history-expansion command-substitution
command-substitution-delimiter process-substitution process-substitution-delimiter
arithmetic-expansion single-hyphen-option double-hyphen-option back-quoted-argument
back-quoted-argument-delimiter single-quoted-argument double-quoted-argument
dollar-quoted-argument rc-quote dollar-double-quoted-argument back-double-quoted-argument
back-dollar-quoted-argument assign redirection comment named-fd numeric-fd arg0 default""".split())
for name, value in re.findall(r"^ZSH_HIGHLIGHT_STYLES\[([^]]+)\]=\x27([^\x27]*)\x27$", open(sys.argv[1]).read(), re.M):
    if name not in styles:
        print(f"{name} is not a zsh-syntax-highlighting style")
    for part in value.split(","):
        if not re.fullmatch(r"none|(fg|bg)=#[0-9a-fA-F]{6}|bold|underline|standout", part):
            print(f"{name} has {part}")
' "$(zsh_theme sunset).zsh")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its fast-syntax-highlighting theme the way
#      fast-theme does
# THEN it sets every style fast-theme asks for (so fast-theme reports none
#      missing), and each value is one fast-theme can read: none,
#      attributes, and colors as #rrggbb or bg:#rrggbb
test_zsh_fast_theme_has_every_style() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
wanted = """default unknown-token reserved-word alias suffix-alias builtin function command precommand
commandseparator hashed-command path pathseparator globbing globbing-ext history-expansion
single-hyphen-option double-hyphen-option back-quoted-argument single-quoted-argument
double-quoted-argument dollar-quoted-argument back-or-dollar-double-quoted-argument
back-dollar-quoted-argument assign redirection comment variable mathvar mathnum matherr
assign-array-bracket forvar fornum foroper forsep exec-descriptor here-string-tri here-string-text
here-string-var secondary case-input case-parentheses case-condition correct-subtle incorrect-subtle
subtle-separator subtle-bg path-to-dir paired-bracket bracket-level-1 bracket-level-2 bracket-level-3
global-alias subcommand single-sq-bracket double-sq-bracket double-paren optarg-string optarg-number
recursive-base""".split()
styles = {}
for line in open(sys.argv[1]).read().splitlines():
    if re.match(r"\s*;", line) or re.match(r"\s*\[", line) or not line.strip():
        continue
    m = re.fullmatch(r"\s*([^\s=]+)\s*=\s*(.*?)\s*", line)
    if not m:
        print(f"not key = value: {line}")
        continue
    styles[m.group(1)] = m.group(2)
for name in wanted:
    if name not in styles:
        print(f"missing style: {name}")
for name, value in styles.items():
    if name not in wanted:
        print(f"{name} is not a fast-syntax-highlighting style")
    if name in ("secondary", "pathseparator") or not value:
        continue
    for part in value.split(","):
        if not re.fullmatch(r"none|(no-)?(bold|blink|conceal|reverse|standout|underline)|(bg:)?#[0-9a-fA-F]{6}", part):
            print(f"{name} has {part}")
' "$(zsh_theme sunset).ini")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN the Sunset palette, and zsh
# WHEN zsh loads the generated file, with and without a truecolor terminal
# THEN it loads without errors, sets the styles and the suggestion color,
#      and loads zsh's nearcolor module only when the terminal doesn't say it
#      has 24-bit color
test_zsh_file_loads_in_zsh() {
  command -v zsh >/dev/null 2>&1 || return 0
  generate sunset
  file="$(zsh_theme sunset).zsh"
  OUTPUT="$(COLORTERM=truecolor zsh -f -c 'source "$1"; print -r -- "$ZSH_HIGHLIGHT_STYLES[command] $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE $(zmodload | grep -c nearcolor)"' zsh "$file" 2>&1)"
  expected="fg=$(color accent_light) fg=$(color text_muted) 0"
  [ "$OUTPUT" = "$expected" ] || fail "with truecolor: expected '$expected'"
  nearcolor="$(COLORTERM= zsh -f -c 'source "$1"; zmodload | grep -c nearcolor' zsh "$file" 2>&1)"
  [ "$nearcolor" = 1 ] || fail "expected zsh/nearcolor without truecolor, got: $nearcolor"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its zsh folder is deleted, and the templates are kept
test_remove_deletes_the_zsh_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/zsh-theme/sunset/jenerated-sunset.zsh"
  assert_missing "$SANDBOX/repo/app-themes/zsh-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/zsh-theme/colors.zsh.tmpl"
}

# --- Tests: installing -------------------------------------------------------

ZSH_LINE='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/jenerated-colors.zsh"'

# fake_zsh with|without -> fakes zsh, as if ~/.zshrc loaded
# fast-syntax-highlighting or not: with it, running fast-theme prints the
# marker jenerate looks for. Records the command it's given in
# $SANDBOX/zsh-ran.
fake_zsh() {
  local marker=""
  [ "$1" = with ] && marker="echo JENERATED-FAST-THEME-DONE"
  fake_command zsh "printf '%s' \"\$2\" >\"$SANDBOX/zsh-ran\"
$marker"
}

# GIVEN no ~/.zshrc, and zsh without fast-syntax-highlighting
# WHEN choosing zsh and Blue Purple
# THEN the zsh colors and the fast-syntax-highlighting theme are linked into
#      ~/.config, ~/.zshrc is created to load the colors, and it says how to
#      switch fast-syntax-highlighting to the theme
test_zsh_creates_zshrc() {
  fake_os Linux
  fake_zsh without
  install_app zsh blue-purple
  assert_status 0
  folder="$SANDBOX/repo/app-themes/zsh-theme/blue-purple"
  assert_link "$SANDBOX/home/.config/zsh/jenerated-colors.zsh" "$folder/jenerated-blue-purple.zsh"
  assert_link "$SANDBOX/home/.config/fsh/jenerated-colors.ini" "$folder/jenerated-blue-purple.ini"
  assert_file_contains "$SANDBOX/home/.zshrc" "$ZSH_LINE"
  assert_contains "    fast-theme XDG:jenerated-colors"
  assert_file_contains "$SANDBOX/zsh-ran" "fast-theme -q XDG:jenerated-colors"
}

# GIVEN a ~/.zshrc of the user's own, and zsh with fast-syntax-highlighting
# WHEN choosing zsh and answering yes to loading the colors
# THEN the line goes at the end of ~/.zshrc, and fast-syntax-highlighting is
#      switched to the theme
test_zsh_switches_fast_syntax_highlighting() {
  fake_os Linux
  fake_zsh with
  printf 'source ~/plugins/fast-syntax-highlighting.plugin.zsh\n' >"$SANDBOX/home/.zshrc"
  install_app zsh blue-purple "y\n"
  assert_status 0
  expected="$(printf 'source ~/plugins/fast-syntax-highlighting.plugin.zsh\n# Colors from Jenerated Themes\n%s' "$ZSH_LINE")"
  assert_file_equals "$SANDBOX/home/.zshrc" "$expected"
  assert_contains "Switched fast-syntax-highlighting to Jenerated Blue Purple."
  assert_not_contains "If you use fast-syntax-highlighting"
}

# GIVEN a ~/.zshrc of the user's own
# WHEN choosing zsh and answering no to loading the colors
# THEN ~/.zshrc is left alone, and it shows the line to add by hand
test_zsh_leaves_zshrc_when_declined() {
  fake_os Linux
  fake_zsh without
  printf 'setopt autocd\n' >"$SANDBOX/home/.zshrc"
  install_app zsh blue-purple "n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.zshrc" "setopt autocd"
  assert_contains "    $ZSH_LINE"
}

# GIVEN ZDOTDIR set to another folder, where zsh keeps its .zshrc
# WHEN choosing zsh
# THEN the .zshrc in that folder loads the colors, and no ~/.zshrc is made
test_zsh_uses_zdotdir() {
  fake_os Linux
  fake_zsh without
  mkdir -p "$SANDBOX/home/.config/zsh"
  TEST_ZDOTDIR="$SANDBOX/home/.config/zsh" install_app zsh blue-purple
  assert_status 0
  assert_file_contains "$SANDBOX/home/.config/zsh/.zshrc" "$ZSH_LINE"
  assert_missing "$SANDBOX/home/.zshrc"
}

run_tests
