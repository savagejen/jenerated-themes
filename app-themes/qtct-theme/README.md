# Jenerated Themes for Qt apps outside KDE Plasma

Color schemes for [qt5ct and qt6ct](https://github.com/trialuser02/qt6ct),
the tools that set how Qt apps look on desktops other than KDE Plasma:
GNOME, Xfce, Cinnamon, MATE, window managers and so on. With one of these
schemes chosen, Qt apps take the palette's colors: Legion, Wireshark's
windows, VLC, qBittorrent, KeePassXC and any other Qt app that doesn't set
its own. [jenerate.py](../../jenerate.py) writes one
`jenerated-<slug>.conf` file for each palette you generate, and the same
file works for both qt5ct (Qt 5 apps) and qt6ct (Qt 6 apps).

The colors follow the [KDE Plasma color scheme](../kde-theme/), so Qt apps
look the same on either kind of desktop: windows in the palette's sidebar
color, views and text fields in its editor background, buttons in its hover
color, and selections in its accent.

**On KDE Plasma, use the KDE Plasma theme instead.** Plasma's own Qt
integration colors Qt apps from its color scheme, and qt5ct and qt6ct only
take over when an app starts with `QT_QPA_PLATFORMTHEME` set to them, which
Plasma doesn't do. So installing these schemes never changes anything on
Plasma.

The files are generated from `colors.conf.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose "Qt apps
outside KDE Plasma". To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the scheme into qt6ct's and qt5ct's `colors` folders.
   Each lists a scheme by its file name, so name it for the palette. A
   symlink means later changes to the palette show up when you restart your
   Qt apps. Run these from the same folder where you ran `git clone`.

   ```bash
   mkdir -p ~/.config/qt6ct/colors ~/.config/qt5ct/colors
   ln -s "$PWD/jenerated-themes/app-themes/qtct-theme/jenerated-blue-purple.conf" ~/.config/qt6ct/colors/"Jenerated Blue Purple.conf"
   ln -s "$PWD/jenerated-themes/app-themes/qtct-theme/jenerated-blue-purple.conf" ~/.config/qt5ct/colors/"Jenerated Blue Purple.conf"
   ```

3. Qt apps use qt6ct (or qt5ct, for Qt 5 apps) when the
   `QT_QPA_PLATFORMTHEME` environment variable is set to it. If yours isn't,
   add this line to `/etc/environment` (or export it from `~/.profile`), and
   log out and back in:

   ```bash
   QT_QPA_PLATFORMTHEME=qt6ct
   ```

4. Open **Qt6 Settings** (qt6ct). On the **Appearance** tab, choose
   **Fusion** as the style, then **Custom** palette and **Jenerated Blue
   Purple**, and click **Apply**. Do the same in **Qt5 Settings** (qt5ct) for
   Qt 5 apps.

5. Restart your Qt apps.

Apps started with `sudo`, like Legion, use root's settings rather than
yours. To color them too, set up qt6ct for root the same way (`sudo qt6ct`),
with the scheme copied into `/root/.config/qt6ct/colors`.

## Color scheme format

A qt5ct or qt6ct color scheme is a small INI file with a `[ColorScheme]`
section. `active_colors`, `inactive_colors` and `disabled_colors` each list
Qt's 21 palette colors (window text, button, the four bevel shades, text,
bright text, button text, base, window, shadow, highlight, highlighted text,
link, visited link, alternate base, no role, tooltip base, tooltip text and
placeholder text), as `#aarrggbb`.
