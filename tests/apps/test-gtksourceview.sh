#!/usr/bin/env bash
# Tests for GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-gtksourceview.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
# gsv_scheme slug version -> the GtkSourceView scheme for a version folder
# (gtksourceview-4, gtksourceview-5 or libgedit-gtksourceview-300).
gsv_scheme() { printf '%s' "$SANDBOX/repo/app-themes/gtksourceview-theme/$1/$2/jenerated-$1.xml"; }
GSV_VERSIONS="gtksourceview-4 gtksourceview-5 libgedit-gtksourceview-300"

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it and reading its three style schemes as XML
# THEN each is valid XML named after the palette, with the editor's text
#      and background, strings and keywords in the palette's colors
test_gtksourceview_schemes_use_the_palette() {
  generate sunset
  for version in $GSV_VERSIONS; do
    result="$("$PYTHON" -c '
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
styles = {s.get("name"): s for s in root.iter("style")}
print(root.get("id"), root.get("name"), styles["text"].get("foreground"), styles["text"].get("background"),
      styles["def:string"].get("foreground"), styles["def:keyword"].get("foreground"))
' "$(gsv_scheme sunset "$version")")"
    expected="jenerated-sunset Jenerated Sunset $(color text) $(color bg) $(color green) $(color accent_soft)"
    [ "$result" = "$expected" ] || fail "$version: expected '$expected', got '$result'"
  done
}

# GIVEN the Sunset palette, and a light palette
# WHEN generating them
# THEN each scheme follows its format's rules, which differ: GtkSourceView 3
#      and 4 need version="1.0" and refuse <metadata>; GtkSourceView 5 has
#      version="1.0" and <metadata> saying dark or light, with the colors
#      GNOME Text Editor recolors its window from; and gedit 47's
#      libgedit-gtksourceview needs kind="dark" or "light", and refuses any
#      attribute or element it doesn't know (such as version, author,
#      metadata, or underline-color, which it spells underline_color)
test_gtksourceview_schemes_follow_each_format() {
  write_light_palette daylight Daylight
  generate sunset,daylight
  assert_status 0
  OUTPUT="$("$PYTHON" -c '
import sys, xml.etree.ElementTree as ET
folder = sys.argv[1]
def load(slug, version):
    return ET.parse(f"{folder}/{slug}/{version}/jenerated-{slug}.xml").getroot()
for slug, scheme in (("sunset", "dark"), ("daylight", "light")):
    old = load(slug, "gtksourceview-4")
    if old.get("version") != "1.0": print(f"{slug} gtksourceview-4: needs version=1.0")
    if old.find("metadata") is not None: print(f"{slug} gtksourceview-4: has <metadata>")
    new = load(slug, "gtksourceview-5")
    if new.get("version") != "1.0": print(f"{slug} gtksourceview-5: needs version=1.0")
    meta = {p.get("name"): p.text for p in new.iter("property")}
    variant = meta.get("variant")
    if variant != scheme: print(f"{slug} gtksourceview-5: variant is {variant}, not {scheme}")
    for key in ("window_bg_color", "headerbar_bg_color", "sidebar_bg_color", "popover_bg_color", "accent_bg_color", "accent_fg_color"):
        if not (meta.get(key) or "").startswith("#"): print(f"{slug} gtksourceview-5: no {key}")
    gedit = load(slug, "libgedit-gtksourceview-300")
    kind = gedit.get("kind")
    if kind != scheme: print(f"{slug} libgedit: kind is {kind}, not {scheme}")
    extra = set(gedit.attrib) - {"id", "name", "_name", "kind"}
    if extra: print(f"{slug} libgedit: <style-scheme> has {sorted(extra)}")
    for child in gedit:
        if child.tag not in ("description", "_description", "color", "style"):
            print(f"{slug} libgedit: has <{child.tag}>")
        allowed = {"style": {"name", "foreground", "background", "italic", "bold", "underline", "underline_color",
                             "strikethrough", "scale", "use-style"}, "color": {"name", "value"}}.get(child.tag, set())
        name = child.get("name")
        for attribute in set(child.attrib) - allowed:
            print(f"{slug} libgedit: <{child.tag} name={name}> has {attribute}")
' "$SANDBOX/repo/app-themes/gtksourceview-theme")"
  [ -z "$OUTPUT" ] || fail "$OUTPUT"
}

# GIVEN the three style scheme templates
# WHEN comparing their <style> lines (treating gedit's underline_color as
#      underline-color)
# THEN they're the same, so the editors all show a palette the same way
test_gtksourceview_templates_share_their_styles() {
  folder="$SANDBOX/repo/app-themes/gtksourceview-theme"
  grep '<style ' "$folder/gtksourceview-4.xml.tmpl" >"$SANDBOX/styles-4"
  for template in gtksourceview-5.xml.tmpl libgedit.xml.tmpl; do
    grep '<style ' "$folder/$template" | sed 's/underline_color=/underline-color=/g' >"$SANDBOX/styles-other"
    if ! cmp -s "$SANDBOX/styles-4" "$SANDBOX/styles-other"; then
      fail "$template's styles differ from gtksourceview-4.xml.tmpl's:
$(diff "$SANDBOX/styles-4" "$SANDBOX/styles-other")"
    fi
  done
}

# GIVEN the Sunset palette, and GtkSourceView 4's Python bindings
# WHEN generating it and loading its GtkSourceView 4 scheme with the real
#      library
# THEN it loads, with the palette's colors
test_gtksourceview_4_scheme_loads_in_gtksourceview() {
  "$PYTHON" -c 'import gi; gi.require_version("GtkSource", "4")' 2>/dev/null || return 0
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import sys, gi
gi.require_version("GtkSource", "4")
from gi.repository import GtkSource
manager = GtkSource.StyleSchemeManager()
manager.set_search_path([sys.argv[1]])
scheme = manager.get_scheme("jenerated-sunset")
if scheme is None:
    print("not loaded")
else:
    style = scheme.get_style("def:string")
    print(scheme.get_name(), style.props.foreground.lower())
' "$SANDBOX/repo/app-themes/gtksourceview-theme/sunset/gtksourceview-4" 2>&1)"
  expected="Jenerated Sunset $(color green | tr 'A-F' 'a-f')"
  [ "$OUTPUT" = "$expected" ] || fail "expected '$expected'"
}

# GIVEN the Sunset palette, and GtkSourceView 5's library
# WHEN generating it and loading its GtkSourceView 5 scheme with the real
#      library
# THEN it loads, saying it's dark, with its header bar color for GNOME Text
#      Editor
test_gtksourceview_5_scheme_loads_in_gtksourceview() {
  "$PYTHON" -c 'import ctypes; ctypes.CDLL("libgtksourceview-5.so.0")' 2>/dev/null || return 0
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import ctypes, sys
lib = ctypes.CDLL("libgtksourceview-5.so.0")
lib.gtk_source_init()
p, s = ctypes.c_void_p, ctypes.c_char_p
lib.gtk_source_style_scheme_manager_new.restype = p
lib.gtk_source_style_scheme_manager_set_search_path.argtypes = [p, ctypes.POINTER(s)]
lib.gtk_source_style_scheme_manager_get_scheme.restype = p
lib.gtk_source_style_scheme_manager_get_scheme.argtypes = [p, s]
lib.gtk_source_style_scheme_get_name.restype = s
lib.gtk_source_style_scheme_get_name.argtypes = [p]
lib.gtk_source_style_scheme_get_metadata.restype = s
lib.gtk_source_style_scheme_get_metadata.argtypes = [p, s]
manager = lib.gtk_source_style_scheme_manager_new()
lib.gtk_source_style_scheme_manager_set_search_path(manager, (s * 2)(sys.argv[1].encode(), None))
scheme = lib.gtk_source_style_scheme_manager_get_scheme(manager, b"jenerated-sunset")
if not scheme:
    print("not loaded")
else:
    print(lib.gtk_source_style_scheme_get_name(scheme).decode(),
          lib.gtk_source_style_scheme_get_metadata(scheme, b"variant").decode(),
          lib.gtk_source_style_scheme_get_metadata(scheme, b"headerbar_bg_color").decode())
' "$SANDBOX/repo/app-themes/gtksourceview-theme/sunset/gtksourceview-5" 2>&1)"
  expected="Jenerated Sunset dark $(color bg_chrome)"
  [ "$OUTPUT" = "$expected" ] || fail "expected '$expected'"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its style scheme folders are deleted, and the templates are kept
test_remove_deletes_the_gtksourceview_schemes() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/gtksourceview-theme/sunset/gtksourceview-5/jenerated-sunset.xml"
  assert_missing "$SANDBOX/repo/app-themes/gtksourceview-theme/sunset"
  assert_exists "$SANDBOX/repo/app-themes/gtksourceview-theme/libgedit.xml.tmpl"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system
# WHEN choosing the text editors and Blue Purple (a dark palette)
# THEN each GtkSourceView version's styles folder gets a link to its own
#      version of the scheme (3 and 4 share one), and it explains where each
#      editor's setting is, telling GNOME Text Editor users to pick its dark
#      style
test_gtksourceview_links_each_version() {
  fake_os Linux
  install_app gtksourceview blue-purple "y\n1\n"
  assert_status 0
  data="$SANDBOX/home/.local/share"
  folder="$SANDBOX/repo/app-themes/gtksourceview-theme/blue-purple"
  file="jenerated-blue-purple.xml"
  assert_link "$data/gtksourceview-3.0/styles/$file" "$folder/gtksourceview-4/$file"
  assert_link "$data/gtksourceview-4/styles/$file" "$folder/gtksourceview-4/$file"
  assert_link "$data/gtksourceview-5/styles/$file" "$folder/gtksourceview-5/$file"
  assert_link "$data/libgedit-gtksourceview-300/styles/$file" "$folder/libgedit-gtksourceview-300/$file"
  assert_contains "gedit: Preferences -> Font & Colors."
  assert_contains "Xed: Edit -> Preferences -> Theme."
  assert_contains "choose the dark style first"
  assert_missing "$SANDBOX/home/.var"
}

# GIVEN a light palette
# WHEN choosing the text editors and it
# THEN it tells GNOME Text Editor users to pick its light style
test_gtksourceview_light_palette_says_light_style() {
  fake_os Linux
  sed -e 's/^name = .*/name = "Dawn"/' -e 's/^slug = .*/slug = "dawn"/' \
    -e 's/^bg = "#[0-9a-fA-F]*"/bg = "#fbfbfd"/' "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/dawn-palette.toml"
  install_app gtksourceview dawn "y\n1\n"
  assert_status 0
  assert_contains "Jenerated Dawn"
  assert_contains "choose the light style first"
}

# GIVEN GNOME Text Editor and gedit installed through Flatpak
# WHEN choosing the text editors
# THEN their own data folders get links too
test_gtksourceview_themes_the_flatpaks() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.var/app/org.gnome.TextEditor" "$SANDBOX/home/.var/app/org.gnome.gedit"
  install_app gtksourceview blue-purple "y\n1\n"
  assert_status 0
  folder="$SANDBOX/repo/app-themes/gtksourceview-theme/blue-purple"
  assert_link "$SANDBOX/home/.var/app/org.gnome.TextEditor/data/gtksourceview-5/styles/jenerated-blue-purple.xml" \
    "$folder/gtksourceview-5/jenerated-blue-purple.xml"
  assert_link "$SANDBOX/home/.var/app/org.gnome.gedit/data/libgedit-gtksourceview-300/styles/jenerated-blue-purple.xml" \
    "$folder/libgedit-gtksourceview-300/jenerated-blue-purple.xml"
}

run_tests
