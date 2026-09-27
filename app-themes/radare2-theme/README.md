# Jenerated Themes for radare2

Color themes for [radare2](https://rada.re/), the reverse engineering framework, and
Iaito, its graphical interface. [jenerate.py](../../jenerate.py) writes one
`jenerated-<slug>` file for each palette you generate, for example
`jenerated-blue-purple`, loaded in radare2 with `eco jenerated-<slug>`.

Rizin, the fork of radare2, names some colors differently, so it has
[its own themes](../rizin-theme/).

The themes color radare2's code the same way the editor themes color code:
comments in the palette's muted text, jumps and pushes like keywords (its
soft accent), calls like functions (its light accent), registers and types in
cyan, numbers in orange, printable bytes in green, and graph edges green for
taken and red for not taken. The current line and highlighted words get the
palette's line highlight and selection colors behind them.

The colors are exact with 24-bit color on (`e scr.color=3`); with fewer
colors, radare2 picks the nearest ones.

The files are generated from `theme.r2.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose radare2. It
links the theme into radare2's themes folder, and offers to load it every time
radare2 starts. To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the theme into `~/.local/share/radare2/cons`, where radare2
   looks for themes. A symlink means later changes to the palette show up
   the next time you load it. Run these from the same folder where you ran
   `git clone`.

   ```bash
   mkdir -p ~/.local/share/radare2/cons

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/radare2-theme/jenerated-blue-purple" ~/.local/share/radare2/cons/

   # Or copy
   cp ./jenerated-themes/app-themes/radare2-theme/jenerated-blue-purple ~/.local/share/radare2/cons/
   ```

3. Load it every time radare2 starts, by adding these lines to `~/.radare2rc`:

   ```
   e scr.color=3
   eco jenerated-blue-purple
   ```

   Or try it in a running radare2 by typing them there.

## Theme file format

A radare2 theme is a list of radare2 commands: `ecd` resets the colors to the
defaults, then each `ec <name> <color>` sets one, as `rgb:RRGGBB`. A second
color after the first sets the background, which the current line, the
highlighted word and the widgets use. Lines starting with `#` are comments.
