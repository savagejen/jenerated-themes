# Jenerated Themes for Ghidra

Themes for [Ghidra](https://ghidra-sre.org/), the reverse engineering suite
(11.0 or later, which added themes). [jenerate.py](../../jenerate.py) writes
one `jenerated-<slug>.theme` file for each palette you generate, for example
`jenerated-blue-purple.theme`. Each shows up in Ghidra as "Jenerated" plus
the palette's name.

A theme colors Ghidra's windows, tables and panels, and its code views in
the same roles as the editor themes:

- **Decompiler:** comments in the palette's muted text, keywords in its soft
  accent, function names in its light accent, types in cyan, constants in
  magenta, parameters in orange.
- **Listing:** mnemonics like keywords, registers in cyan, labels in yellow,
  cross-references in green, comments muted, raw bytes in the subtle text.
- **Overview bar and bookmarks** in the palette's accent and status colors.

Dark palettes use Ghidra's Flat Dark look, and light ones its Flat Light.

The files are generated from `theme.theme.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Ghidra. It
links the theme into the `themes` folder of each Ghidra version's settings
folder it finds. Ghidra makes that folder the first time it runs; before
that, setup explains how to import the theme from Ghidra instead.

To install by hand, either:

- **Import it in Ghidra:** in the project window, choose **Edit -> Theme ->
  Import...** and choose
  `jenerated-themes/app-themes/ghidra-theme/jenerated-blue-purple.theme`.
  Importing copies the theme, so import it again after changing the
  palette. Or:
- **Link it into Ghidra's settings folder**, so later changes to the palette
  show up after you restart Ghidra. The folder is named after your Ghidra
  version; Help -> Runtime Information -> Application Layout shows it as
  "Settings Directory". It's `~/.config/ghidra/ghidra_<version>` on Linux,
  `~/Library/ghidra/ghidra_<version>` on macOS, and
  `~/.ghidra/.ghidra_<version>` before Ghidra 11.1. Run this from the folder
  where you ran `git clone`, with your version's folder:

  ```bash
  mkdir -p ~/.config/ghidra/ghidra_11.4_PUBLIC/themes
  ln -s "$PWD/jenerated-themes/app-themes/ghidra-theme/jenerated-blue-purple.theme" ~/.config/ghidra/ghidra_11.4_PUBLIC/themes/
  ```

Then, in the project window, choose **Edit -> Theme -> Switch...** and pick
**Jenerated Blue Purple**.

## Theme file format

A Ghidra theme is a text file of `name = value` lines: the theme's name, its
look and feel, whether it builds on the dark defaults, then the colors it
changes, by Ghidra's names for them (`color.fg.decompiler.keyword`, and
`[color]system.color.bg.view` for the colors Ghidra's own windows use).
Lines starting with `//` are comments.
