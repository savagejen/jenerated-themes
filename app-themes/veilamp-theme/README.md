# Jenerated Themes for Veilamp

Skins for [Veilamp](https://veilamp.com/), the Winamp-inspired music player
(0.3.4 or later, which added skin packages). [jenerate.py](../../jenerate.py)
writes one skin for each palette you generate, as a `skin.json` in a folder
named after the palette, for example `blue-purple/skin.json`. Each shows up in
Veilamp as "Jenerated" plus the palette's name.

Veilamp's skins have two parts: a layout and a palette. These skins are
palettes, so they recolor the Modern, Circular and Sci-fi HUD layouts; the
Winamp Classic layout keeps its own colors. The skin sets:

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

The easiest way is `./setup.sh` from the repository root: choose Veilamp. It
links the skin's folder into Veilamp's `skins` folder, where Veilamp finds it
the next time it starts.

To install by hand, either:

- **Link it into Veilamp's skins folder**, so later changes to the palette
  show up after you restart Veilamp. The folder is
  `~/.local/share/com.veilamp.app/skins` on Linux and
  `~/Library/Application Support/com.veilamp.app/skins` on macOS (or `skins`
  in `VEILAMP_DATA_DIR`, if you set it). Run this from the folder where you
  ran `git clone`:

  ```bash
  mkdir -p ~/.local/share/com.veilamp.app/skins
  ln -s "$PWD/jenerated-themes/app-themes/veilamp-theme/blue-purple" ~/.local/share/com.veilamp.app/skins/jenerated-blue-purple
  ```

  Veilamp can't remove a linked skin itself (its remove button shows an
  error), so to remove it, delete the link. Or:
- **Import it in Veilamp:** open the **Skins** tab ("Skins" in the top bar),
  and under **Palette**, choose **Import theme...** and pick
  `jenerated-themes/app-themes/veilamp-theme/blue-purple/skin.json`.
  Importing copies the skin, so import it again after changing the palette;
  it replaces the one you imported before.

Then restart Veilamp if it's open, open the **Skins** tab, and choose
**Jenerated Blue Purple** as the palette, with the Modern, Circular or Sci-fi
HUD layout.

## Skin format

A Veilamp skin is a JSON file with a `name`, an optional `author` and
`description`, and a `vars` map of the CSS custom properties it changes
(`--cyan`, `--bg-1`, `--text` and so on). Veilamp ignores any it doesn't know,
and uses its default for any left out. A folder with a `skin.json` in it is a
skin package, which can also hold fonts and images; these skins don't need
any.
