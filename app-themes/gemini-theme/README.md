# Jenerated Themes for Gemini CLI

Color themes for [Gemini CLI](https://github.com/google-gemini/gemini-cli),
the terminal AI assistant. [jenerate.py](../../jenerate.py) writes one
`jenerated-<slug>.json` theme file for each palette you generate, for example
`jenerated-blue-purple.json`, named "Jenerated" plus the palette's name.

The theme sets Gemini CLI's colors from the palette: its background and
text; its keyword color for links and for keywords and types in code (Gemini
CLI uses one color for both); its accent for highlights, focus and borders;
its green, yellow and red for success, warnings and errors; its muted text
for comments; and green and red tints of its background behind added and
removed lines in diffs. The banner's gradient runs through its three accent
colors.

The files are generated from `theme.json.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

Gemini CLI loads a theme from a JSON file named by `ui.theme` in its
`settings.json`, and only from inside your home folder.

The easiest way is `./setup.sh` from the repository root: choose Gemini CLI.
It links the theme into `~/.gemini/themes`, and offers to set `ui.theme` in
`~/.gemini/settings.json`, keeping your other settings. To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the theme into `~/.gemini/themes`. A symlink means later
   changes to the palette show up the next time Gemini CLI starts. (If this
   repository is outside your home folder, copy it: Gemini CLI won't load a
   theme from outside your home folder.) Run these from the same folder
   where you ran `git clone`.

   ```bash
   mkdir -p ~/.gemini/themes

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/gemini-theme/jenerated-blue-purple.json" ~/.gemini/themes/

   # Or copy
   cp ./jenerated-themes/app-themes/gemini-theme/jenerated-blue-purple.json ~/.gemini/themes/
   ```

3. Point `ui.theme` in `~/.gemini/settings.json` at it, with the full path:

   ```json
   {
     "ui": {
       "theme": "/home/you/.gemini/themes/jenerated-blue-purple.json"
     }
   }
   ```

4. Start Gemini CLI.

While `ui.theme` is set, Gemini CLI's `/theme` command can't switch themes;
remove the setting to choose with `/theme` again.
