#!/usr/bin/env bash
# Tests for Jellyfin (media server): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-jellyfin.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
jellyfin_css() { printf '%s' "$SANDBOX/repo/app-themes/jellyfin-theme/jenerated-$1.css"; }

# --- Tests: making the theme -------------------------------------------------

# jellyfin_var path name -> prints the value of the CSS's --jf-name variable.
jellyfin_var() { sed -n "s/^ *--jf-$2: *\(.*\);$/\1/p" "$1"; }

# GIVEN the Sunset palette
# WHEN generating it
# THEN its Jellyfin CSS sets Jellyfin's page, panel, text, accent and error
#      colors from the palette, for whichever of Jellyfin's themes is chosen
test_jellyfin_css_uses_the_palette() {
  generate sunset
  css="$(jellyfin_css sunset)"
  assert_file_contains "$css" ":root[data-theme] {"
  for pair in "palette-background-default bg" "palette-background-paper bg_widget" \
    "palette-text-primary text" "palette-primary-main accent" \
    "palette-primary-contrastText text_bright" "palette-secondary-main accent_soft" \
    "palette-error-main red" "palette-AppBar-defaultBg bg_chrome"; do
    set -- $pair
    [ "$(jellyfin_var "$css" "$1")" = "$(color "$2")" ] ||
      fail "expected --jf-$1 to be $(color "$2"), got '$(jellyfin_var "$css" "$1")'"
  done
}

# GIVEN the Sunset palette
# WHEN generating its Jellyfin CSS
# THEN its braces balance, every variable is Jellyfin's (--jf-...), each
#      ...Channel variable is the "r g b" form of the color it goes with (as
#      Jellyfin writes rgb(var(...Channel) / alpha)), and every color is a
#      #rrggbb or a valid rgba()
test_jellyfin_css_follows_the_format() {
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import re, sys
css = re.sub(r"/\*.*?\*/", "", open(sys.argv[1]).read(), flags=re.S)
if css.count("{") != css.count("}"):
    print("unbalanced braces")
decls = dict(re.findall(r"(--[\w-]+):\s*([^;]+);", css))
for name, value in decls.items():
    if not name.startswith("--jf-"):
        print(f"{name} is not a Jellyfin variable")
    if name.endswith("Channel"):
        base = decls.get(name[:-len("Channel")])
        if not re.fullmatch(r"\d{1,3} \d{1,3} \d{1,3}", value):
            print(f"{name} is {value}")
        elif base is None:
            print(f"{name} has no color to go with")
        elif " ".join(str(int(base[i:i + 2], 16)) for i in (1, 3, 5)) != value:
            print(f"{name} is {value}, but its color is {base}")
for value in re.findall(r"#[0-9a-zA-Z]+", css):
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        print(f"bad color {value}")
for args in re.findall(r"rgba\(([^)]*)\)", css):
    parts = [p.strip() for p in args.split(",")]
    if len(parts) != 4 or not all(p.isdigit() and int(p) < 256 for p in parts[:3]) or not 0 <= float(parts[3]) <= 1:
        print(f"bad rgba({args})")
if "var(" in css:
    print("uses var()")
' "$(jellyfin_css sunset)")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Jellyfin CSS is deleted, and the template is kept
test_remove_deletes_the_jellyfin_css() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/jellyfin-theme/jenerated-sunset.css"
  assert_missing "$(jellyfin_css sunset)"
  assert_exists "$SANDBOX/repo/app-themes/jellyfin-theme/theme.css.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Jellyfin and Blue Purple
# THEN the CSS is copied to the clipboard, it says where the file is, and it
#      explains both places to paste it
test_jellyfin_copies_the_css() {
  fake_os Linux
  install_app jellyfin blue-purple
  assert_status 0
  assert_contains "app-themes/jellyfin-theme/jenerated-blue-purple.css"
  assert_contains "(Copied to your clipboard.)"
  assert_same_file "$SANDBOX/clipboard" "$SANDBOX/repo/app-themes/jellyfin-theme/jenerated-blue-purple.css"
  assert_contains "Dashboard -> Branding"
  assert_contains "Settings -> Display"
}

run_tests
