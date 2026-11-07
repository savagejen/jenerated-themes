#!/usr/bin/env bash
# Tests for Quassel IRC: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-quassel.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

quassel_qss() { printf '%s' "$SANDBOX/repo/app-themes/quassel-theme/jenerated-$1.qss"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its Quassel stylesheet
# THEN the window follows the palette (Qt's palette and the chat view), the
#      marker line is the accent, lines that mention you are orange laid over
#      the background, and IRC's white and black are the palette's bright
#      white and black terminal colors
test_quassel_stylesheet_follows_the_palette() {
  generate sunset
  qss="$(quassel_qss sunset)"
  assert_file_contains "$qss" "Jenerated Sunset"
  assert_file_contains "$qss" "  window: $(color bg_sidebar);"
  assert_file_contains "$qss" "  base: $(color bg);"
  assert_file_contains "$qss" "  highlight: $(color accent);"
  assert_file_contains "$qss" "ChatView { background: $(color bg); }"
  assert_file_contains "$qss" "stop: 0 $(color accent), stop: 0.1 transparent"
  highlight="$("$PYTHON" -c '
import sys
sys.path.insert(0, sys.argv[1])
from jenerate_themes.colors import blend
print(blend(sys.argv[2], sys.argv[3], 30))
' "$SANDBOX/repo" "$(color orange)" "$(color bg)")"
  assert_file_contains "$qss" "  background: $highlight;"
  assert_file_contains "$qss" "ChatLine[fg-color=\"00\"] { foreground: $(color term_bright_white); }"
  assert_file_contains "$qss" "ChatLine[bg-color=\"01\"] { background: $(color term_black); }"
}

# GIVEN the Sunset palette
# WHEN generating it and reading its Quassel stylesheet the way Quassel does
#      (comments removed, then its own blocks taken out)
# THEN every Palette role is one Quassel knows, every ChatLine, ChatListItem
#      and NickListItem declaration matches Quassel's patterns, every IRC
#      color from 00 to 0f is set for text and background, and what's left
#      for Qt is only the chat view's background
test_quassel_stylesheet_parses_as_quassel_reads_it() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
ss = open(sys.argv[1]).read()
problems = []
# As qssparser.cpp: remove // and /* */ comments, then the Palette blocks,
# then ChatLine, ChatListItem and NickListItem blocks.
ss = re.sub(r"//.*?(\n|$)|/\*.*?\*/", "", ss, flags=re.S)
roles = {"alternate-base", "background", "base", "bright-text", "button",
         "button-text", "dark", "foreground", "highlight", "highlighted-text",
         "light", "link", "link-visited", "mid", "midlight", "shadow", "text",
         "tooltip-base", "tooltip-text", "window", "window-text", "marker-line",
         "sender-color-self"} | {f"sender-color-0{i:x}" for i in range(16)}
for decl, body in re.findall(r"(Palette[^{]*)\{([^}]+)\}", ss):
    if not re.fullmatch(r"Palette((:(normal|active|inactive|disabled))*)", decl.strip()):
        problems.append("bad palette declaration: " + decl)
    for line in filter(str.strip, body.split(";")):
        role = line.split(":", 1)[0].strip()
        if role not in roles:
            problems.append("unknown palette role: " + role)
ss = re.sub(r"(Palette[^{]*)\{([^}]+)\}", "", ss)
irc = set()
chatline = re.compile(r"ChatLine(?:::(\w+))?(?:#([\w\-]+))?(?:\[([=\-,\"\w\s]+)\])?")
item = re.compile(r"(Chat|Nick)ListItem(?:\[([=\-,\"\w\s]+)\])?")
for decl, body in re.findall(r"((?:ChatLine|ChatListItem|NickListItem)[^{]*)\{([^}]+)\}", ss):
    decl = decl.strip()
    if not (chatline.fullmatch(decl) or item.fullmatch(decl)):
        problems.append("bad declaration: " + decl)
    irc.update(re.findall(r"(fg|bg)-color=\"(0[0-9a-f])\"", decl))
    for line in filter(str.strip, body.split(";")):
        if not re.fullmatch(r"\s*(foreground|background): #[0-9a-f]{6}\s*", line):
            problems.append("bad property in " + decl + ": " + line.strip())
missing = {(k, f"0{i:x}") for k in ("fg", "bg") for i in range(16)} - irc
if missing:
    problems.append("IRC colors not set: " + ", ".join(sorted("-".join(m) for m in missing)))
rest = re.sub(r"((?:ChatLine|ChatListItem|NickListItem)[^{]*)\{([^}]+)\}", "", ss).split()
if " ".join(rest) != "ChatView { background: " + sys.argv[2] + "; }":
    problems.append("left for Qt: " + " ".join(rest))
print("\n".join(problems))
' "$(quassel_qss sunset)" "$(color bg)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# --- Tests: installing -------------------------------------------------------

QUASSEL_QSS="app-themes/quassel-theme/jenerated-blue-purple.qss"
QUASSEL_FLATPAK_DIR=".var/app/org.quassel_irc.QuasselClient/config/quassel-irc.org"

# GIVEN Linux
# WHEN choosing Quassel IRC and Blue Purple
# THEN the stylesheet is linked into a stylesheets folder in Quassel's
#      settings folder, and it says how to turn the stylesheet on
test_quassel_links_the_stylesheet() {
  fake_os Linux
  install_app quassel blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/quassel-irc.org/stylesheets/jenerated-blue-purple.qss" \
    "$SANDBOX/repo/$QUASSEL_QSS"
  assert_contains "Settings -> Configure Quassel... -> Interface"
  assert_contains '"Use custom stylesheet"'
  assert_contains "$SANDBOX/home/.config/quassel-irc.org/stylesheets/jenerated-blue-purple.qss"
}

# GIVEN a Mac
# WHEN choosing Quassel IRC and Blue Purple
# THEN the stylesheet goes in Quassel's folder in Application Support
test_quassel_on_macos_uses_application_support() {
  fake_os Darwin
  install_app quassel blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/Library/Application Support/Quassel/stylesheets/jenerated-blue-purple.qss" \
    "$SANDBOX/repo/$QUASSEL_QSS"
}

# GIVEN the Quassel Flatpak, which can't see files outside its own folder
# WHEN choosing Quassel IRC and Blue Purple, and linking
# THEN the usual settings folder gets a link, the Flatpak's gets a copy (a
#      file, not a link), and it says to run jenerate again after changing the
#      palette
test_quassel_copies_the_stylesheet_for_the_flatpak() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/org.quassel_irc.QuasselClient"
  install_app quassel blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/quassel-irc.org/stylesheets/jenerated-blue-purple.qss" \
    "$SANDBOX/repo/$QUASSEL_QSS"
  copy="$SANDBOX/home/$QUASSEL_FLATPAK_DIR/stylesheets/jenerated-blue-purple.qss"
  [ -f "$copy" ] && [ ! -L "$copy" ] || fail "expected a copy (not a link) at $copy"
  assert_same_file "$copy" "$SANDBOX/repo/$QUASSEL_QSS"
  assert_contains "run ./jenerate again for it"
}

# GIVEN the Quassel Flatpak
# WHEN choosing Quassel IRC and Blue Purple, and saying no to running the
#      install commands
# THEN nothing is installed, and it shows the command to copy the
#      stylesheet for the Flatpak too
test_quassel_flatpak_copy_is_shown_when_installing_by_hand() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/org.quassel_irc.QuasselClient"
  install_app quassel blue-purple "n\n"
  assert_status 0
  assert_missing "$SANDBOX/home/.config/quassel-irc.org"
  assert_missing "$SANDBOX/home/$QUASSEL_FLATPAK_DIR"
  assert_contains "cp \"$SANDBOX/repo/$QUASSEL_QSS\" \"\$HOME/$QUASSEL_FLATPAK_DIR/stylesheets/jenerated-blue-purple.qss\""
}

run_tests
