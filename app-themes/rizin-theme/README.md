# Jenerated Themes for rizin

Color themes for [rizin](https://rizin.re/), the reverse engineering framework, and
Cutter, its graphical interface. [jenerate.py](../../jenerate.py) writes one
`jenerated-<slug>` file for each palette you generate, for example
`jenerated-blue-purple`, loaded in rizin with `eco jenerated-<slug>`.

Rizin is a fork of [radare2](../radare2-theme/), and the themes match
radare2's, with rizin's names for its colors (it calls addresses `offset`,
for example).

The themes color rizin's code the same way the editor themes color code:
comments in the palette's muted text, jumps and pushes like keywords (its
soft accent), calls like functions (its light accent), registers and types in
cyan, numbers in orange, printable bytes in green, and graph edges green for
taken and red for not taken. The current line and highlighted words get the
palette's line highlight and selection colors behind them.

The colors are exact with 24-bit color on (`e scr.color=3`); with fewer
colors, rizin picks the nearest ones.

The files are generated from `theme.rz.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose rizin. It
links the theme into rizin's themes folder, and offers to load it every time
rizin starts. To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the theme into `~/.local/share/rizin/cons`, where rizin
   looks for themes. A symlink means later changes to the palette show up
   the next time you load it. Run these from the same folder where you ran
   `git clone`.

   ```bash
   mkdir -p ~/.local/share/rizin/cons

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/rizin-theme/jenerated-blue-purple" ~/.local/share/rizin/cons/

   # Or copy
   cp ./jenerated-themes/app-themes/rizin-theme/jenerated-blue-purple ~/.local/share/rizin/cons/
   ```

3. Load it every time rizin starts, by adding these lines to
   `~/.config/rizin/rizinrc` (or `~/.rizinrc`, if you have one):

   ```
   e scr.color=3
   eco jenerated-blue-purple
   ```

   Or try it in a running rizin by typing them there.

## Theme file format

A rizin theme is a list of rizin commands: `ecd` resets the colors to the
defaults, then each `ec <name> <color>` sets one, as `rgb:RRGGBB`. A second
color after the first sets the background, which the current line, the
highlighted word and the widgets use. Lines starting with `#` are comments.
