# Palette Creator

A page for designing a palette in your browser. It shows a generic app window
(an editor with syntax colors, a sidebar, tabs, a terminal, buttons, inputs,
notifications and a diff) built only from the palette's colors, and recolors
it as you edit.

## Start it

Needs Python 3.11 or later. Run `./setup.sh` from the repository root and
choose **Design a new palette**; it explains the steps below, then starts
the Palette Creator. Or go straight to it:

```bash
./setup.sh --design
```

It opens the page in your browser. Press `Ctrl+C` in the terminal to stop
it. The page only works while the Palette Creator is running, and only from
this computer.

The Palette Creator's code is in
[jenerate_themes/creator](../jenerate_themes/creator/): `serve.py` and the
page, `palette-creator.html`. To start it with options (`--no-browser` to
just print the address, or `--port` to pick a port), run it from the
repository root as `python3 -m jenerate_themes.creator.serve --no-browser`.

It uses port 8765, or the next free one if another program has it. If the
Palette Creator is already running there from this folder (left open in
another terminal, say), it asks whether to open that one in your browser, or
stop it and start a fresh one. Start a fresh one after updating the
repository, so the page and the server are the new versions.

## Design a palette

- **Your draft:** the page edits `work-in-progress-palette.toml` in this
  folder, and saves it automatically as you go (whenever the palette is
  valid; if it isn't, the draft is kept as it was until you fix it). It's
  created from Blue Purple the first time you start the Palette Creator, and
  git ignores it, so your drafts stay yours.
- **Description:** the comment at the top of the palette file: what the
  palette is and where its colors come from. Blank lines separate
  paragraphs. It's wrapped to fit the file when saved, and the file's usual
  note about how colors are written stays after it.
- **Load from...:** replaces your draft with a palette you choose in
  your computer's file dialog, which opens in `palettes/` (you can also pick
  a palette kept elsewhere). It warns you first, since anything in the work
  in progress that you haven't saved as a palette is lost. The palette is
  copied exactly, comments and all, and one `jenerate.py` would reject is
  refused, leaving your work in progress alone. Without a file dialog, the
  page lists the palettes in `palettes/Dark` and `palettes/Light` and asks
  which one.
- **Colors:** each color has a color picker, and a text field that takes a
  `#rrggbb` value or another color's name (like `red`), just as in a palette
  file. A color that refers to another shows what it resolves to.
- **Finding colors:** hover over a color to highlight where the preview uses
  it (including colors that refer to it), or click part of the preview to
  jump to its color.
- **Checking:** the page checks the palette with `jenerate.py`'s own rules as
  you type, and shows what's wrong, such as a short name with capitals or a
  color the templates need. Hot pink in the preview means a color is missing
  or invalid.

## Save it

- **Save as palette...** opens your computer's save dialog in `palettes/Dark`
  or `palettes/Light`, whichever the palette is, suggesting
  `<short-name>-palette.toml` (for example `sunset-palette.toml`). Keep that
  name: `jenerate.py` finds palettes there by their short name, so it won't
  accept another name. You can also save somewhere else and pass the file's
  path to `jenerate.py`. The dialog is `zenity` or `kdialog` on Linux, or the
  standard one on macOS; without one, the page asks for a file name instead.
- **Install it, or keep designing:** once it's saved, the page asks whether
  to install it into your apps now. Choosing to install closes the Palette
  Creator, and the terminal you started it from goes on to the app menu
  with your palette already chosen (ALL THE APPS is there too). Choosing to
  keep designing leaves it saved; install it later by running `./setup.sh`
  again and choosing **Install a theme**. A palette saved outside
  `palettes/` isn't offered: generate its themes with
  `./jenerate.py path/to/your-palette.toml`, then follow the install steps
  in each app's folder.

Saving keeps the palette file's layout: its header comments, its groups of
colors with their titles, and each color's note.
