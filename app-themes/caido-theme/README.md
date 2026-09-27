# Jenerated Themes for Caido

Custom CSS for [Caido](https://caido.io/), the web security testing toolkit.
[jenerate.py](../../jenerate.py) writes one `jenerated-<slug>.css` file for
each palette you generate, for example `jenerated-blue-purple.css`.

Caido builds its interface from a set of color variables, and the CSS sets
them from the palette: its backgrounds for pages, panels, menus and
selections; its text colors; its borders; its accent for primary buttons,
focus and highlights; and its red, green, orange and yellow, with the light
accent for info, for Caido's danger, success, warning, secondary and info
colors. It sets both the names current Caido uses (`--color-...`) and the
ones older versions use (`--c-...`).

The files are generated from `theme.css.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Caido keeps custom CSS in its own settings, so the CSS is pasted in rather
than installed as a file. `./setup.sh` from the repository root (choose
Caido) shows where the file is and copies it to your clipboard. Then, in
Caido:

1. Click your account button at the top right and choose **Settings**, then
   open the **Appearance** tab.
2. Choose the **Dark** appearance for a dark palette, or **Light** for a
   light one.
3. Open **Custom CSS**, paste in the contents of
   `app-themes/caido-theme/jenerated-blue-purple.css` (or your palette's
   file), replacing anything there, and save.

After changing the palette, run `./jenerate.py <slug>` (or `./setup.sh`
again) and paste the new CSS.
