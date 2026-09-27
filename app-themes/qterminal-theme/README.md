# Jenerated Themes for QTerminal

Color schemes for [QTerminal](https://github.com/lxqt/qterminal), the
terminal of the LXQt desktop and Kali Linux. QTerminal's terminal
(qtermwidget) reads Konsole's color scheme format, so it uses the same file
as the [KDE Plasma theme](../kde-theme/)'s Konsole scheme:
`app-themes/kde-theme/<slug>/Jenerated-<slug>.colorscheme`, written by
[jenerate.py](../../jenerate.py) for each palette you generate. It has the
same 16 terminal colors as the Tilix, Ptyxis and Konsole themes.

To change colors, see [Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose QTerminal.
To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the scheme into `~/.local/share/qterminal/color-schemes`.
   QTerminal lists each scheme by its file name, so name it for the palette.
   A symlink means later changes to the palette show up after you restart
   QTerminal. Run these from the same folder where you ran `git clone`.

   ```bash
   mkdir -p ~/.local/share/qterminal/color-schemes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colorscheme" ~/.local/share/qterminal/color-schemes/"Jenerated Blue Purple.colorscheme"

   # Or copy
   cp ./jenerated-themes/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colorscheme ~/.local/share/qterminal/color-schemes/"Jenerated Blue Purple.colorscheme"
   ```

3. Close every QTerminal window and open QTerminal again; it reads its color
   schemes when it starts.

4. Open **File -> Preferences**, and on the **Appearance** tab choose
   **Jenerated Blue Purple** as the **Color scheme**.
