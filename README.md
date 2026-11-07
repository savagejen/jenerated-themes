# Jenerated Themes

A small theming engine: pick a color palette, and `jenerate` (the
Jenerator) turns it into matching themes for every supported app. You only
get the palettes you ask for, so your apps' theme lists stay short.

The default palette, **Blue Purple**, comes already generated, so you can
install it in any app without running anything.

![VS Code with the Jenerated Blue Purple theme: the Explorer sidebar and a Python file in the editor](Screenshot.png)

## Supported apps

Each app has its own folder with a template and install instructions. They're
grouped the same way as in `jenerate`, which can also search for an app by
name. Apps marked (Linux) or (macOS), and the Linux desktops, are only
offered on that system.

### Web browsers

- [Chromium browsers (Chrome, Brave, Edge, Opera and more)](app-themes/chromium-theme/)
- [Firefox](app-themes/firefox-theme/)
- [Vivaldi](app-themes/vivaldi-theme/)
- [Zen Browser](app-themes/zen-theme/)

### Communication

- [Element (Matrix chat)](app-themes/element-theme/)
- [Mattermost](app-themes/mattermost-theme/)
- [Quassel IRC](app-themes/quassel-theme/)
- [Slack](app-themes/slack-theme/)

### Editors: code, text and notes

- [Emacs](app-themes/emacs-theme/)
- [GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)](app-themes/gtksourceview-theme/) (Linux)
- [Godot](app-themes/godot-theme/)
- [JetBrains apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)](app-themes/jetbrains-theme/)
- [LibreOffice (Writer, Calc, Impress and more)](app-themes/libreoffice-theme/)
- [Obsidian](app-themes/obsidian-theme/)
- [Qt Creator](app-themes/qtcreator-theme/)
- [RStudio](app-themes/rstudio-theme/)
- [Spyder](app-themes/spyder-theme/)
- [Sublime Text](app-themes/sublime-theme/)
- [Unreal Engine](app-themes/unreal-theme/)
- [Vim and Neovim](app-themes/vim-theme/)
- [VS Code (and Code - OSS, VSCodium)](app-themes/vs-code-theme/)
- [Xcode](app-themes/xcode-theme/) (macOS)

### Terminals and command-line tools

- [fzf (fuzzy finder)](app-themes/fzf-theme/)
- [Gemini CLI](app-themes/gemini-theme/)
- [PowerShell (pwsh)](app-themes/pwsh-theme/)
- [Ptyxis (Ubuntu terminal)](app-themes/ptyxis-theme/) (Linux)
- [QTerminal (LXQt's and Kali's terminal)](app-themes/qterminal-theme/) (Linux)
- [Tilix (terminal)](app-themes/tilix-theme/) (Linux)
- [tmux](app-themes/tmux-theme/)
- [zsh (syntax highlighting and suggestions)](app-themes/zsh-theme/)

### Linux desktops

- [Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)](app-themes/decky-theme/)
- [GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)](app-themes/gtk3-theme/)
- [KDE Plasma (Plasma and KDE apps, Konsole, Kate)](app-themes/kde-theme/)
- [Qt apps outside KDE Plasma (qt5ct and qt6ct)](app-themes/qtct-theme/)

### Entertainment

- [Jellyfin (media server)](app-themes/jellyfin-theme/)
- [mpv (media player)](app-themes/mpv-theme/)
- [OBS Studio (streaming and recording)](app-themes/obs-theme/)
- [Veilamp (music player)](app-themes/veilamp-theme/)

### Art and design

- [Krita (painting)](app-themes/krita-theme/)

### Hacking and testing tools

- [Caido (web security testing)](app-themes/caido-theme/)
- [Ghidra (reverse engineering)](app-themes/ghidra-theme/)
- [Insomnia (API client)](app-themes/insomnia-theme/)
- [radare2 (reverse engineering)](app-themes/radare2-theme/)
- [rizin (reverse engineering)](app-themes/rizin-theme/)
- [Wireshark (network analyzer)](app-themes/wireshark-theme/)

## Themes

A few premade palettes are included, dark and light, and can be previewed in
[palettes/README.md](palettes/README.md).

## Install

### With pipx (recommended)

Jenerated Themes needs Python 3.11 or later (`python3 --version` to check),
which current Linux systems come with. [pipx](https://pipx.pypa.io/)
installs it as the `jenerate` command, in a place of its own.

1. Install pipx, if you don't have it, with the line for your system, then
   run `pipx ensurepath` and open a new terminal, so the commands pipx
   installs can be found:

   ```bash
   sudo apt install pipx         # Ubuntu, Debian, Kali
   sudo dnf install pipx         # Fedora
   sudo pacman -S python-pipx    # Arch
   brew install pipx             # macOS, with Homebrew
   pipx ensurepath
   ```

2. Install Jenerated Themes:

   ```bash
   pipx install jenerate-themes
   ```

3. Run it, and choose an app and a theme:

   ```bash
   jenerate
   ```

To update it later, run `pipx upgrade jenerate-themes`. To uninstall it, run
`pipx uninstall jenerate-themes`. The themes and palettes you made are kept
in your [data folder](#where-your-themes-and-palettes-are); delete that too
once you've switched your apps to other themes, since they use the files
there.

### From a clone, with setup.sh

You can also clone the repository and run the setup script, which works the
same way:

```bash
git clone https://github.com/savagejen/jenerated-themes jenerated-themes
cd jenerated-themes
./setup.sh
```

It needs Python 3.11 or later too; without it, it offers to install the
Blue Purple theme into the apps where that only takes linking a few files
into place, or pasting a theme in. Run `git pull` in the folder to update
it.

It is designed to work on Linux or macOS, but some of the themes function on
other platforms, where the `jenerate` command (installed with pipx, above)
can make them. See [Setting up by hand](#setting-up-by-hand) below.

## Using it

`jenerate` (or `./setup.sh`, in a clone) asks which app and which theme you
want (dark or light, then which one), and it can also open the palette
previews in your browser. For most apps, it first shows the commands that
install the theme, then offers to run them for you, linking the files (so
they follow palette changes) or copying them. It can also start the
[Palette Creator](palette-creator/), for designing a palette of your own.

`jenerate --help` (or `./setup.sh --help`) lists the shortcuts, like going
straight to installing a particular palette into a particular app, or
straight to the Palette Creator.

To theme everything at once, choose **ALL THE APPS** in the app menu: it
installs one palette into every app it finds on your computer that it can
install into by itself, without asking anything else once you've said yes.
Apps it doesn't find are left out, and listed. (Apps whose themes are
installed by hand, like most browsers and Slack, are left out and listed.)
Or, for one app that keeps several themes to choose from (VS Code, Vim, the
terminals and most editors), choose **ALL THE PALETTES** at the dark or
light question, to install every palette into it.

### Where your themes and palettes are

|                               | Installed with pipx                         | A clone                              |
|-------------------------------|---------------------------------------------|--------------------------------------|
| Your palettes                 | `~/.local/share/jenerate-themes/palettes`   | `palettes/`                          |
| Generated themes              | `~/.local/share/jenerate-themes/app-themes` | `app-themes/`, next to the templates |
| Generating a palette's themes | `jenerate generate sunset`                  | `./jenerate.py sunset`               |

On macOS, the data folder is `~/Library/Application Support/jenerate-themes`
instead of `~/.local/share/jenerate-themes`. The palettes that come with
Jenerated Themes are listed with yours, and one of yours with the same short
name takes its place.

### Setting up by hand

To use the default Blue Purple theme, clone the repository and follow the
install steps in each app's folder. To add other palettes (needs Python 3.11
or later):

1. Clone this repository:

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   cd jenerated-themes
   ```

2. See which palettes are available (also listed under [Themes](#themes)):

   ```bash
   ./jenerate.py --list
   ```

3. Generate themes for the palettes you want, by short name. Separate several
   with commas, or run it again later to add more:

   ```bash
   ./jenerate.py sunset
   ./jenerate.py sunset,another-palette
   ```

4. Follow the install steps in each app's folder.

To remove a palette's themes again, run `./jenerate.py --remove sunset`.

## How it works

A palette is a small file that names each color by its role: the editor
background, text, the accent, error red, the terminal's colors and so on.
The ones that come with Jenerated Themes are in [palettes/Dark](palettes/Dark/)
and [palettes/Light](palettes/Light/). Jenerated Themes fills those colors
into a template for each app, and writes the themes named after the
palette, in your [data folder](#where-your-themes-and-palettes-are) or,
in a clone, next to the templates. Themes you generated earlier are kept.

In a clone, generated themes stay out of git, so your copy holds only the
palettes you chose. Don't edit generated themes by hand; change the palette
and generate its themes again.

## Light and dark palettes

Palettes can be dark or light. `jenerate.py` works out which from the
palette's editor background (`bg`): a palette is light if black text reads
better on it than white. A palette can also say which it is, with
`scheme = "dark"` or `scheme = "light"` after its `short_name`. The themes
follow:
VS Code and Firefox mark the theme dark or light, JetBrains themes build on
the IDE's dark or light theme, GTK3 themes on Adwaita's dark or light
version, Obsidian and Vim tell the app which it is, Godot uses its own
contrast setting for dark or light, and Chromium picks matching search
logos for the new tab page. Several others (among them Element, Mattermost,
Zen and the GNOME text editors) also mark the theme dark or light or adjust
a few details to match. The rest just use the palette's colors.

Two text colors matter most for light palettes: `text_bright` is text on the
accent color (buttons, badges, selected menu items), and `text_strong` is
emphasized text on ordinary backgrounds (the active tab, the selected file).
On a dark palette both are usually white, so `text_strong = "text_bright"`;
on a light palette `text_bright` stays light for the accent, and
`text_strong` is dark, often just `"text"`.

## Changing colors

Edit one of your palettes, then generate its themes again
(`jenerate generate sunset`, or `./jenerate.py sunset` in a clone), and reload the
apps that use it to see the change. To change a palette that came with
Jenerated Themes, copy it into your palettes folder first (see
[Where your themes and palettes are](#where-your-themes-and-palettes-are)),
or load it into the [Palette Creator](palette-creator/) and save it from
there: yours takes its place. In a clone, you can edit the palettes in
`palettes/` directly.

You can also keep a palette anywhere else and give its path:
`jenerate generate ~/my-palettes/forest-palette.toml`.

## Adding a palette

The easiest way is the [Palette Creator](palette-creator/): run `jenerate`
(or `./setup.sh`) and choose **Design a new palette** (`--help` lists a
shortcut straight to it). It shows a preview in your browser that recolors
as you edit. Save the palette (it goes in your palettes folder's `Dark` or
`Light`, to match it), and it asks whether to install it into your apps
now, or keep designing and install it later from the menu.

To write one by hand, copy an existing palette to
`Dark/<short-name>-palette.toml` or `Light/<short-name>-palette.toml` in your
palettes folder, change its `name`, `short_name` and colors, and generate
its themes. Every color the templates use
must be defined; if one is missing, Jenerated Themes stops and names it.

A few rules keep generated files safe and valid; Jenerated Themes checks
them and explains any that a palette breaks:

- The `short_name` is used in file names, so it's lowercase letters,
  numbers and single dashes, like `deep-blue-sea`.
- A palette in your palettes folder's `Dark` or `Light` must be named
  `<short-name>-palette.toml`, and a short name can only be used once there.
  (A palette kept elsewhere and given by its path can be named anything.)
- The `name` can't be empty, start or end with spaces, or contain double
  quotes, slashes, backslashes, `<`, `>`, `&` or line breaks. (It's written
  into JSON and XML files, and also names the Obsidian theme's folder.)
- Every color is a quoted string: `"#rrggbb"` or another color's name.
- `scheme` is optional: `"dark"` or `"light"`, for a palette whose editor
  background (`bg`) doesn't make that clear. See
  [Light and dark palettes](#light-and-dark-palettes).

## Contributing

To share a palette, add support for an app, or work on the project itself,
see [CONTRIBUTING.md](CONTRIBUTING.md). It covers how the templates work,
adding palettes and apps, the tests, screenshots, and the license.

## License

[MIT](LICENSE).
