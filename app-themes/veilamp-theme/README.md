# Jenerated Themes for Veilamp

> **Switched off for now.** Importing any palette (even Veilamp's own
> template) sends Veilamp into a loop that restarts the app over and over
> until it crashes

Palettes for [Veilamp](https://veilamp.com/), the Winamp-inspired music
player. [jenerate.py](../../jenerate.py) writes one `jenerated-<slug>.json`
theme file for each palette you generate, for example
`jenerated-blue-purple.json`, named "Jenerated" plus the palette's name.

Veilamp's skins have two parts: a layout and a palette. These themes are
palettes, so they recolor the Modern, Circular and Sci-fi HUD layouts; the
Winamp Classic layout keeps its own colors. The theme sets:

- **Its three accent colors** from the palette's accent (Veilamp's main
  highlight color), soft accent and light accent, with dimmer shades mixed
  toward the background, and the accent gradient and glows from the first
  two.
- **Its backgrounds, panels and text** from the palette's: the window
  background shading from the editor background into the darker chrome color
  with a faint glow of the accent, translucent panels in the popup color, and
  three levels of text.

Fonts and the window's shape stay as Veilamp sets them.

The files are generated from `theme.json.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Veilamp keeps imported palettes in its own settings, so the theme is imported
from inside the app. `./setup.sh` from the repository root (choose Veilamp)
shows where the file is. Then, in Veilamp:

1. Open the **Skins** tab ("Skins" in the top bar).
2. Under **Palette**, choose **Import**, and pick
   `app-themes/veilamp-theme/jenerated-blue-purple.json` (or your palette's
   file).
3. Choose **Jenerated Blue Purple** as the palette, with the Modern,
   Circular or Sci-fi HUD layout.

After changing the palette, run `./jenerate.py <slug>` and import it again; it
replaces the one you imported before.

## Theme file format

A Veilamp theme is a JSON file with a `name`, an optional `author`, and a
`vars` map of the CSS custom properties it changes (`--cyan`, `--bg-1`,
`--text` and so on). Veilamp ignores any it doesn't know, and uses its
default for any left out.
