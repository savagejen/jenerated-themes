#!/usr/bin/env bash
# Tests for the menus: what ./setup.sh (which hands over to jenerate) asks,
# from the first menu through choosing an app and a palette, searching, ALL
# THE APPS and ALL THE PALETTES, its shortcuts, and showing the install
# commands. Each app's own install steps are tested in tests/apps/.
#
# Usage: tests/menus/test-menus.sh [part of a test's name]
#
# Each test runs from a throwaway copy of the repository, with HOME pointed
# at an empty folder, so nothing outside the sandbox is touched.

source "$(dirname "$0")/../lib.sh"

after_sandbox() {
  quiet_desktop
}

# palette_name file -> prints a palette's name, read with Python's TOML parser.
palette_name() {
  "$(find_python)" -c '
import sys, tomllib
print(tomllib.load(open(sys.argv[1], "rb"))["name"])
' "$1"
}

# --- Tests: menus ------------------------------------------------------------

# GIVEN a Linux system
# WHEN setup.sh shows the app menu
# THEN it lists the categories with how many apps each has ("1 app" for
#      one), then ALL THE APPS, then search, and a way back
test_app_menu_on_linux_groups_the_apps() {
  fake_os Linux
  run_setup "1\n2\n4\n1\n"
  assert_status 0
  assert_contains "Which app do you want to theme?
  1) Web browsers (4 apps)
  2) Communication (4 apps)
  3) Editors: code, text and notes (13 apps)
  4) Terminals and command-line tools (8 apps)
  5) Linux desktops (4 apps)
  6) Entertainment (4 apps)
  7) Art and design (1 app)
  8) Hacking and testing tools (6 apps)
  9) ALL THE APPS
  10) Search for an app by name
  0) Back"
  assert_contains "Your Slack theme string"
}

# GIVEN a Mac
# WHEN setup.sh shows the app menu
# THEN the Linux-only apps are left out of the categories, and the Linux
#      desktops category, which has none left, isn't shown
test_app_menu_on_macos_leaves_out_linux_apps() {
  fake_os Darwin
  run_setup "1\n2\n4\n1\n"
  assert_status 0
  assert_contains "Which app do you want to theme?
  1) Web browsers (4 apps)
  2) Communication (4 apps)
  3) Editors: code, text and notes (13 apps)
  4) Terminals and command-line tools (5 apps)
  5) Entertainment (4 apps)
  6) Art and design (1 app)
  7) Hacking and testing tools (6 apps)
  8) ALL THE APPS
  9) Search for an app by name
  0) Back"
  assert_contains "Your Slack theme string"
  assert_not_contains "Linux desktops"
}

# GIVEN a Linux system
# WHEN opening each category from the app menu, then going back
# THEN each lists its apps, alphabetically, with a way back, and Back
#      returns to the app menu each time
test_each_category_lists_its_apps() {
  fake_os Linux
  run_setup "1\n1\n0\n2\n0\n3\n0\n4\n0\n5\n0\n6\n0\n7\n0\n8\n3\n1\n"
  assert_status 0
  assert_contains "Communication:
  1) Element (Matrix chat)
  2) Mattermost
  3) Quassel IRC
  4) Slack
  0) Back"
  assert_contains "Web browsers:
  1) Chromium browsers (Chrome, Brave, Edge, Opera and more)
  2) Firefox
  3) Vivaldi
  4) Zen Browser
  0) Back"
  assert_contains "Editors: code, text and notes:
  1) Emacs
  2) GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)
  3) Godot
  4) JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)
  5) LibreOffice (Writer, Calc, Impress and more)
  6) Obsidian
  7) Qt Creator
  8) RStudio
  9) Spyder
  10) Sublime Text
  11) Unreal Engine
  12) Vim / Neovim
  13) VS Code (and Code - OSS, VSCodium)
  0) Back"
  assert_contains "Terminals and command-line tools:
  1) fzf (fuzzy finder)
  2) Gemini CLI
  3) PowerShell (pwsh)
  4) Ptyxis (Ubuntu terminal)
  5) QTerminal (LXQt's and Kali's terminal)
  6) Tilix (terminal)
  7) tmux
  8) zsh (syntax highlighting and suggestions)
  0) Back"
  assert_contains "Linux desktops:
  1) Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)
  2) GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)
  3) KDE Plasma (Plasma and KDE apps, Konsole, Kate)
  4) Qt apps outside KDE Plasma (qt5ct and qt6ct)
  0) Back"
  assert_contains "Entertainment:
  1) Jellyfin (media server)
  2) mpv (media player)
  3) OBS Studio (streaming and recording)
  4) Veilamp (music player)
  0) Back"
  assert_contains "Art and design:
  1) Krita (painting)
  0) Back"
  assert_contains "Hacking and testing tools:
  1) Caido (web security testing)
  2) Ghidra (reverse engineering)
  3) Insomnia (API client)
  4) radare2 (reverse engineering)
  5) rizin (reverse engineering)
  6) Wireshark (network analyzer)
  0) Back"
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^Which app do you want to theme?$')"
  [ "$count" -eq 8 ] || fail "expected the app menu 8 times (once, then after each Back), got $count"
}

# GIVEN a category open
# WHEN choosing an app from it
# THEN that app is installed
test_choosing_an_app_from_a_category() {
  fake_os Linux
  run_setup "1\n4\n7\n1\n"
  assert_status 0
  assert_contains "Installing the tmux colors"
}

# GIVEN the app menu
# WHEN typing part of a name instead of a number
# THEN it lists the apps whose name, or category, match (case doesn't
#      matter), and one can be chosen from them
test_typing_a_name_searches() {
  fake_os Linux
  run_setup "1\nCOMMAND-LINE\n7\n1\n"
  assert_status 0
  assert_contains "Apps matching \"COMMAND-LINE\":
  1) fzf (fuzzy finder)
  2) Gemini CLI
  3) PowerShell (pwsh)
     Covers: PSReadLine
  4) Ptyxis (Ubuntu terminal)
  5) QTerminal (LXQt's and Kali's terminal)
  6) Tilix (terminal)
  7) tmux
  8) zsh (syntax highlighting and suggestions)
     Covers: zsh-syntax-highlighting, fast-syntax-highlighting,
     zsh-autosuggestions
  0) Back"
  assert_contains "Installing the tmux colors"
}

# GIVEN the app menu
# WHEN searching for apps a theme covers but its menu name doesn't list:
#      RustRover, Dolphin and Brave
# THEN each finds the theme that covers it (JetBrains, KDE Plasma and
#      Chromium browsers), with the full list of apps it covers under it,
#      wrapped and lined up with its name
test_search_finds_apps_a_theme_covers() {
  fake_os Linux
  run_setup "1\nrustrover\n0\ndolphin\n0\nbrave\n1\n1\n"
  assert_status 0
  assert_contains 'Apps matching "rustrover":
  1) JetBrains Apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)
     Covers: IntelliJ IDEA, Android Studio, PyCharm, WebStorm, PhpStorm,
     GoLand, RubyMine, CLion, Rider, DataGrip, DataSpell, RustRover
  0) Back'
  assert_contains 'Apps matching "dolphin":
  1) KDE Plasma (Plasma and KDE apps, Konsole, Kate)
     Covers: Dolphin, Kate, KWrite, Okular, Konsole, System Settings
  0) Back'
  assert_contains 'Apps matching "brave":
  1) Chromium browsers (Chrome, Brave, Edge, Opera and more)
     Covers: Google Chrome, Chromium, Brave, Microsoft Edge, Opera
  0) Back'
}

# GIVEN the app menu and a category
# WHEN they're shown
# THEN they don't list the apps each theme covers (only search results do)
test_menus_leave_out_the_covered_apps() {
  fake_os Linux
  run_setup "1\n2\n0\nslack\n1\n1\n"
  assert_status 0
  assert_not_contains "Covers:"
}

# GIVEN the JetBrains theme's README, which lists the IDEs it supports
# WHEN searching for each of them
# THEN every one finds the JetBrains theme
test_search_finds_every_jetbrains_ide() {
  fake_os Linux
  ides="$(sed -n '/^Themes for the JetBrains apps/,/^(Not Fleet/s/^- //p' "$SANDBOX/repo/app-themes/jetbrains-theme/README.md")"
  [ -n "$ides" ] || fail "expected the README to list the IDEs"
  answers="1\n"
  while IFS= read -r ide; do answers="$answers$ide\n0\n"; done <<<"$ides"
  run_setup "${answers}slack\n1\n1\n"
  assert_status 0
  while IFS= read -r ide; do
    assert_contains "Apps matching \"$ide\":
  1) JetBrains Apps"
  done <<<"$ides"
  # The Covers list shown in search results names them all too.
  covers="$(printf '%s\n' "$OUTPUT" | sed -n '/^Apps matching "RustRover":$/,/^  0) Back$/p' | sed -n '/Covers:/,/0) Back/p' | tr '\n' ' ')"
  while IFS= read -r ide; do
    case "$covers" in *"$ide"*) ;; *) fail "expected the Covers list to name $ide" ;; esac
  done <<<"$ides"
}

# GIVEN an app two themes cover: gedit, whose text area the GNOME text
#       editors theme colors and whose window the GTK3 theme colors
# WHEN searching for it
# THEN both are listed
test_search_lists_every_theme_for_an_app() {
  fake_os Linux
  run_setup "1\ngedit\n0\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'Apps matching "gedit":
  1) GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)
     Covers: gedit, GNOME Text Editor, Xed, Pluma, Meld
  2) GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)
     Covers: GIMP, Inkscape, Shotwell, Thunar, Nemo, Caja, gedit,'
}

# GIVEN the app menu
# WHEN choosing "Search for an app by name" and typing a name
# THEN it lists the matching apps
test_search_option_asks_for_a_name() {
  fake_os Linux
  run_setup "1\n10\nfire\n1\n1\n"
  assert_status 0
  assert_contains "Type part of an app's name (or press Enter to go back): "
  assert_contains 'Apps matching "fire":
  1) Firefox
  0) Back'
}

# GIVEN the app menu
# WHEN searching for something no app matches, then for Slack
# THEN it says nothing matches and shows the app menu again, where the next
#      search works
test_search_with_no_matches_returns_to_the_app_menu() {
  fake_os Linux
  run_setup "1\nnotepad\nslack\n1\n1\n"
  assert_status 0
  assert_contains 'No app matches "notepad".'
  assert_contains "Your Slack theme string"
}

# GIVEN the app menu
# WHEN choosing Back
# THEN it returns to the first question, where installing starts over
test_back_from_the_app_menu_returns_to_the_first_question() {
  fake_os Linux
  run_setup "1\n0\n1\nslack\n1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^What would you like to do?$')"
  [ "$count" -eq 2 ] || fail "expected the first question twice, got $count"
  assert_contains "Your Slack theme string"
}

# GIVEN an app chosen from a category
# WHEN choosing Back at the theme menu
# THEN it returns to that category, where another app can be chosen
test_back_from_the_theme_menu_returns_to_the_category() {
  fake_os Linux
  run_setup "1\n1\n2\n0\n1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c '^Web browsers:$')"
  [ "$count" -eq 2 ] || fail "expected the browsers category twice, got $count"
  assert_contains "chrome://extensions"
  assert_not_contains "about:debugging"
}

# GIVEN the palettes in palettes/Dark
# WHEN choosing an app
# THEN the theme menu lists every palette by name
test_theme_menu_lists_every_palette() {
  run_setup "1\nslack\n1\n1\n"
  for file in "$SANDBOX"/repo/palettes/Dark/*-palette.toml; do
    assert_contains ") $(palette_name "$file")"
  done
}

# GIVEN a new Forest palette in palettes/
# WHEN choosing an app
# THEN the theme menu lists Forest
test_theme_menu_lists_a_new_palette() {
  sed -e 's/^name = .*/name = "Forest"/' -e 's/^slug = .*/slug = "forest"/' \
    "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" \
    >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "1\nslack\n1\n1\n"
  assert_contains ") Forest"
}

# GIVEN a Forest palette whose name and slug use TOML's single quotes
# WHEN choosing Slack and Forest
# THEN Forest is listed by name and generated
test_theme_menu_reads_single_quoted_names() {
  sed -e "s/^name = .*/name = 'Forest'/" -e "s/^slug = .*/slug = 'forest'/" \
    "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" >"$SANDBOX/repo/palettes/forest-palette.toml"
  run_setup "1\nslack\n1\n2\n"
  assert_status 0
  assert_contains "2) Forest"
  assert_contains "Generated Forest (forest)"
}

# GIVEN dark palettes and a light one, Dawn
# WHEN choosing Slack, then Light
# THEN it asks for dark or light before the palettes, lists only Dawn, and
#      generates it
test_theme_menu_asks_dark_or_light() {
  dawn_palette Light
  run_setup "1\nslack\n1\n2\n1\n"
  assert_status 0
  assert_contains "Do you want a dark or light theme?
  1) Dark
  2) Light
  3) Preview the palettes (opens in your browser)
  0) Back"
  assert_contains "Which theme do you want?
  1) Dawn
  0) Back"
  assert_contains "Generated Dawn (dawn)"
}

# GIVEN dark palettes and a light one
# WHEN choosing Light, going back, then choosing Dark and Sunset
# THEN Back from the palettes asks dark or light again, and the dark list has
#      only the dark palettes
test_theme_menu_back_goes_to_dark_or_light() {
  dawn_palette Light
  run_setup "1\nslack\n1\n2\n0\n1\n2\n"
  assert_status 0
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'Do you want a dark or light theme?')" = "2" ] ||
    fail "expected the dark or light question twice"
  assert_contains "Which theme do you want?
  1) Blue Purple
  2) Sunset
  0) Back"
  assert_contains "Generated Sunset (sunset)"
}

# GIVEN dark palettes and a light one
# WHEN searching for Slack, choosing it, then going back from the dark or
#      light question
# THEN the search results are shown again
test_dark_or_light_back_goes_to_the_app_menu() {
  dawn_palette Light
  run_setup "1\nslack\n1\n0\n1\n1\n1\n"
  assert_status 0
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'Apps matching "slack":')" = "2" ] ||
    fail "expected the search results twice"
  assert_contains "Your Slack theme string"
}

# GIVEN dark palettes and a light one, on Linux with xdg-open (faked, so no
#       real browser opens)
# WHEN choosing Preview, then Light and Dawn
# THEN xdg-open is given the palettes README on GitHub, the address is
#      printed, and the same question is asked again, where Light still works
test_preview_opens_the_palettes_readme_and_asks_again() {
  fake_os Linux
  fake_command xdg-open "printf '%s' \"\$*\" >\"$SANDBOX/xdg-open-ran\""
  dawn_palette Light
  run_setup "1\nslack\n1\n3\n2\n1\n"
  assert_status 0
  wait_for "$SANDBOX/xdg-open-ran"
  assert_file_equals "$SANDBOX/xdg-open-ran" \
    "https://github.com/savagejen/jenerated-themes/blob/main/palettes/README.md"
  assert_contains "Opening the palette previews in your browser:
  https://github.com/savagejen/jenerated-themes/blob/main/palettes/README.md"
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'Do you want a dark or light theme?')" = "2" ] ||
    fail "expected the dark or light question again after Preview"
  assert_contains "Generated Dawn (dawn)"
}

# GIVEN dark palettes and a light one, on a Mac
# WHEN choosing Preview, then Dark and Blue Purple
# THEN it opens the palettes README with `open`
test_preview_on_macos_uses_open() {
  fake_os Darwin
  fake_command open "printf '%s' \"\$*\" >\"$SANDBOX/open-ran\""
  dawn_palette Light
  run_setup "1\nslack\n1\n3\n1\n1\n"
  assert_status 0
  assert_file_equals "$SANDBOX/open-ran" \
    "https://github.com/savagejen/jenerated-themes/blob/main/palettes/README.md"
  assert_contains "Your Slack theme string"
}

# GIVEN dark palettes and a light one, where the browser can't be opened
# WHEN choosing Preview, then Dark and Blue Purple
# THEN it prints the address to open instead, and asks again
test_preview_without_a_browser_prints_the_address() {
  fake_os Darwin
  fake_command open "exit 1"
  dawn_palette Light
  run_setup "1\nslack\n1\n3\n1\n1\n"
  assert_status 0
  assert_contains "Open the palette previews in your browser:
  https://github.com/savagejen/jenerated-themes/blob/main/palettes/README.md"
  assert_contains "Your Slack theme string"
}

# fake_outside_commands -> fakes the commands an install uses outside the
# sandbox's home folder (tmux's running server, LibreOffice's unopkg), so an
# ALL THE APPS run can't touch the real ones.
fake_outside_commands() {
  fake_command tmux "exit 1"
  fake_command unopkg "exit 1"
}

# GIVEN Linux, with Tilix, tmux and VS Code found on this computer
# WHEN choosing ALL THE APPS and Blue Purple, then saying no
# THEN it lists the three found, the automated apps not found, and the
#      manual ones it leaves out, asks with no as the default, installs
#      nothing, and goes back to the first menu, where installing one app
#      still works
test_all_the_apps_lists_the_apps_and_asks_first() {
  fake_os Linux
  fake_outside_commands
  export SETUP_FOUND_APPS="tilix tmux vscode"
  run_setup "1\n9\n1\nn\n1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "==> ALL THE APPS
This installs Jenerated Blue Purple into all 3 of these apps, with no"
  assert_contains "  - VS Code (and Code - OSS, VSCodium)
  - Tilix (terminal)
  - tmux

These weren't found on this computer, so they're left out:"
  assert_contains "  - Sublime Text"
  assert_contains "Manual installs aren't included."
  assert_contains "  - Slack"
  assert_contains "  - Firefox"
  assert_contains "Install into all 3 apps? [y/N]"
  assert_not_contains "ALL THE APPS: Tilix"
  assert_missing "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json"
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'What would you like to do?')" = "2" ] ||
    fail "expected the first menu again after saying no"
  assert_contains "Your Slack theme string"
}

# GIVEN Linux, with Obsidian (but no vault), VS Code and Tilix found
# WHEN choosing ALL THE APPS and Blue Purple, and saying yes
# THEN the found apps are installed without another question, each question
#      showing its automatic answer, and nothing is installed for apps that
#      weren't found; the summary lists the 2 installed, then as not
#      installed Obsidian (which needs a vault typed in; status 1) and the
#      manual apps, which may need doing by hand, then the apps not found
test_all_the_apps_installs_into_every_automated_app() {
  fake_os Linux
  fake_outside_commands
  export SETUP_FOUND_APPS="obsidian vscode tilix"
  run_setup "1\n9\n1\ny\n"
  assert_status 1
  assert_contains "==> ALL THE APPS: Tilix (terminal) (3 of 3)"
  assert_contains "Run these for you? [Y/n] y (automatic)"
  assert_contains "Enter a number (1-2): 1 (automatic)"
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_link "$SANDBOX/home/.vscode/extensions/jenerated-themes" "$SANDBOX/repo/app-themes/vs-code-theme"
  assert_contains "==> ALL THE APPS: done
Installed Jenerated Blue Purple into:
  - VS Code (and Code - OSS, VSCodium)
  - Tilix (terminal)

Not installed:
  - Obsidian
  - Chromium browsers (Chrome, Brave, Edge, Opera and more)"
  assert_contains "  - Jellyfin (media server)
  - Caido (web security testing)

These may need to be done by hand. Run ./setup.sh again and choose each"
  assert_contains "Not found on this computer, so left out:"
  assert_contains "  - Sublime Text"
  assert_missing "$SANDBOX/home/.config/sublime-text"
  assert_missing "$SANDBOX/home/.config/tmux"
  assert_not_contains "Your Slack theme string"
}

# GIVEN a Mac
# WHEN choosing ALL THE APPS
# THEN only the apps that run on macOS are included
test_all_the_apps_on_macos_leaves_out_linux_apps() {
  fake_os Darwin
  fake_outside_commands
  export SETUP_FOUND_APPS="xcode vscode"
  run_setup "1\n8\n1\nn\n1\nslack\n1\n1\n"
  assert_contains "==> ALL THE APPS"
  assert_contains "  - Xcode"
  assert_not_contains "Tilix"
  assert_not_contains "KDE Plasma"
}

# GIVEN none of the automated apps found on this computer
# WHEN choosing ALL THE APPS and Blue Purple
# THEN it says so without asking anything, and goes back to the first menu
test_all_the_apps_with_none_found_goes_back() {
  fake_os Linux
  export SETUP_FOUND_APPS=""
  run_setup "1\n9\n1\n1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "None of the apps it can install into by itself were found on this"
  assert_not_contains "Install into all"
  assert_contains "Your Slack theme string"
}

# GIVEN dark palettes and a light one
# WHEN choosing Tilix, which keeps palettes side by side
# THEN the dark or light question offers ALL THE PALETTES above Preview
test_all_the_palettes_is_offered_for_side_by_side_apps() {
  fake_os Linux
  dawn_palette Light
  run_setup "1\ntilix\n1\n1\n1\ny\n1\n"
  assert_contains "Do you want a dark or light theme?
  1) Dark
  2) Light
  3) ALL THE PALETTES
  4) Preview the palettes (opens in your browser)
  0) Back"
}

# GIVEN dark palettes and a light one
# WHEN choosing tmux (one palette at a time), Slack (a manual install), and
#      ALL THE APPS
# THEN ALL THE PALETTES isn't offered for any of them
test_all_the_palettes_is_not_offered_for_the_others() {
  fake_os Linux
  fake_outside_commands
  dawn_palette Light
  run_setup "1\ntmux\n1\n1\n1\n"
  assert_not_contains "ALL THE PALETTES"
  run_setup "1\nslack\n1\n1\n1\n"
  assert_not_contains "ALL THE PALETTES"
  export SETUP_FOUND_APPS="tilix"
  run_setup "1\n9\n1\n1\nn\n1\nslack\n1\n1\n1\n"
  assert_not_contains "ALL THE PALETTES"
}

# GIVEN dark palettes and a light one, Dawn
# WHEN choosing Tilix, ALL THE PALETTES, and saying yes
# THEN it says what it will do, asking with no as the default, then installs
#      every palette's scheme without another question
test_all_the_palettes_installs_every_palette() {
  fake_os Linux
  dawn_palette Light
  run_setup "1\ntilix\n1\n3\ny\n"
  assert_status 0
  assert_contains "==> ALL THE PALETTES
This installs all 3 palettes into Tilix (terminal), with no more"
  assert_contains "Install all 3 palettes? [y/N]"
  assert_contains "Generating all 3 themes"
  for slug in blue-purple dawn sunset; do
    assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-$slug.json" \
      "$SANDBOX/repo/app-themes/tilix-theme/$slug.json"
  done
  assert_contains "==> ALL THE PALETTES: done
Installed into Tilix (terminal):
  - Blue Purple"
  assert_not_contains "Not installed:"
}

# GIVEN dark palettes and a light one
# WHEN choosing Tilix and ALL THE PALETTES, then saying no
# THEN nothing is installed, and the first menu is shown again
test_all_the_palettes_can_be_declined() {
  fake_os Linux
  dawn_palette Light
  run_setup "1\ntilix\n1\n3\nn\n1\nslack\n1\n1\n1\n"
  assert_status 0
  assert_missing "$SANDBOX/home/.config/tilix/schemes/jenerated-dawn.json"
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'What would you like to do?')" = "2" ] ||
    fail "expected the first menu again after saying no"
}

# GIVEN only dark palettes
# WHEN choosing an app
# THEN the palettes are listed without asking dark or light
test_theme_menu_skips_dark_or_light_with_one_kind() {
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_not_contains "Do you want a dark or light theme?"
  assert_contains "Which theme do you want?
  1) Blue Purple
  2) Sunset
  0) Back"
}

# GIVEN a palette in palettes/ that isn't valid TOML
# WHEN choosing an app
# THEN it stops before the theme menu, naming the broken palette
test_theme_menu_stops_on_an_unreadable_palette() {
  printf 'name = "Broken\n' >"$SANDBOX/repo/palettes/broken-palette.toml"
  run_setup "1\nslack\n1\n1\n"
  assert_status 1
  assert_contains "broken-palette.toml: not a valid palette file"
  assert_contains "fix the palette named above"
  assert_not_contains "Which theme"
}

# GIVEN answers that are empty or out of range at the app menu, and empty,
#       not numbers or out of range at the theme menu
# WHEN they're typed
# THEN each one asks again, and valid answers then carry on
test_invalid_choices_ask_again() {
  run_setup "1\n\n99\nslack\n1\n\nabc\n99\n-1\n1\n"
  assert_status 0
  count="$(printf '%s\n' "$OUTPUT" | grep -c 'Please enter a number between 0 and')"
  [ "$count" -eq 6 ] || fail "expected 6 re-prompts, got $count"
  assert_contains "Your Slack theme string"
}

# GIVEN no input at all
# WHEN setup.sh asks what to do
# THEN it exits with status 1, saying no choice was made
test_no_answer_exits_with_error() {
  run_setup ""
  assert_status 1
  assert_contains "no choice made"
}

# --- Tests: the first menu --------------------------------------------------

# sunset_number -> prints Sunset's number in the dark palettes' menu.
sunset_number() {
  local i=1 file
  for file in "$SANDBOX"/repo/palettes/Dark/*-palette.toml; do
    [ "$(basename "$file")" = sunset-palette.toml ] && break
    i=$((i + 1))
  done
  printf '%s' "$i"
}

# GIVEN setup.sh starting
# WHEN it shows its first menu
# THEN it offers installing a theme or designing a palette, and choosing to
#      install goes on to the app menu
test_first_menu_offers_installing_or_designing() {
  run_setup "1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "What would you like to do?"
  assert_contains "1) Install a theme for an app"
  assert_contains "2) Design a new palette (opens the Palette Creator)"
  assert_contains "Which app do you want to theme?"
}

# GIVEN an answer that isn't one of the first menu's choices
# WHEN it's typed at the first menu
# THEN it asks again
test_first_menu_asks_again_for_an_invalid_choice() {
  run_setup "3\n1\nslack\n1\n1\n"
  assert_status 0
  assert_contains "Please enter a number between 1 and 2."
}

# GIVEN setup.sh run from a folder other than the repository
# WHEN choosing to design a palette
# THEN it explains how to use the Palette Creator, then runs serve.py from
#      the repository, without going on to the app menu
test_palette_creator_choice_starts_the_server() {
  stub_palette_creator
  run_setup "2\n"
  assert_status 0
  assert_contains "Starting the Palette Creator"
  assert_contains '"Save as palette..." opens a save'
  assert_contains "press Ctrl+C here to stop it"
  assert_contains "stub server running"
  assert_not_contains "Which app"
  assert_file_equals "$SANDBOX/serve-ran" "$SANDBOX/repo|"
}

# GIVEN serve.py exiting with status 3, as it does for Back when asked about
#       a Palette Creator that's already running
# WHEN choosing to design a palette, then installing Slack's Blue Purple
# THEN the first menu is shown again, and installing works from there
test_palette_creator_back_returns_to_the_first_menu() {
  stub_palette_creator
  printf 'sys.exit(3)\n' >>"$SANDBOX/repo/jenerate_themes/creator/serve.py"
  run_setup "2\n1\nslack\n1\n1\n"
  assert_status 0
  [ "$(printf '%s\n' "$OUTPUT" | grep -c 'What would you like to do?')" = "2" ] ||
    fail "expected the first menu twice"
  assert_contains "Your Slack theme string"
}

# GIVEN serve.py stopping with an error
# WHEN choosing to design a palette
# THEN setup.sh exits with the same status
test_palette_creator_error_status_is_kept() {
  stub_palette_creator
  printf 'sys.exit(1)\n' >>"$SANDBOX/repo/jenerate_themes/creator/serve.py"
  run_setup "2\n"
  assert_status 1
  assert_not_contains "Which app"
}

# --- Tests: the --design and --install shortcuts ----------------------------

# GIVEN setup.sh
# WHEN running it with --design
# THEN it starts the Palette Creator straight away, without the first menu
test_design_starts_the_palette_creator() {
  stub_palette_creator
  run_setup "" --design
  assert_status 0
  assert_contains "Starting the Palette Creator"
  assert_contains "stub server running"
  assert_not_contains "What would you like to do?"
}

# GIVEN serve.py exiting with status 3, for Back when asked about a Palette
#       Creator that's already running
# WHEN running setup.sh with --design
# THEN it exits, since there's no menu to go back to
test_design_back_exits() {
  stub_palette_creator
  printf 'sys.exit(3)\n' >>"$SANDBOX/repo/jenerate_themes/creator/serve.py"
  run_setup "" --design
  assert_status 0
  assert_not_contains "What would you like to do?"
  assert_not_contains "Which app"
}

# GIVEN setup.sh
# WHEN running it with --install=slack,sunset
# THEN it installs Slack's Sunset theme without asking for the app or palette
test_install_with_an_app_and_a_palette_skips_the_menus() {
  run_setup "" --install=slack,sunset
  assert_status 0
  assert_contains "Generating the Sunset theme"
  assert_contains "Your Slack theme string"
  assert_not_contains "What would you like to do?"
  assert_not_contains "Which app"
  assert_not_contains "Which theme do you want?"
}

# GIVEN setup.sh
# WHEN running it with --install=slack, and choosing Sunset
# THEN it asks only for the palette
test_install_with_an_app_asks_for_the_palette() {
  run_setup "$(sunset_number)\n" --install=slack
  assert_status 0
  assert_contains "Which theme do you want?"
  assert_contains "Generating the Sunset theme"
  assert_not_contains "Which app"
}

# GIVEN setup.sh
# WHEN running it with --install=,sunset, and choosing Slack
# THEN it asks only for the app
test_install_with_a_palette_asks_for_the_app() {
  run_setup "slack\n1\n" --install=,sunset
  assert_status 0
  assert_contains "Which app do you want to theme?"
  assert_contains "Generating the Sunset theme"
  assert_contains "Your Slack theme string"
  assert_not_contains "What would you like to do?"
  assert_not_contains "Which theme do you want?"
}

# GIVEN setup.sh run with --install=slack
# WHEN going back from the palette question
# THEN the app menu is shown, as it would be after choosing Slack there
test_install_back_from_the_palette_goes_to_the_app_menu() {
  run_setup "0\nslack\n1\n$(sunset_number)\n" --install=slack
  assert_status 0
  assert_contains "Which app do you want to theme?"
  assert_contains "Generating the Sunset theme"
  assert_contains "Your Slack theme string"
}

# GIVEN setup.sh
# WHEN running it with an app or palette it doesn't know
# THEN it stops before any menu, listing the ones it knows
test_install_names_what_it_doesnt_know() {
  run_setup "" --install=bogus,sunset
  assert_status 1
  assert_contains 'no app called "bogus". The apps are:'
  assert_contains "vscode"
  assert_contains "or all, for ALL THE APPS"
  assert_not_contains "Which app"
  run_setup "" --install=slack,nope
  assert_status 1
  assert_contains 'no palette called "nope". The palettes are:'
  assert_contains "blue-purple"
  assert_contains "or all, for ALL THE PALETTES"
  assert_not_contains "Your Slack theme string"
}

# GIVEN a Linux system, then a macOS one
# WHEN asking for an app only offered on the other one
# THEN it says which system the app is offered on
test_install_names_the_system_an_app_is_offered_on() {
  fake_os Linux
  run_setup "" --install=xcode,sunset
  assert_status 1
  assert_contains "xcode is only offered on macOS"
  fake_os Darwin
  run_setup "" --install=tilix,sunset
  assert_status 1
  assert_contains "tilix is only offered on Linux"
}

# GIVEN setup.sh
# WHEN reading the apps it notes as only offered on the other system
# THEN each is an app it adds on one system, so the two lists agree
test_other_system_apps_are_real_apps() {
  for id in $(grep -o '^  OTHER_SYSTEM_APPS="$OTHER_SYSTEM_APPS [^"]*' "$SANDBOX/repo/setup.sh" |
    sed 's/.*OTHER_SYSTEM_APPS //' | tr ' ' '\n' | cut -d: -f1); do
    grep -q "^  add_app $id " "$SANDBOX/repo/setup.sh" ||
      fail "$id is noted as another system's app, but isn't added for any system"
  done
}

# GIVEN setup.sh
# WHEN asking for ALL THE PALETTES with an app that uses one palette at a
#      time, a manual one, or ALL THE APPS
# THEN it stops, saying why
test_install_refuses_all_the_palettes_where_the_menu_doesnt_offer_it() {
  fake_os Linux
  run_setup "" --install=tmux,all
  assert_status 1
  assert_contains "tmux uses one palette at a time"
  run_setup "" --install=slack,all
  assert_status 1
  assert_contains "Slack is themed by hand, one palette at a time"
  run_setup "" --install=all,all
  assert_status 1
  assert_contains "ALL THE APPS and ALL THE PALETTES don't go together"
}

# GIVEN dark palettes and a light one
# WHEN running setup.sh with --install=tilix,all, and saying yes
# THEN it asks first, as the menu's ALL THE PALETTES does, then installs
#      every palette
test_install_all_the_palettes_asks_first() {
  fake_os Linux
  dawn_palette Light
  run_setup "y\n" --install=tilix,all
  assert_status 0
  assert_contains "==> ALL THE PALETTES"
  assert_contains "Install all "
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-dawn.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/dawn.json"
}

# GIVEN setup.sh run with --install=,all
# WHEN choosing tmux (one palette at a time) from the app menu, then Tilix
# THEN it explains why tmux can't take them all, and asks for another app
test_install_all_the_palettes_asks_again_for_an_app_that_cant_take_them() {
  fake_os Linux
  run_setup "tmux\n1\ntilix\n1\ny\n" --install=,all
  assert_status 0
  assert_contains "tmux uses one palette at a time. Choose another app."
  assert_contains "==> ALL THE PALETTES"
}

# GIVEN setup.sh run with --install=all,blue-purple, with Tilix found
# WHEN saying yes
# THEN it asks first, as the menu's ALL THE APPS does, then installs
test_install_all_the_apps_asks_first() {
  fake_os Linux
  fake_outside_commands
  export SETUP_FOUND_APPS="tilix"
  run_setup "y\n" --install=all,blue-purple
  assert_contains "==> ALL THE APPS"
  assert_contains "Install into all 1 apps?"
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
}

# GIVEN setup.sh
# WHEN running --install without an app or palette, with too many, or with
#      two options at once
# THEN it stops, showing how it's written
test_install_is_written_app_comma_palette() {
  for option in --install --install= --install=, --install=a,b,c; do
    run_setup "" "$option"
    assert_status 1
    assert_contains "like --install=vscode,candy"
  done
  run_setup "" --design --install=slack,sunset
  assert_status 1
  assert_contains "one option at a time"
}

# --- Tests: generating -------------------------------------------------------

# GIVEN Python 3.11 or later
# WHEN choosing Slack and Sunset
# THEN Sunset's themes are generated and added to package.json
test_generates_the_chosen_palette() {
  run_setup "1\nslack\n1\n2\n"
  assert_status 0
  assert_contains "Generated Sunset (sunset)"
  assert_exists "$SANDBOX/repo/app-themes/slack-theme/sunset.txt"
  assert_exists "$SANDBOX/repo/app-themes/ptyxis-theme/sunset.palette"
  assert_exists "$SANDBOX/repo/app-themes/vs-code-theme/themes/jenerated-sunset-color-theme.json"
  grep -q '"Jenerated Sunset"' "$SANDBOX/repo/app-themes/vs-code-theme/package.json" ||
    fail "expected package.json to list Jenerated Sunset"
}

# GIVEN a palette with a color that isn't valid (so it's listed, but can't be
#       generated)
# WHEN choosing Tilix and that palette
# THEN it stops with jenerate.py's error and installs nothing
test_choosing_a_broken_palette_stops_with_its_error() {
  fake_os Linux
  sed -e 's/^name = .*/name = "Bad"/' -e 's/^slug = .*/slug = "bad"/' \
    "$SANDBOX/repo/palettes/Dark/sunset-palette.toml" >"$SANDBOX/repo/palettes/bad-palette.toml"
  printf 'mystery = "blue-purple"\n' >>"$SANDBOX/repo/palettes/bad-palette.toml"
  run_setup "1\ntilix\n1\n1\ny\n1\n"
  assert_status 1
  assert_contains "1) Bad"
  assert_contains "color \`mystery\` = 'blue-purple' is not a #rrggbb value"
  assert_not_contains "Done!"
  assert_missing "$SANDBOX/home/.config/tilix/schemes/jenerated-bad.json"
}

# --- Tests: showing the install commands, then running them ------------------

TILIX_SCHEMES=".config/tilix/schemes"

# GIVEN a Linux system
# WHEN choosing Tilix and answering no to running the install commands
# THEN the link and copy commands are shown first, nothing is installed, and
#      the steps to turn the theme on follow the commands
test_install_commands_are_shown_and_can_be_declined() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\nn\n"
  assert_status 0
  assert_contains "==> To install the Tilix color scheme, run:
    mkdir -p \"\$HOME/$TILIX_SCHEMES\"
    ln -s \"$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json\" \"\$HOME/$TILIX_SCHEMES/jenerated-blue-purple.json\"
Or, to copy the files instead of linking them:
    cp -R \"$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json\" \"\$HOME/$TILIX_SCHEMES/jenerated-blue-purple.json\"

Run these for you? [Y/n]"
  assert_contains "==> Once you've run the commands above, to turn the color scheme on:"
  assert_not_contains "Link or copy the files?"
  assert_missing "$SANDBOX/home/$TILIX_SCHEMES"
}

# GIVEN a Linux system
# WHEN choosing Tilix, running the commands, and choosing to copy
# THEN the scheme is copied rather than linked, with a reminder to run
#      setup.sh again after changing the palette
test_install_can_copy_instead_of_linking() {
  fake_os Linux
  run_setup "1\ntilix\n1\n1\ny\n2\n"
  assert_status 0
  [ -f "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" ] &&
    [ ! -L "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" ] ||
    fail "expected a copy, not a link"
  assert_same_file "$SANDBOX/home/$TILIX_SCHEMES/jenerated-blue-purple.json" \
    "$SANDBOX/repo/app-themes/tilix-theme/blue-purple.json"
  assert_contains "The files are copies, so after changing the palette"
}

# --- Tests: JetBrains apps ---------------------------------------------------

# GIVEN JetBrains, LibreOffice, Spyder and Zen counted as found, but no IDE
#       has run, LibreOffice's installer doesn't work, and Spyder and Zen
#       haven't been opened
# WHEN installing ALL THE APPS
# THEN each is listed as not installed, with why, rather than as installed
test_all_the_apps_reports_what_it_could_not_install() {
  fake_os Linux
  fake_outside_commands
  export SETUP_FOUND_APPS="jetbrains libreoffice spyder zen tilix"
  run_setup "1\n9\n1\ny\n"
  assert_contains "no JetBrains IDE has run yet"
  assert_contains "LibreOffice's extension installer (unopkg) wasn't found"
  assert_contains "Spyder hasn't been opened yet"
  assert_contains "Zen hasn't been opened yet"
  installed="$(printf '%s\n' "$OUTPUT" | sed -n '/^Installed Jenerated Blue Purple into:$/,/^$/p')"
  [ "$(printf '%s\n' "$installed" | grep -c '^  - ')" = "1" ] ||
    fail "expected only Tilix installed, got: $installed"
  assert_contains "Not installed:
  - Zen Browser"
}

run_tests
