#!/usr/bin/env bash
# Tests for Emacs: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-emacs.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
emacs_theme() { printf '%s' "$SANDBOX/repo/app-themes/emacs-theme/jenerated-$1-theme.el"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Emacs theme
# THEN it defines and provides the theme jenerated-sunset (matching the file
#      name, as Emacs requires), its parentheses balance outside strings and
#      comments, and the default, keyword and string faces and the terminal
#      colors use the palette's colors
test_emacs_theme_uses_the_palette() {
  generate sunset
  theme="$(emacs_theme sunset)"
  OUTPUT="$("$PYTHON" -c '
import re, sys
text = open(sys.argv[1]).read()
depth, in_string, i = 0, False, 0
while i < len(text):
    ch = text[i]
    if in_string:
        if ch == "\\": i += 1
        elif ch == "\"": in_string = False
    elif ch == ";":
        i = text.find("\n", i)
        if i < 0: break
    elif ch == "\"": in_string = True
    elif ch == "(": depth += 1
    elif ch == ")":
        depth -= 1
        if depth < 0: print("a closing parenthesis without an opening one")
    i += 1
if depth != 0 or in_string:
    print("the parentheses or strings do not balance")
if "(deftheme jenerated-sunset" not in text or "(provide-theme (quote jenerated-sunset))" not in text.replace("\x27jenerated-sunset", "(quote jenerated-sunset)"):
    print("the theme is not defined and provided as jenerated-sunset")
' "$theme")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
  assert_file_contains "$theme" "'(default ((t (:foreground \"$(color text)\" :background \"$(color bg)\"))))"
  assert_file_contains "$theme" "'(font-lock-keyword-face ((t (:foreground \"$(color accent_soft)\"))))"
  assert_file_contains "$theme" "'(font-lock-string-face ((t (:foreground \"$(color green)\"))))"
  assert_file_contains "$theme" "'(ansi-color-red ((t (:foreground \"$(color term_red)\" :background \"$(color term_red)\"))))"
}

# GIVEN the Sunset palette, and Emacs
# WHEN Emacs loads the generated theme (with no init file of its own)
# THEN it's enabled, its faces have the palette's colors, and every face it
#      sets is one Emacs defines
test_emacs_theme_loads_in_emacs() {
  command -v emacs >/dev/null 2>&1 || return 0
  generate sunset
  OUTPUT="$(emacs --batch -Q --eval "
(progn
  (dolist (f '(ansi-color diff-mode hl-line display-line-numbers tab-bar tab-line paren display-fill-column-indicator))
    (require f nil t))
  (add-to-list 'custom-theme-load-path \"$SANDBOX/repo/app-themes/emacs-theme/\")
  (load-theme 'jenerated-sunset t)
  (let (unknown)
    (dolist (spec (get 'jenerated-sunset 'theme-settings))
      (when (and (eq (car spec) 'theme-face) (not (facep (nth 1 spec))))
        (push (nth 1 spec) unknown)))
    (princ (format \"%s %s %s %s\" custom-enabled-themes (face-attribute 'default :background)
      (face-attribute 'font-lock-string-face :foreground) (or unknown \"\")))))" 2>&1)"
  expected="(jenerated-sunset) $(color bg) $(color green) "
  [ "$OUTPUT" = "$expected" ] || fail "expected '$expected'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Emacs theme is deleted, and the template is kept
test_remove_deletes_the_emacs_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/emacs-theme/jenerated-sunset-theme.el"
  assert_missing "$(emacs_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/emacs-theme/theme.el.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN no Emacs folder yet
# WHEN choosing Emacs and Blue Purple
# THEN the theme is linked into ~/.emacs.d (where Emacs looks for themes by
#      default), and it explains how to load it and keep it
test_emacs_links_the_theme() {
  fake_os Linux
  install_app emacs blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.emacs.d/jenerated-blue-purple-theme.el" \
    "$SANDBOX/repo/app-themes/emacs-theme/jenerated-blue-purple-theme.el"
  assert_contains "M-x load-theme RET jenerated-blue-purple RET"
  assert_contains "M-x customize-themes"
}

# GIVEN Emacs set up in ~/.config/emacs (and no ~/.emacs.d or ~/.emacs)
# WHEN choosing Emacs
# THEN the theme goes in ~/.config/emacs, the folder Emacs uses then
test_emacs_uses_the_config_folder() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/emacs"
  install_app emacs blue-purple "y\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/.config/emacs/jenerated-blue-purple-theme.el"
  assert_missing "$SANDBOX/home/.emacs.d"
}

# GIVEN a ~/.emacs file as well as ~/.config/emacs
# WHEN choosing Emacs
# THEN the theme goes in ~/.emacs.d, since Emacs prefers it whenever there's
#      a ~/.emacs
test_emacs_prefers_emacs_d_when_there_is_a_dot_emacs() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/emacs"
  printf ';; my settings\n' >"$SANDBOX/home/.emacs"
  install_app emacs blue-purple "y\n1\n"
  assert_status 0
  assert_exists "$SANDBOX/home/.emacs.d/jenerated-blue-purple-theme.el"
  assert_missing "$SANDBOX/home/.config/emacs/jenerated-blue-purple-theme.el"
}

run_tests
