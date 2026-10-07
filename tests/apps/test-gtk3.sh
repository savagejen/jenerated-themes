#!/usr/bin/env bash
# Tests for GTK3 apps (GIMP, Inkscape, Thunar, GParted and more): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-gtk3.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

PYTHON="$(find_python)"
gtk3_theme() { printf '%s' "$SANDBOX/repo/app-themes/gtk3-theme/$1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the GTK3 theme builds on GTK's dark Adwaita, uses Sunset's colors, and
#      is named after the palette, with its folder name as the theme name
test_gtk3_theme_uses_the_palette() {
  generate sunset
  css="$(gtk3_theme sunset)/gtk-3.0/gtk.css"
  assert_file_contains "$css" '@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");'
  assert_file_contains "$css" "@define-color theme_selected_bg_color $(color accent);"
  assert_file_contains "$css" "background-image: image($(color bg_chrome));"
  assert_file_contains "$css" "button.suggested-action, button.suggested-action:backdrop {"
  assert_file_contains "$(gtk3_theme sunset)/index.theme" "Name=Jenerated Sunset"
  assert_file_contains "$(gtk3_theme sunset)/index.theme" "GtkTheme=Jenerated-sunset"
}

# GIVEN the Sunset palette, and GTK3's Python bindings
# WHEN generating it and loading its CSS with GTK's own parser
# THEN GTK reports no errors (including in the Adwaita theme it imports)
test_gtk3_theme_parses_in_gtk() {
  "$PYTHON" -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' 2>/dev/null || return 0
  generate sunset
  OUTPUT="$("$PYTHON" -c '
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib
provider, errors = Gtk.CssProvider(), []
provider.connect("parsing-error", lambda p, s, e: errors.append(f"line {s.get_start_line() + 1}: {e.message}"))
try:
    provider.load_from_path(sys.argv[1])
except GLib.Error as e:
    errors.append(e.message)
print("\n".join(errors) or "no errors")
' "$(gtk3_theme sunset)/gtk-3.0/gtk.css" 2>&1)"
  assert_contains "no errors"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its GTK3 theme folder is deleted, including gtk-3.0 inside it
test_remove_deletes_the_gtk3_theme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/gtk3-theme/sunset/gtk-3.0/gtk.css"
  assert_missing "$(gtk3_theme sunset)"
  assert_exists "$SANDBOX/repo/app-themes/gtk3-theme/gtk.css.tmpl"
}

# --- Tests: installing -------------------------------------------------------

GTK3_THEMES=".local/share/themes"

# fake_gsettings current-theme -> fakes a working gsettings: `get` prints the
# theme, and `set` records its arguments in $SANDBOX/gsettings-set.
fake_gsettings() {
  fake_command gsettings "case \"\$1\" in
  get) echo \"'$1'\" ;;
  set) printf '%s\n' \"\$*\" >\"$SANDBOX/gsettings-set\" ;;
esac"
}

# GIVEN a Linux system without GNOME's settings tool
# WHEN choosing GTK3 apps and Blue Purple
# THEN the theme is linked into ~/.local/share/themes as Jenerated-blue-purple,
#      and it explains how to turn it on
test_gtk3_links_the_theme() {
  fake_os Linux
  install_app gtk3 blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple" "$SANDBOX/repo/app-themes/gtk3-theme/blue-purple"
  assert_exists "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple/gtk-3.0/gtk.css"
  assert_contains "gsettings set org.gnome.desktop.interface gtk-theme Jenerated-blue-purple"
  assert_contains "GTK_THEME=Jenerated-blue-purple"
}

# GIVEN GNOME's settings tool, with Yaru-dark as the GTK3 theme
# WHEN choosing GTK3 apps and Sunset, and answering yes to switching
# THEN the GTK3 theme is set to Jenerated-sunset, and it says how to switch
#      back to Yaru-dark
test_gtk3_switches_the_theme_when_asked() {
  fake_os Linux
  fake_gsettings Yaru-dark
  install_app gtk3 sunset "y\n1\ny\n"
  assert_status 0
  assert_contains "Your GTK3 theme is 'Yaru-dark'."
  assert_file_equals "$SANDBOX/gsettings-set" "set org.gnome.desktop.interface gtk-theme Jenerated-sunset"
  assert_contains "gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'"
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-sunset" "$SANDBOX/repo/app-themes/gtk3-theme/sunset"
}

# GIVEN GNOME's settings tool
# WHEN choosing GTK3 apps and answering no to switching
# THEN the theme is installed but the setting is left alone
test_gtk3_leaves_the_theme_setting_when_declined() {
  fake_os Linux
  fake_gsettings Yaru-dark
  install_app gtk3 blue-purple "y\n1\nn\n"
  assert_status 0
  assert_missing "$SANDBOX/gsettings-set"
  assert_link "$SANDBOX/home/$GTK3_THEMES/Jenerated-blue-purple" "$SANDBOX/repo/app-themes/gtk3-theme/blue-purple"
  assert_contains "Legacy Applications"
}

run_tests
