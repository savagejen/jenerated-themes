# Jenerated Themes for Veilamp

Skins for [Veilamp](https://veilamp.com/), the Winamp-inspired music player
(a version after 0.3.6, with the skin picker in Settings -> Appearance).
[jenerate.py](../../jenerate.py)
writes one skin for each palette you generate, as a `skin.json` in a folder
named after the palette, for example `blue-purple/skin.json`. Each shows up in
Veilamp as "Jenerated" plus the palette's name.

A Veilamp skin can bring a layout, graphics and visualizations as well as
colors. These skins are colors only: picking one recolors the layout you're
using, if it's Modern, Circular, Sci-fi HUD or Neonwave. The Classic and
LCARS layouts keep their own colors. The skin sets:

- **Its three accent colors** from the palette's accent (Veilamp's main
  highlight color), soft accent and light accent, with dimmer shades mixed
  toward the background, and the accent gradient and glows from the first
  two.
- **Its backgrounds, panels and text** from the palette's: the window
  background shading from the editor background into the darker chrome color
  with a faint glow of the accent, translucent panels in the popup color, and
  three levels of text, and the color of text on the accent (badges and
  buttons).

Fonts and the window's shape stay as Veilamp sets them.

The files are generated from `theme.json.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `jenerate` (or `./setup.sh` in a clone): choose Veilamp.
It links the skin's folder into Veilamp's `skins` folder, where Veilamp finds
it the next time it starts.

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
- **Add it in Veilamp:** open **Settings -> Appearance**, choose
  **From folder...**, and pick the
  `jenerated-themes/app-themes/veilamp-theme/blue-purple` folder. Veilamp
  copies the skin and switches to it, so add it again after changing the
  palette; it replaces the one you added before.

Then restart Veilamp if it's open, open **Settings -> Appearance**, and click
the **Jenerated Blue Purple** skin. It recolors the layout you're using; for
another layout, click that layout's skin first, then **Jenerated Blue
Purple**.

## Skin format

A Veilamp skin is a JSON file with a `name`, an optional `author` and
`description`, and a `vars` map of the CSS custom properties it changes
(`--cyan`, `--bg-1`, `--text` and so on). Veilamp ignores any it doesn't know,
and uses its default for any left out. A folder with a `skin.json` in it is a
skin package, which can also hold fonts and images; these skins don't need
any.
