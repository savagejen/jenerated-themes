#!/usr/bin/env bash
# Tests for tmux: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-tmux.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
tmux_theme() { printf '%s' "$SANDBOX/repo/app-themes/tmux-theme/$1/jenerated-$1.conf"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN its tmux colors set the status line, the current window, the active
#      pane's border, messages and the copy-mode selection from the palette
test_tmux_colors_use_the_palette() {
  generate sunset
  conf="$(tmux_theme sunset)"
  assert_file_contains "$conf" "set -gq status-style \"fg=$(color text_subtle),bg=$(color bg_chrome)\""
  assert_file_contains "$conf" "set -gq window-status-current-style \"fg=$(color text_strong),bg=$(color bg_selected),bold\""
  assert_file_contains "$conf" "set -gq pane-active-border-style \"fg=$(color accent)\""
  assert_file_contains "$conf" "set -gq message-style \"fg=$(color text),bg=$(color bg_widget)\""
  assert_file_contains "$conf" "set -gq mode-style \"fg=$(color text_strong),bg=$(color selection)\""
}

# GIVEN the Sunset palette
# WHEN generating it and reading each line as tmux would
# THEN every setting is "set -gq" (so a tmux without the option skips it
#      quietly), each option is one tmux 3.4 has, each value is quoted (tmux
#      reads an unquoted # as a comment), and each style is fg=, bg= and
#      attributes, with #rrggbb colors
test_tmux_colors_follow_tmuxs_rules() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
styles = {"status-style", "window-status-style", "window-status-current-style", "window-status-activity-style",
          "window-status-bell-style", "pane-border-style", "pane-active-border-style", "message-style",
          "message-command-style", "mode-style", "copy-mode-match-style", "copy-mode-current-match-style",
          "popup-style", "popup-border-style", "menu-style", "menu-selected-style", "menu-border-style"}
colours = {"clock-mode-colour", "display-panes-colour", "display-panes-active-colour"}
for line in open(sys.argv[1]).read().splitlines():
    if not line or line.startswith("#"):
        continue
    m = re.fullmatch(r"set -gq ([a-z-]+) \"([^\"]*)\"", line)
    if not m:
        print(f"not set -gq option \"value\": {line}")
        continue
    option, value = m.groups()
    if option in colours:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            print(f"{option} is {value}, not #rrggbb")
    elif option in styles:
        for part in value.split(","):
            if not re.fullmatch(r"(fg|bg)=#[0-9a-fA-F]{6}|bold|italics|underscore|dim", part):
                print(f"{option} has {part}")
    else:
        print(f"unknown option: {option}")
' "$(tmux_theme sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its tmux folder is deleted, and the template is kept
test_remove_deletes_the_tmux_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/tmux-theme/sunset/jenerated-sunset.conf"
  assert_missing "$SANDBOX/repo/app-themes/tmux-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/tmux-theme/colors.conf.tmpl"
}

# --- Tests: installing -------------------------------------------------------

TMUX_LINE='source-file -q ~/.config/tmux/jenerated-colors.conf'

# fake_tmux running|stopped -> fakes tmux: list-sessions succeeds only when
# running, and source-file records the file it's given in $SANDBOX/tmux-sourced.
fake_tmux() {
  local status=1
  [ "$1" = running ] && status=0
  fake_command tmux "case \"\$1\" in
  list-sessions) exit $status ;;
  source-file) printf '%s' \"\$2\" >\"$SANDBOX/tmux-sourced\" ;;
esac"
}

# GIVEN no tmux settings file, and tmux not running
# WHEN choosing tmux and Blue Purple
# THEN the colors are linked into ~/.config/tmux, ~/.tmux.conf is created to
#      load them, and it says how to load them into a running tmux
test_tmux_creates_tmux_conf() {
  fake_os Linux
  fake_tmux stopped
  install_app tmux blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/.config/tmux/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/tmux-theme/blue-purple/jenerated-blue-purple.conf"
  assert_file_contains "$SANDBOX/home/.tmux.conf" "$TMUX_LINE"
  assert_contains "the next time it starts"
  assert_contains "tmux source-file ~/.config/tmux/jenerated-colors.conf"
  assert_missing "$SANDBOX/tmux-sourced"
}

# GIVEN a tmux.conf in ~/.config/tmux (and no ~/.tmux.conf)
# WHEN choosing tmux and answering yes to loading the colors
# THEN that file loads them, and no ~/.tmux.conf is made (tmux would read it
#      instead)
test_tmux_uses_the_config_folder_file() {
  fake_os Linux
  fake_tmux stopped
  mkdir -p "$SANDBOX/home/.config/tmux"
  printf 'set -g mouse on\n' >"$SANDBOX/home/.config/tmux/tmux.conf"
  install_app tmux blue-purple "y\n"
  assert_status 0
  expected="$(printf 'set -g mouse on\n# Colors from Jenerated Themes\n%s' "$TMUX_LINE")"
  assert_file_equals "$SANDBOX/home/.config/tmux/tmux.conf" "$expected"
  assert_missing "$SANDBOX/home/.tmux.conf"
}

# GIVEN a ~/.tmux.conf of the user's own
# WHEN choosing tmux and answering no to loading the colors
# THEN ~/.tmux.conf is left alone, and it shows the line to add by hand
test_tmux_leaves_tmux_conf_when_declined() {
  fake_os Linux
  fake_tmux stopped
  printf 'set -g mouse on\n' >"$SANDBOX/home/.tmux.conf"
  install_app tmux blue-purple "n\n"
  assert_status 0
  assert_file_equals "$SANDBOX/home/.tmux.conf" "set -g mouse on"
  assert_contains "    $TMUX_LINE"
}

# GIVEN tmux running
# WHEN choosing tmux and answering yes to loading the colors into it
# THEN the running tmux is told to load the colors file
test_tmux_loads_the_colors_into_a_running_tmux() {
  fake_os Linux
  fake_tmux running
  install_app tmux blue-purple "y\n"
  assert_status 0
  assert_file_equals "$SANDBOX/tmux-sourced" "$SANDBOX/home/.config/tmux/jenerated-colors.conf"
  assert_contains "tmux uses Jenerated Blue Purple now"
}

# GIVEN tmux set up with Blue Purple
# WHEN choosing tmux and Sunset, and answering yes to replacing the link
# THEN the link points to Sunset, and ~/.tmux.conf isn't changed again
test_tmux_switching_palettes_repoints_the_link() {
  fake_os Linux
  fake_tmux stopped
  install_app tmux blue-purple
  cp "$SANDBOX/home/.tmux.conf" "$SANDBOX/tmux-before.conf"
  install_app tmux sunset "y\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/tmux/jenerated-colors.conf" \
    "$SANDBOX/repo/app-themes/tmux-theme/sunset/jenerated-sunset.conf"
  assert_same_file "$SANDBOX/home/.tmux.conf" "$SANDBOX/tmux-before.conf"
}

run_tests
