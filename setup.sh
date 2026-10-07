#!/usr/bin/env bash
# Walks you through installing a Jenerated theme: pick an app, pick a palette,
# and it generates the theme and installs it for you. It can also start the
# Palette Creator, for designing a new palette.
#
# Usage: ./setup.sh (./setup.sh --help lists the options)
#
# With Python 3.11 or later, setup.sh hands over to the jenerate app
# (./jenerate), which does all of that. Without Python, it can still install
# Blue Purple, whose themes come with the repository, into the apps where
# that only means linking files into place.
#
# Works on Linux and macOS (including macOS's built-in bash 3.2).

set -eu

# Where setup.sh was run from, for paths the user types.
START_DIR="$(pwd)"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OS="$(uname -s)"

# --- Helpers -----------------------------------------------------------------

say() { printf '%s\n' "$*"; }
step() {
  local text="$*" first
  # When you chose to run the install commands yourself, nothing's done yet.
  if [ "${INSTALL_MODE:-}" = manual ]; then
    case "$text" in
      "Done! "*)
        text="${text#Done! }"
        first="$(printf '%s' "${text%"${text#?}"}" | tr '[:upper:]' '[:lower:]')"
        text="Once you've run the commands above, $first${text#?}"
        ;;
    esac
  fi
  printf '\n==> %s\n' "$text"
}
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }

# ask_yes "Question?" -> returns 0 for yes (the default), 1 for no.
ask_yes() {
  local reply
  printf '%s [Y/n] ' "$1"
  read -r reply || reply=n
  case "$reply" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

# choose "Prompt" option... -> sets CHOICE to the chosen option's index (0-based).
choose() {
  local prompt="$1" i reply
  shift
  say ""
  say "$prompt"
  i=1
  for option in "$@"; do
    printf '  %d) %s\n' "$i" "$option"
    i=$((i + 1))
  done
  while :; do
    printf 'Enter a number (1-%d): ' "$#"
    read -r reply || die "no choice made"
    case "$reply" in
      '' | *[!0-9]*) ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "$#" ]; then
          CHOICE=$((reply - 1))
          return
        fi
        ;;
    esac
    say "Please enter a number between 1 and $#."
  done
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

# --- Maintainer tasks ---------------------------------------------------------
# ./setup.sh --prep-commit and --update-screenshots run
# maintainer-tools/prep-commit.py and update-screenshots.py (see there). Listed under "For
# maintainers" in --help, and left out of the README, which is for people
# installing themes; documented in CONTRIBUTING.md.

PYTHON="$(find_python)"

prep_commit() {
  [ -n "$PYTHON" ] || die "--prep-commit needs Python 3.11 or later"
  exec "$PYTHON" maintainer-tools/prep-commit.py
}

update_screenshots() {
  [ -n "$PYTHON" ] || die "--update-screenshots needs Python 3.11 or later"
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 ||
    die "--update-screenshots needs Node.js and npm (for Playwright)"
  exec "$PYTHON" maintainer-tools/update-screenshots.py "$@"
}

# --- Options -----------------------------------------------------------------

usage() {
  cat <<'EOF_USAGE'
Usage: ./setup.sh [option]

Walks you through installing a Jenerated theme: pick an app, pick a palette,
and it generates the theme and installs it for you.

With no option, it shows a menu:
  1) Install a theme for an app
  2) Design a new palette (opens the Palette Creator in your browser)

Options:
  -h, --help                  Show this help, and exit.
  --version                   Show the version, and exit.
  --design                    Start the Palette Creator, skipping the menu.
  --install=APP,PALETTE       Install a theme, skipping the menus: APP is an
                              app's id and PALETTE a palette's slug, like
                              --install=vscode,candy. Leave either out to
                              choose it from its menu (--install=vscode, or
                              --install=,candy). "all" means ALL THE APPS or
                              ALL THE PALETTES. A name it doesn't know lists
                              the ones it does.

For maintainers (see CONTRIBUTING.md):
  --prep-commit               Put the generated files git tracks back to the
                              Blue Purple defaults, before a commit.
  --update-screenshots        File every palette as dark or light, retake
                              every palette's screenshot, and update
                              palettes/README.md. Needs Node.js and npm.
  --update-screenshots=SLUGS  The same, but retake only these palettes'
                              screenshots, by slug, with commas between
                              several (like candy,sunset).
EOF_USAGE
}

# Set by --design and --install, for the menus further down to act on.
DESIGN=""
INSTALL_REQUEST=""

[ "$#" -le 1 ] || die "one option at a time (./setup.sh --help lists the options)"
case "${1:-}" in
  "") ;;
  --version)
    # Read from the package, so it works without Python too.
    printf 'jenerate-themes %s\n' "$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' jenerate_themes/__init__.py)"
    exit 0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --design)
    DESIGN=1
    ;;
  --install=*)
    INSTALL_REQUEST="${1#*=}"
    case "$INSTALL_REQUEST" in
      "" | ",") die "name an app, a palette or both, like --install=vscode,candy" ;;
      *,*,*) die "name one app and one palette, like --install=vscode,candy" ;;
    esac
    ;;
  --install)
    die "name an app, a palette or both, like --install=vscode,candy"
    ;;
  --prep-commit)
    prep_commit
    exit 0
    ;;
  --update-screenshots | --update-screenshot)
    update_screenshots
    exit 0
    ;;
  --update-screenshots=* | --update-screenshot=*)
    [ -n "${1#*=}" ] || die "name the palettes to screenshot, like --update-screenshots=candy"
    update_screenshots "${1#*=}"
    exit 0
    ;;
  *) die "unknown option: $1 (./setup.sh --help lists the options)" ;;
esac

# --- Hand over to the jenerate app ---------------------------------------------

# With Python 3.11 or later, the jenerate app (./jenerate, in Python) does the
# rest: the same menus and installs, calling itself ./setup.sh in its
# messages. It starts in the folder setup.sh was run from, for paths you type.
# Without Python, the rest of this script does it instead.
if [ -n "$PYTHON" ]; then
  export JENERATE_COMMAND=./setup.sh
  cd "$START_DIR"
  if [ -n "$DESIGN" ]; then
    exec "$PYTHON" "$ROOT/jenerate" design
  elif [ -n "$INSTALL_REQUEST" ]; then
    # --install=APP,PALETTE -> install APP PALETTE (--palette PALETTE alone
    # when there's no app).
    set -- install
    if [ -n "${INSTALL_REQUEST%%,*}" ]; then set -- "$@" "${INSTALL_REQUEST%%,*}"; fi
    case "$INSTALL_REQUEST" in
      *,?*) set -- "$@" --palette "${INSTALL_REQUEST#*,}" ;;
    esac
    exec "$PYTHON" "$ROOT/jenerate" "$@"
  fi
  exec "$PYTHON" "$ROOT/jenerate"
fi

# --- Without Python: Blue Purple only ---------------------------------------
# The rest of setup.sh runs only without Python 3.11 or later. Blue Purple's
# themes come with the repository already generated, so it can still install
# them, into the apps where that only means linking files into place (or
# showing a theme to paste in). Every other palette, the other apps, ALL THE
# APPS and ALL THE PALETTES need Python, and jenerate.

# install_link target source -> links (or, with INSTALL_MODE=copy, copies)
# source to target, offering to replace anything already at target.
install_link() {
  local target="$1" source="$2"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    say "Already installed (linked to this folder)."
    return
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    say "An older install exists at $target."
    if [ "$INSTALL_MODE" = copy ]; then
      ask_yes "Replace it with a copy?" || die "left the existing install alone"
    else
      ask_yes "Replace it with a link to this folder?" || die "left the existing install alone"
    fi
    rm -rf "$target"
  fi
  if [ "$INSTALL_MODE" = copy ]; then
    cp -R "$source" "$target"
    say "Copied $source to $target"
  else
    ln -s "$source" "$target"
    say "Linked $target -> $source"
  fi
}

# shell_quote path -> prints the path in double quotes, ready to paste into a
# shell, with $HOME standing for your home folder.
shell_quote() {
  local path="$1" home=""
  case "$path" in
    "$HOME"/*)
      home='$HOME'
      path="${path#"$HOME"}"
      ;;
  esac
  printf '"%s%s"' "$home" "$(printf '%s' "$path" | sed 's/[\\"$`]/\\&/g')"
}

plan_link() {
  PLAN_TARGETS+=("$1")
  PLAN_SOURCES+=("$2")
}

# run_install_plan what -> shows the commands that install the planned files
# (what names them, like "the Tilix color scheme"), then offers to run them,
# linking or copying the files. Sets INSTALL_MODE to link, copy, or manual
# if you'd rather run them yourself. Files already linked to this folder are
# left out, and if that's all of them, there's nothing to ask.
run_install_plan() {
  local what="$1" i target source dir dirs="" existing=""
  local targets=() sources=()
  for i in "${!PLAN_TARGETS[@]}"; do
    target="${PLAN_TARGETS[$i]}"
    source="${PLAN_SOURCES[$i]}"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then continue; fi
    targets+=("$target")
    sources+=("$source")
  done
  PLAN_TARGETS=()
  PLAN_SOURCES=()

  if [ "${#targets[@]}" -eq 0 ]; then
    step "Installing $what"
    say "Already installed (linked to this folder)."
    INSTALL_MODE=link
    return
  fi

  step "To install $what, run:"
  for target in "${targets[@]}"; do
    dir="$(dirname "$target")"
    case "$dirs" in
      *"
$dir
"*) ;;
      *)
        dirs="$dirs
$dir
"
        say "    mkdir -p $(shell_quote "$dir")"
        ;;
    esac
    if [ -e "$target" ] || [ -L "$target" ]; then existing=1; fi
  done
  for i in "${!targets[@]}"; do
    say "    ln -s $(shell_quote "${sources[$i]}") $(shell_quote "${targets[$i]}")"
  done
  say "Or, to copy the files instead of linking them:"
  for i in "${!targets[@]}"; do
    say "    cp -R $(shell_quote "${sources[$i]}") $(shell_quote "${targets[$i]}")"
  done
  if [ -n "$existing" ]; then
    say "(An older install is in the way; move it aside first.)"
  fi

  say ""
  if ! ask_yes "Run these for you?"; then
    INSTALL_MODE=manual
    return
  fi
  choose "Link or copy the files?" \
    "Link (recommended): they update by themselves when you change the palette" \
    "Copy: they don't need this folder, but run ./setup.sh again after changing the palette"
  if [ "$CHOICE" -eq 0 ]; then INSTALL_MODE=link; else INSTALL_MODE=copy; fi

  step "Installing $what"
  for i in "${!targets[@]}"; do
    mkdir -p "$(dirname "${targets[$i]}")"
    install_link "${targets[$i]}" "${sources[$i]}"
  done
}

copy_to_clipboard() {
  if [ "$OS" = "Darwin" ] && command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    return 1
  fi
}

install_chromium() {
  local folder="$ROOT/app-themes/chromium-theme/$SLUG"

  # Browsers cache a theme in its folder when they load it; clear any old
  # cache so the new colors are used.
  rm -f "$folder/Cached Theme.pak"

  step "Done! The theme is ready in $folder"
  say "To turn it on, in Chrome, Brave, Edge, Opera, Chromium or another"
  say "Chromium-based browser:"
  say "1. Open the browser's extensions page:"
  say "     chrome://extensions  (Chrome, Chromium)"
  say "     brave://extensions   (Brave)"
  say "     edge://extensions    (Edge)"
  say "     opera://extensions   (Opera)"
  say "2. Turn on Developer mode."
  say "3. Click \"Load unpacked\" and choose the folder above. The theme applies"
  say "   right away."
  say "The browser keeps loading the theme from that folder, so leave it there."
  say "After changing the palette, run ./setup.sh again and load it again."
  say "To go back to the browser's own look: Settings -> Appearance -> Theme ->"
  say "Reset to default."
}

install_mattermost() {
  local theme
  # One line, so it's easy to copy from the terminal too.
  theme="$(tr -d '\n' <"app-themes/mattermost-theme/$SLUG.json" | sed 's/  */ /g')"

  step "Your Mattermost theme"
  say ""
  say "$theme"
  say ""
  if printf '%s' "$theme" | copy_to_clipboard 2>/dev/null; then
    say "(Copied to your clipboard.)"
  fi

  step "Done! To turn the theme on (Mattermost keeps themes with your account):"
  say "1. In Mattermost, open Settings -> Display -> Theme, and choose Edit."
  say "2. Choose Custom Theme, and paste the theme above into the box under"
  say "   \"Copy and paste to share theme colors\"."
  say "3. Choose Save."
  say "It applies wherever you use Mattermost: the web, the desktop app and the"
  say "mobile apps. After changing the palette, run ./setup.sh again and paste"
  say "the new theme."
}

# Quassel's settings folder (not the Flatpak's; see QUASSEL_FLATPAK).
quassel_config_dir() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s' "$HOME/Library/Application Support/Quassel"
  else
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/quassel-irc.org"
  fi
}

# The Flatpak's own folder. The Flatpak can't see files outside it, so it
# gets a copy of the stylesheet rather than a link to this folder.
QUASSEL_FLATPAK="$HOME/.var/app/org.quassel_irc.QuasselClient"

install_quassel() {
  local file="jenerated-$SLUG.qss"
  local source="$ROOT/app-themes/quassel-theme/$file"
  local stylesheets flatpak_copy=""
  stylesheets="$(quassel_config_dir)/stylesheets"

  plan_link "$stylesheets/$file" "$source"
  run_install_plan "the Quassel stylesheet"

  if [ -d "$QUASSEL_FLATPAK" ]; then
    flatpak_copy="$QUASSEL_FLATPAK/config/quassel-irc.org/stylesheets/$file"
  fi
  if [ -n "$flatpak_copy" ] && [ "$INSTALL_MODE" = manual ]; then
    step "For the Quassel Flatpak, which can't see files outside its own folder, run:"
    say "    mkdir -p $(shell_quote "$(dirname "$flatpak_copy")")"
    say "    cp $(shell_quote "$source") $(shell_quote "$flatpak_copy")"
  elif [ -n "$flatpak_copy" ]; then
    step "Copying the stylesheet for the Quassel Flatpak"
    say "(The Flatpak can't see files outside its own folder, so it gets a copy.)"
    mkdir -p "$(dirname "$flatpak_copy")"
    rm -f "$flatpak_copy"
    cp "$source" "$flatpak_copy"
    say "Copied $source to $flatpak_copy"
  fi

  step "Done! To turn the stylesheet on:"
  say "1. In Quassel, open Settings -> Configure Quassel... -> Interface."
  say "2. Check \"Use custom stylesheet\" and choose"
  say "   $stylesheets/$file"
  if [ -n "$flatpak_copy" ]; then
    say "   (or, in the Flatpak, $flatpak_copy)"
  fi
  say "3. Click OK; the colors change right away."
  say "After changing the palette, run ./jenerate.py $SLUG and restart Quassel."
  if [ -n "$flatpak_copy" ]; then
    say "The Flatpak's copy doesn't update itself: run ./setup.sh again for it."
  fi
}

install_slack() {
  local theme
  theme="$(tr -d '\n' <"app-themes/slack-theme/$SLUG.txt")"

  step "Your Slack theme string"
  say ""
  say "    $theme"
  say ""
  if printf '%s' "$theme" | copy_to_clipboard 2>/dev/null; then
    say "(Copied to your clipboard.)"
  fi

  step "Done! To turn the theme on (Slack can't be themed from outside the app):"
  say "1. Paste the string above into any message box in Slack, such as a DM"
  say "   to yourself, and send it."
  say "2. Click the \"Switch sidebar theme\" button that appears under it."
  say "Slack themes are per workspace, so repeat this in each workspace."
}

# Emacs's own folder, chosen the way Emacs chooses it: ~/.emacs.d if it (or
# a ~/.emacs file) exists, otherwise ~/.config/emacs if that exists, and
# otherwise ~/.emacs.d.
emacs_dir() {
  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
  if [ -e "$HOME/.emacs.d" ] || [ -e "$HOME/.emacs" ]; then
    printf '%s' "$HOME/.emacs.d"
  elif [ -e "$xdg" ]; then
    printf '%s' "$xdg"
  else
    printf '%s' "$HOME/.emacs.d"
  fi
}

install_emacs() {
  local dir file="jenerated-$SLUG-theme.el"
  dir="$(emacs_dir)"

  # Emacs looks for themes in its own folder, so nothing else needs setting.
  plan_link "$dir/$file" "$ROOT/app-themes/emacs-theme/$file"
  run_install_plan "the Emacs theme"

  step "Done! To turn the theme on, in Emacs:"
  say "1. Run M-x load-theme RET jenerated-$SLUG RET. Emacs asks whether to"
  say "   trust the theme's code first; say yes (and yes to treating it as"
  say "   safe, so it doesn't ask again)."
  say "2. To keep it, run M-x customize-themes, tick jenerated-$SLUG (and"
  say "   untick any other theme), and choose Save Theme Settings."
  say "After changing the palette, run ./jenerate.py $SLUG and load the theme"
  say "again."
}

# Editors built on GtkSourceView read style schemes from a folder named after
# their GtkSourceView version, and the three versions in use each need their
# own file (see app-themes/gtksourceview-theme/README.md).
install_gtksourceview() {
  local data="${XDG_DATA_HOME:-$HOME/.local/share}"
  local folder="$ROOT/app-themes/gtksourceview-theme/$SLUG"
  local file="jenerated-$SLUG.xml"
  local version dir
  # "folder-in-this-repo  styles-folder" pairs: GtkSourceView 3 and 4 (gedit 46
  # and earlier, Xed, Pluma, Meld), 5 (GNOME Text Editor), and gedit 47 and
  # later's own libgedit-gtksourceview.
  local pairs=(
    "gtksourceview-4 $data/gtksourceview-3.0/styles"
    "gtksourceview-4 $data/gtksourceview-4/styles"
    "gtksourceview-5 $data/gtksourceview-5/styles"
    "libgedit-gtksourceview-300 $data/libgedit-gtksourceview-300/styles"
  )
  # Apps installed through Flatpak keep their data in folders of their own.
  if [ -d "$HOME/.var/app/org.gnome.TextEditor" ]; then
    pairs+=("gtksourceview-5 $HOME/.var/app/org.gnome.TextEditor/data/gtksourceview-5/styles")
  fi
  if [ -d "$HOME/.var/app/org.gnome.gedit" ]; then
    pairs+=("libgedit-gtksourceview-300 $HOME/.var/app/org.gnome.gedit/data/libgedit-gtksourceview-300/styles")
  fi

  for pair in "${pairs[@]}"; do
    version="${pair%% *}"
    dir="${pair#* }"
    plan_link "$dir/$file" "$folder/$version/$file"
  done
  run_install_plan "the style schemes"

  step "Done! Choose \"Jenerated $NAME\" as the color scheme in each editor:"
  say "- gedit: Preferences -> Font & Colors."
  say "- GNOME Text Editor: the menu -> Preferences -> Style. It only lists"
  say "  schemes that match its own light or dark style, so for this palette"
  if grep -q '<property name="variant">light</property>' "$folder/gtksourceview-5/$file"; then
    say "  choose the light style first (the sun at the top of the menu)."
  else
    say "  choose the dark style first (the moon at the top of the menu)."
  fi
  say "- Xed: Edit -> Preferences -> Theme."
  say "- Pluma, Meld and other GtkSourceView editors: in their preferences,"
  say "  usually under fonts and colors."
  say "Reopen editors that were already open. After changing the palette, run"
  say "./jenerate.py $SLUG and reopen them."
}

# Qt Creator's user styles folders: the usual one (~/.config on macOS too),
# and, if Qt Creator was installed through Flatpak, the folder Flatpak gives
# it.
qtcreator_styles_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/.config/QtProject/qtcreator/styles"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/QtProject/qtcreator/styles"
  fi
  if [ -d "$HOME/.var/app/io.qt.QtCreator" ]; then
    printf '%s\n' "$HOME/.var/app/io.qt.QtCreator/config/QtProject/qtcreator/styles"
  fi
  return 0
}

install_qtcreator() {
  local file="jenerated-$SLUG.xml"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(qtcreator_styles_dirs)

  for dir in "${dirs[@]}"; do
    plan_link "$dir/$file" "$ROOT/app-themes/qtcreator-theme/$file"
  done
  run_install_plan "the Qt Creator color scheme"

  step "Done! To turn the color scheme on, in Qt Creator:"
  say "1. Open Edit -> Preferences (Qt Creator -> Settings on a Mac, Tools ->"
  say "   Options in older versions) -> Text Editor -> Font & Colors."
  say "2. Choose \"Jenerated $NAME\" as the Color Scheme. (Restart Qt Creator"
  say "   first if it doesn't appear.)"
  say "For the rest of the window, choose Qt Creator's own Dark or Light theme"
  say "to match, under Environment -> Interface -> Theme."
  say "After changing the palette, run ./jenerate.py $SLUG and choose the scheme"
  say "again, or restart Qt Creator."
}

install_rstudio() {
  # RStudio's settings folder, on Linux and macOS alike.
  local themes
  if [ -n "${RSTUDIO_CONFIG_HOME:-}" ]; then
    themes="$RSTUDIO_CONFIG_HOME/themes"
  else
    themes="${XDG_CONFIG_HOME:-$HOME/.config}/rstudio/themes"
  fi

  plan_link "$themes/jenerated-$SLUG.rstheme" "$ROOT/app-themes/rstudio-theme/jenerated-$SLUG.rstheme"
  run_install_plan "the RStudio theme"

  step "Done! To turn the theme on, in RStudio:"
  say "1. Open Tools -> Global Options -> Appearance."
  say "2. Choose \"Jenerated $NAME\" as the Editor theme, and Apply. (Restart"
  say "   RStudio first if it doesn't appear.)"
  say "After changing the palette, run ./jenerate.py $SLUG and choose the theme"
  say "again, or restart RStudio."
}

# Sublime Text's data folders: Sublime Text 4's, and Sublime Text 3's, the
# Flatpak's and the Snap's when they exist.
sublime_data_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Sublime Text"
    if [ -d "$HOME/Library/Application Support/Sublime Text 3" ]; then
      printf '%s\n' "$HOME/Library/Application Support/Sublime Text 3"
    fi
    return 0
  fi
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s\n' "$config/sublime-text"
  if [ -d "$config/sublime-text-3" ]; then printf '%s\n' "$config/sublime-text-3"; fi
  if [ -d "$HOME/.var/app/com.sublimetext.three" ]; then
    printf '%s\n' "$HOME/.var/app/com.sublimetext.three/config/sublime-text"
  fi
  if [ -d "$HOME/snap/sublime-text" ]; then
    printf '%s\n' "$HOME/snap/sublime-text/current/.config/sublime-text"
  fi
  return 0
}

install_sublime() {
  local file="jenerated-$SLUG.sublime-color-scheme"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(sublime_data_dirs)

  for dir in "${dirs[@]}"; do
    plan_link "$dir/Packages/User/$file" "$ROOT/app-themes/sublime-theme/$file"
  done
  run_install_plan "the Sublime Text color scheme"

  step "Done! To turn the color scheme on, in Sublime Text:"
  say "1. Open the command palette (Ctrl+Shift+P, or Cmd+Shift+P on a Mac),"
  say "   choose \"UI: Select Color Scheme\", then \"Jenerated $NAME\"."
  say "2. For the sidebar and tabs to match, choose \"UI: Select Theme\" there"
  say "   too, then \"Adaptive\", which takes its colors from the color scheme."
  say "Sublime Text reloads the color scheme when the palette changes and"
  say "./jenerate.py $SLUG runs again."
}

# Unreal Engine's folder for your own editor themes. It's the same for every
# engine version, and Unreal doesn't follow XDG_CONFIG_HOME.
unreal_themes_dir() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Epic/UnrealEngine/Slate/Themes"
  else
    printf '%s\n' "$HOME/.config/Epic/UnrealEngine/Slate/Themes"
  fi
}

install_unreal() {
  local file="jenerated-$SLUG.json"
  local dir
  dir="$(unreal_themes_dir)"

  plan_link "$dir/$file" "$ROOT/app-themes/unreal-theme/$file"
  run_install_plan "the Unreal Engine editor theme"

  step "Done! To turn the theme on, in the Unreal Editor:"
  say "1. Open Edit -> Editor Preferences -> General -> Appearance."
  say "2. Under Theme, choose \"Jenerated $NAME\" as the Active Theme. (Restart"
  say "   the editor first if it doesn't appear.)"
  say "To tweak the colors in Unreal, choose Duplicate and edit the copy, so"
  say "your changes aren't overwritten the next time you run ./jenerate.py."
  say "After changing the palette, run ./jenerate.py $SLUG and restart the"
  say "editor."
}

install_vim() {
  local vim_pack="$HOME/.vim/pack/jenerated/start/jenerated-themes"
  local nvim_pack="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/jenerated/start/jenerated-themes"
  local has_vim="" has_nvim=""
  { command -v vim >/dev/null 2>&1 || [ -d "$HOME/.vim" ]; } && has_vim=1
  { command -v nvim >/dev/null 2>&1 || [ -d "$HOME/.config/nvim" ]; } && has_nvim=1
  # With neither found, set it up for Vim.
  [ -z "$has_nvim" ] && has_vim=1

  # app-themes/vim-theme is a Vim package: linked once, every generated palette's
  # colorscheme (in its colors/ folder) is available.
  if [ -n "$has_vim" ]; then plan_link "$vim_pack" "$ROOT/app-themes/vim-theme"; fi
  if [ -n "$has_nvim" ]; then plan_link "$nvim_pack" "$ROOT/app-themes/vim-theme"; fi
  if [ -n "$has_vim" ] && [ -n "$has_nvim" ]; then
    run_install_plan "the colorschemes for Vim and Neovim"
  elif [ -n "$has_vim" ]; then
    run_install_plan "the colorschemes for Vim"
  else
    run_install_plan "the colorschemes for Neovim"
  fi

  step "Done! To turn the colorscheme on:"
  say "Try it now with :colorscheme jenerated-$SLUG"
  say ""
  if [ -n "$has_vim" ]; then
    say "To keep it, add these lines to ~/.vimrc:"
    say "    set termguicolors"
    say "    colorscheme jenerated-$SLUG"
  fi
  if [ -n "$has_nvim" ]; then
    say "To keep it in Neovim, add these lines to ~/.config/nvim/init.lua:"
    say "    vim.opt.termguicolors = true"
    say "    vim.cmd.colorscheme(\"jenerated-$SLUG\")"
  fi
  say ""
  say "termguicolors gives the palette's exact colors. If your terminal doesn't"
  say "support true color, leave it out: the colorscheme then uses the terminal's"
  say "16 colors, which the Ptyxis and Tilix themes set to the same palette."
}

# The extensions folders of the VS Code family that are in use: VS Code's
# (~/.vscode), and Code - OSS's and VSCodium's (both ~/.vscode-oss), which each
# makes the first time it runs. With neither there, VS Code's.
vscode_extension_dirs() {
  local found=""
  if [ -d "$HOME/.vscode" ]; then
    printf '%s\n' "$HOME/.vscode/extensions"
    found=1
  fi
  if [ -d "$HOME/.vscode-oss" ]; then
    printf '%s\n' "$HOME/.vscode-oss/extensions"
    found=1
  fi
  [ -n "$found" ] || printf '%s\n' "$HOME/.vscode/extensions"
  return 0
}

install_vscode() {
  local source="$ROOT/app-themes/vs-code-theme"
  local extensions dirs=() other obsolete

  while IFS= read -r extensions; do dirs+=("$extensions"); done < <(vscode_extension_dirs)

  for extensions in "${dirs[@]}"; do
    plan_link "$extensions/jenerated-themes" "$source"
  done
  run_install_plan "the VS Code extension"

  for extensions in "${dirs[@]}"; do
    # A .vsix install of the same extension would clash with the link.
    for other in "$extensions"/local.jenerated-themes-*; do
      [ -e "$other" ] || continue
      say ""
      say "Note: you also have a packaged copy installed ($(basename "$other"), in $extensions)."
      say "Uninstall \"Jenerated Themes\" from the editor's Extensions view so the two don't clash."
    done

    # If the extension was ever uninstalled, VS Code lists it in .obsolete and
    # ignores it, even after it's reinstalled. VS Code rewrites that file while
    # it runs, so it has to be closed while we remove the entry.
    obsolete="$extensions/.obsolete"
    if [ "$INSTALL_MODE" != manual ] && [ -f "$obsolete" ] && grep -q 'local\.jenerated-themes' "$obsolete"; then
      say ""
      say "This extension is marked as uninstalled in $extensions,"
      say "which hides the theme."
      say "Quit it completely (all windows), then press Enter to fix it."
      read -r _ || die "stopped before changing its files; run ./setup.sh again"
      sed -e 's/"local\.jenerated-themes[^"]*":[a-z]*//g' \
        -e 's/,,*/,/g' -e 's/{,/{/' -e 's/,}/}/' "$obsolete" >"$obsolete.tmp"
      if grep -q '^{}$' "$obsolete.tmp"; then
        rm -f "$obsolete" "$obsolete.tmp"
      else
        mv "$obsolete.tmp" "$obsolete"
      fi
      say "Fixed."
    fi
  done

  step "Done! To turn the theme on (in VS Code, Code - OSS or VSCodium):"
  say "1. Open (or reload) the editor: Command Palette -> \"Developer: Reload Window\"."
  say "2. Open the theme picker (Ctrl+K Ctrl+T, or Cmd+K Cmd+T on a Mac)."
  say "3. Choose \"Jenerated $NAME\"."
  if [ ! -d "$HOME/.vscode-oss" ]; then
    say "For Code - OSS or VSCodium, open it once first, so it makes its"
    say "~/.vscode-oss folder, then run ./setup.sh again."
  fi
}

install_xcode() {
  local themes="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"

  # Xcode lists a theme by its file name, so the link is named after the
  # palette rather than its slug.
  plan_link "$themes/Jenerated $NAME.xccolortheme" "$ROOT/app-themes/xcode-theme/jenerated-$SLUG.xccolortheme"
  run_install_plan "the Xcode theme"

  step "Done! To turn the theme on:"
  say "1. Quit Xcode if it's open, and open it again (it finds new themes when"
  say "   it starts)."
  say "2. Open Xcode -> Settings (Preferences in older versions) -> Themes, and"
  say "   choose \"Jenerated $NAME\"."
  say "After changing the palette, run ./jenerate.py $SLUG and restart Xcode."
}

install_ptyxis() {
  local palettes="$HOME/.local/share/org.gnome.Ptyxis/palettes"

  plan_link "$palettes/$SLUG.palette" "$ROOT/app-themes/ptyxis-theme/$SLUG.palette"
  run_install_plan "the Ptyxis palette"

  step "Done! To turn the palette on:"
  say "1. Close and reopen Ptyxis."
  say "2. Open Preferences (Ctrl+,), and under Appearance choose \"$NAME\"."
  say "   It applies to the current profile; repeat for other profiles."
}

# QTerminal's terminal (qtermwidget) reads Konsole's color scheme format, so it
# uses the KDE theme's Konsole scheme. It lists schemes by file name, so the
# link is named for the palette.
install_qterminal() {
  local schemes="${XDG_DATA_HOME:-$HOME/.local/share}/qterminal/color-schemes"

  plan_link "$schemes/Jenerated $NAME.colorscheme" "$ROOT/app-themes/kde-theme/$SLUG/Jenerated-$SLUG.colorscheme"
  run_install_plan "the QTerminal color scheme"

  step "Done! To turn the colors on:"
  say "1. Close every QTerminal window, then open QTerminal again; it reads its"
  say "   color schemes when it starts."
  say "2. Open File -> Preferences, and on the Appearance tab choose"
  say "   \"Jenerated $NAME\" as the Color scheme."
  say "After changing the palette, run ./jenerate.py $SLUG and restart QTerminal."
}

install_tilix() {
  local schemes="$HOME/.config/tilix/schemes"

  # The jenerated- prefix keeps it from replacing a scheme of your own.
  plan_link "$schemes/jenerated-$SLUG.json" "$ROOT/app-themes/tilix-theme/$SLUG.json"
  run_install_plan "the Tilix color scheme"

  step "Done! To turn the color scheme on:"
  say "1. Close every Tilix window, then open Tilix again."
  say "2. Open Preferences, choose your profile under Profiles, and on the"
  say "   Color tab choose \"Jenerated $NAME\" as the color scheme."
  say "   Repeat for other profiles."
}

install_decky() {
  local themes="$HOME/homebrew/themes"

  if [ ! -d "$HOME/homebrew" ]; then
    say ""
    say "Decky Loader isn't installed yet (there's no ~/homebrew folder), so the"
    say "theme will wait for it. Install Decky Loader from https://decky.xyz,"
    say "then CSS Loader from Decky's plugin store."
  fi
  plan_link "$themes/Jenerated-$SLUG" "$ROOT/app-themes/decky-theme/$SLUG"
  run_install_plan "the CSS Loader theme"

  step "Done! To turn the theme on, in Gaming Mode:"
  say "1. Open the Quick Access menu (the ... button on a Steam Deck), then"
  say "   Decky's plug icon, and choose CSS Loader."
  say "2. If CSS Loader was already running, scroll to the bottom and press"
  say "   Refresh so it finds the new theme."
  say "3. Turn on \"Jenerated $NAME\"."
  say "CSS Loader reads the theme from this folder, so after changing the"
  say "palette, press Refresh again. To go back to Steam's own colors, turn the"
  say "theme off."
}

# qt5ct and qt6ct each read color schemes from their own colors folder, and
# list each by its file name, so the link is named for the palette. The
# schemes do nothing until Qt apps use qt5ct or qt6ct (QT_QPA_PLATFORMTHEME),
# which KDE Plasma's own Qt integration replaces, so they never change KDE.
install_qtct() {
  local source="$ROOT/app-themes/qtct-theme/jenerated-$SLUG.conf" tool
  for tool in qt5ct qt6ct; do
    plan_link "${XDG_CONFIG_HOME:-$HOME/.config}/$tool/colors/Jenerated $NAME.conf" "$source"
  done
  run_install_plan "the qt5ct and qt6ct color scheme"

  step "Done! To turn the colors on:"
  say "1. Qt apps use qt6ct (or qt5ct, for Qt 5 apps) when QT_QPA_PLATFORMTHEME"
  say "   is set to it. If yours isn't, add QT_QPA_PLATFORMTHEME=qt6ct to"
  say "   /etc/environment (or ~/.profile), and log out and back in. (On KDE"
  say "   Plasma, leave it unset and use the KDE Plasma theme instead.)"
  say "2. Open Qt6 Settings (qt6ct): on the Appearance tab, choose Fusion as the"
  say "   style, then Custom palette and \"Jenerated $NAME\", and Apply. Do the"
  say "   same in Qt5 Settings (qt5ct) for Qt 5 apps."
  say "3. Restart your Qt apps."
  say "Apps started with sudo (like Legion) use root's settings, not yours. To"
  say "color them too, set up qt6ct for root the same way (sudo qt6ct), with the"
  say "scheme copied into /root/.config/qt6ct/colors."
  say "After changing the palette, run ./jenerate.py $SLUG and restart your Qt apps."
}

install_jellyfin() {
  local file="app-themes/jellyfin-theme/jenerated-$SLUG.css"

  step "Your Jellyfin CSS"
  say "It's in $ROOT/$file"
  if copy_to_clipboard <"$file" 2>/dev/null; then
    say "(Copied to your clipboard.)"
  else
    say "Open that file and copy everything in it."
  fi

  step "Done! To turn the theme on (Jellyfin is themed from inside the app):"
  say "For everyone on your server (as an administrator):"
  say "1. Open Dashboard -> Branding (Dashboard -> General in older versions)."
  say "2. Paste the CSS into Custom CSS code, replacing anything there, and"
  say "   save."
  say "Or just for one device:"
  say "1. Open Settings -> Display."
  say "2. Paste the CSS into the Custom CSS code box, and save."
  say "Choose Jellyfin's Dark theme for a dark palette, or Light for a light one."
  say "After changing the palette, run ./setup.sh again and paste the new CSS."
}

# OBS Studio's themes folders: the usual one, and, if OBS was installed
# through Flatpak, the folder Flatpak gives it.
obs_themes_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/obs-studio/themes"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio/themes"
  fi
  if [ -d "$HOME/.var/app/com.obsproject.Studio" ]; then
    printf '%s\n' "$HOME/.var/app/com.obsproject.Studio/config/obs-studio/themes"
  fi
  return 0
}

install_obs() {
  local file="jenerated-$SLUG.ovt"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(obs_themes_dirs)

  for dir in "${dirs[@]}"; do
    plan_link "$dir/$file" "$ROOT/app-themes/obs-theme/$file"
  done
  run_install_plan "the OBS Studio style"

  step "Done! To turn the style on, restart OBS Studio, then:"
  say "1. Open Settings -> Appearance."
  say "2. Choose Yami as the Theme, and \"Jenerated $NAME\" as the Style."
  say "After changing the palette, run ./jenerate.py $SLUG and restart OBS."
}

# Veilamp's skins folder: <data>/skins, where <data> is VEILAMP_DATA_DIR if
# set, or else Veilamp's data folder. Veilamp lists every folder there with a
# skin.json in it each time it starts, as it does the skin packages imported
# from its settings.
veilamp_skins_dir() {
  if [ -n "${VEILAMP_DATA_DIR:-}" ]; then
    printf '%s' "$VEILAMP_DATA_DIR/skins"
  elif [ "$OS" = "Darwin" ]; then
    printf '%s' "$HOME/Library/Application Support/com.veilamp.app/skins"
  else
    printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/com.veilamp.app/skins"
  fi
}

# The skin goes in as jenerated-<slug>, the folder Veilamp itself would make
# when importing it, so importing it from Veilamp later replaces it rather
# than adding a second copy.
install_veilamp() {
  local skins
  skins="$(veilamp_skins_dir)"

  plan_link "$skins/jenerated-$SLUG" "$ROOT/app-themes/veilamp-theme/$SLUG"
  run_install_plan "the Veilamp skin"

  step "Done! To turn the skin on:"
  say "1. Restart Veilamp if it's open; it looks for skins when it starts."
  say "2. Open the Skins tab (\"Skins\" in the top bar), and choose"
  say "   \"Jenerated $NAME\" as the palette, with the Modern, Circular or Sci-fi"
  say "   HUD layout. (Winamp Classic keeps its own colors.)"
  say "After changing the palette, run ./jenerate.py $SLUG and restart Veilamp."
  if [ "$INSTALL_MODE" = link ]; then
    say "Veilamp can't remove a linked skin itself (its remove button shows an"
    say "error); to remove it, delete $(shell_quote "$skins/jenerated-$SLUG")"
  fi
}

# Where Krita looks for color themes: the color-schemes folder in its
# resources folder, for a regular install and for the Flatpak.
krita_scheme_dirs() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/krita/color-schemes"
  else
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/krita/color-schemes"
  fi
  if [ -d "$HOME/.var/app/org.kde.krita" ]; then
    printf '%s\n' "$HOME/.var/app/org.kde.krita/data/krita/color-schemes"
  fi
  return 0
}

# Krita reads KDE color schemes, so it uses the KDE theme's .colors file.
install_krita() {
  local file="Jenerated-$SLUG.colors"
  local dir dirs=()

  # Collect the folders first: install_link may ask a question, which reads
  # your answer from standard input, which a "while read" loop would take over.
  while IFS= read -r dir; do dirs+=("$dir"); done < <(krita_scheme_dirs)

  for dir in "${dirs[@]}"; do
    plan_link "$dir/$file" "$ROOT/app-themes/kde-theme/$SLUG/$file"
  done
  run_install_plan "the Krita color theme"

  step "Done! To turn the theme on:"
  say "1. Restart Krita if it's open; it reads its themes when it starts."
  say "2. Choose Settings -> Themes -> \"Jenerated $NAME\"."
  say "After changing the palette, run ./jenerate.py $SLUG and restart Krita."
}

# Caido keeps its custom CSS in its own settings, so it's pasted in.
install_caido() {
  local file="app-themes/caido-theme/jenerated-$SLUG.css"
  local appearance=Dark
  grep -q 'color-scheme: light;' "$file" && appearance=Light

  step "Your Caido CSS"
  say "It's in $ROOT/$file"
  if copy_to_clipboard <"$file" 2>/dev/null; then
    say "(Copied to your clipboard.)"
  else
    say "Open that file and copy everything in it."
  fi

  step "Done! To turn the theme on (Caido is themed from inside the app):"
  say "1. In Caido, click your account button at the top right and choose"
  say "   Settings, then open the Appearance tab."
  say "2. Choose the $appearance appearance, to match the palette."
  say "3. Open Custom CSS, paste the CSS in, replacing anything there, and save."
  say "After changing the palette, run ./setup.sh again and paste the new CSS."
}

# Prints Ghidra's settings folders, one for each version that has run (the
# folder's name has the version in it): ghidra_<version> in ~/.config/ghidra
# on Linux (11.1 and later), in ~/Library/ghidra on macOS, and in the
# Flatpak's config folder, and .ghidra_<version> in ~/.ghidra from before 11.1.
ghidra_settings_dirs() {
  local dir
  for dir in "${XDG_CONFIG_HOME:-$HOME/.config}"/ghidra/ghidra_* "$HOME/Library/ghidra"/ghidra_* \
    "$HOME/.var/app/org.ghidra_sre.Ghidra/config/ghidra"/ghidra_* "$HOME/.ghidra"/.ghidra_*; do
    if [ -d "$dir" ]; then printf '%s\n' "$dir"; fi
  done
  return 0
}

install_ghidra() {
  local file="jenerated-$SLUG.theme"
  local source="$ROOT/app-themes/ghidra-theme/$file"
  local dir dirs=()

  while IFS= read -r dir; do dirs+=("$dir"); done < <(ghidra_settings_dirs)

  if [ "${#dirs[@]}" -eq 0 ]; then
    # Ghidra makes its settings folder the first time it runs, named for its
    # version, so there's nowhere to put the theme yet.
    step "No Ghidra settings folder found (Ghidra makes one the first time it runs)."
    say "To add the theme from Ghidra itself:"
    say "1. In Ghidra's project window, choose Edit -> Theme -> Import..., and"
    say "   choose $source"
    say "2. Choose Edit -> Theme -> Switch..., and pick \"Jenerated $NAME\"."
    say "Importing copies the theme, so import it again after changing the palette."
    return 0
  fi

  for dir in "${dirs[@]}"; do
    plan_link "$dir/themes/$file" "$source"
  done
  run_install_plan "the Ghidra theme"

  step "Done! To turn the theme on:"
  say "1. Restart Ghidra if it's open; it reads its themes when it starts."
  say "2. In the project window, choose Edit -> Theme -> Switch..., and pick"
  say "   \"Jenerated $NAME\"."
  say "After changing the palette, run ./jenerate.py $SLUG and restart Ghidra."
}

# Wireshark's personal settings folders: ~/.wireshark if there is one (an
# older Wireshark made it, and Wireshark still uses it then), otherwise its
# config folder; and the Flatpak's.
wireshark_config_dirs() {
  if [ -d "$HOME/.wireshark" ]; then
    printf '%s\n' "$HOME/.wireshark"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/wireshark"
  fi
  if [ -d "$HOME/.var/app/org.wireshark.Wireshark" ]; then
    printf '%s\n' "$HOME/.var/app/org.wireshark.Wireshark/config/wireshark"
  fi
  return 0
}

# The coloring rules go in a Wireshark profile of their own, "Jenerated
# <name>", so your own rules (in the Default profile) are left alone, and
# each palette is a profile to switch to.
install_wireshark() {
  local profile="Jenerated $NAME"
  local dir dirs=()

  while IFS= read -r dir; do dirs+=("$dir"); done < <(wireshark_config_dirs)

  for dir in "${dirs[@]}"; do
    plan_link "$dir/profiles/$profile/colorfilters" "$ROOT/app-themes/wireshark-theme/$SLUG/colorfilters"
  done
  run_install_plan "the Wireshark coloring rules"

  step "Done! To turn the colors on:"
  say "1. In Wireshark, right-click the profile name at the right end of the"
  say "   status bar (\"Default\" at first) and choose \"Jenerated $NAME\", or use"
  say "   Edit -> Configuration Profiles."
  say "2. Check that View -> Colorize Packet List is on."
  say "The profile holds just the coloring rules; Wireshark's other settings"
  say "start from their defaults in it."
  say "After changing the palette, run ./jenerate.py $SLUG and switch to the"
  say "profile again (or restart Wireshark)."
}

# The apps it can install Blue Purple into without Python, in menu order, on
# this system.
FALLBACK_IDS=()
FALLBACK_LABELS=()
add_fallback_app() {
  FALLBACK_IDS+=("$1")
  FALLBACK_LABELS+=("$2")
}
add_fallback_app chromium "Chromium browsers (Chrome, Brave, Edge, Opera and more)"
add_fallback_app mattermost "Mattermost"
add_fallback_app quassel "Quassel IRC"
add_fallback_app slack "Slack"
add_fallback_app emacs "Emacs"
if [ "$OS" = "Linux" ]; then add_fallback_app gtksourceview "GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)"; fi
add_fallback_app qtcreator "Qt Creator"
add_fallback_app rstudio "RStudio"
add_fallback_app sublime "Sublime Text"
add_fallback_app unreal "Unreal Engine"
add_fallback_app vim "Vim / Neovim"
add_fallback_app vscode "VS Code (and Code - OSS, VSCodium)"
if [ "$OS" = "Darwin" ]; then add_fallback_app xcode "Xcode"; fi
if [ "$OS" = "Linux" ]; then add_fallback_app ptyxis "Ptyxis (Ubuntu terminal)"; fi
if [ "$OS" = "Linux" ]; then add_fallback_app qterminal "QTerminal (LXQt's and Kali's terminal)"; fi
if [ "$OS" = "Linux" ]; then add_fallback_app tilix "Tilix (terminal)"; fi
if [ "$OS" = "Linux" ]; then add_fallback_app decky "Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)"; fi
if [ "$OS" = "Linux" ]; then add_fallback_app qtct "Qt apps outside KDE Plasma (qt5ct and qt6ct)"; fi
add_fallback_app jellyfin "Jellyfin (media server)"
add_fallback_app obs "OBS Studio (streaming and recording)"
add_fallback_app veilamp "Veilamp (music player)"
add_fallback_app krita "Krita (painting)"
add_fallback_app caido "Caido (web security testing)"
add_fallback_app ghidra "Ghidra (reverse engineering)"
add_fallback_app wireshark "Wireshark (network analyzer)"

# install_app id -> installs Blue Purple (NAME, SLUG) into one app.
install_app() {
  case "$1" in
    chromium) install_chromium ;;
    mattermost) install_mattermost ;;
    quassel) install_quassel ;;
    slack) install_slack ;;
    emacs) install_emacs ;;
    gtksourceview) install_gtksourceview ;;
    qtcreator) install_qtcreator ;;
    rstudio) install_rstudio ;;
    sublime) install_sublime ;;
    unreal) install_unreal ;;
    vim) install_vim ;;
    vscode) install_vscode ;;
    xcode) install_xcode ;;
    ptyxis) install_ptyxis ;;
    qterminal) install_qterminal ;;
    tilix) install_tilix ;;
    decky) install_decky ;;
    qtct) install_qtct ;;
    jellyfin) install_jellyfin ;;
    obs) install_obs ;;
    veilamp) install_veilamp ;;
    krita) install_krita ;;
    caido) install_caido ;;
    ghidra) install_ghidra ;;
    wireshark) install_wireshark ;;
  esac
}

say "Jenerated Themes setup"
say "======================"

[ -z "$DESIGN" ] ||
  die "the Palette Creator needs Python 3.11 or later (python3 --version to check)"

NAME="Blue Purple"
SLUG="blue-purple"

# --install=APP,PALETTE names the app (and palette) up front; without
# Python, only Blue Purple, and only an app from the list above.
APP=""
if [ -n "$INSTALL_REQUEST" ]; then
  APP="${INSTALL_REQUEST%%,*}"
  case "$INSTALL_REQUEST" in
    *,?*)
      palette="${INSTALL_REQUEST#*,}"
      [ "$palette" = blue-purple ] ||
        die "installing $palette needs Python 3.11 or later (python3 --version to check).
Without it, only Blue Purple can be installed (--install=$APP,blue-purple)."
      ;;
  esac
  if [ -n "$APP" ]; then
    case " ${FALLBACK_IDS[*]} " in
      *" $APP "*) ;;
      *) die "installing into $APP needs Python 3.11 or later (python3 --version to check).
Without it, Blue Purple can be installed into:
$(printf '%s, ' "${FALLBACK_IDS[@]}" | fold -s -w 76 | sed "s/ *$//; s/,$//")" ;;
    esac
  fi
fi

say ""
say "Python 3.11 or later wasn't found, so setup can only install Blue Purple,"
say "whose themes come with the repository. With Python, every palette and app"
say "is offered (python3 --version to check yours)."
if ! ask_yes "Install Blue Purple?"; then
  say ""
  say "Install Python 3.11 or later, then run ./setup.sh again."
  exit 0
fi

if [ -z "$APP" ]; then
  choose "Which app do you want to theme?" "${FALLBACK_LABELS[@]}"
  APP="${FALLBACK_IDS[$CHOICE]}"
fi

# How the theme's files are put in place: link (to this folder, so they
# update when the palette is regenerated), copy, or manual (you run the
# commands yourself). See run_install_plan.
INSTALL_MODE=link

step "Installing Blue Purple"
say "Using the Blue Purple files that come with the repository."
install_app "$APP"

if [ "$INSTALL_MODE" = copy ]; then
  say ""
  say "The files are copies; run ./setup.sh again if they ever need updating."
fi
say ""
say "Run ./setup.sh again any time to theme another app."
