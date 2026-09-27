# Jenerated Themes for Krita

Color themes for [Krita](https://krita.org/), the painting app. Krita's
themes are KDE color schemes, so it uses the same file as the
[KDE Plasma theme](../kde-theme/): `app-themes/kde-theme/<slug>/Jenerated-<slug>.colors`,
written by [jenerate.py](../../jenerate.py) for each palette you generate. It
shows up in Krita as "Jenerated" plus the palette's name, and colors Krita's
windows, dockers and menus; your canvas and brushes are untouched.

To change colors, see [Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Krita. To
install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the color scheme into the `color-schemes` folder of
   Krita's resources folder. A symlink means later changes to the palette
   show up after you restart Krita. Run these from the same folder where you
   ran `git clone`. (In Krita, Settings -> Manage Resources -> Open Resources
   Folder shows where yours is: `~/.local/share/krita` on Linux,
   `~/.var/app/org.kde.krita/data/krita` for the Flatpak, and
   `~/Library/Application Support/krita` on macOS.)

   ```bash
   mkdir -p ~/.local/share/krita/color-schemes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colors" ~/.local/share/krita/color-schemes/

   # Or copy
   cp ./jenerated-themes/app-themes/kde-theme/blue-purple/Jenerated-blue-purple.colors ~/.local/share/krita/color-schemes/
   ```

3. Restart Krita if it's open; it reads its themes when it starts.

4. Choose **Settings -> Themes -> Jenerated Blue Purple**.
