# Jenerated Themes for PowerShell

Colors for [PowerShell](https://github.com/PowerShell/PowerShell) (`pwsh`)
on Linux and macOS. [jenerate.py](../../jenerate.py) writes one
`jenerated-<slug>.ps1` script for each palette you generate, for example
`jenerated-blue-purple.ps1`, for your PowerShell profile to load. It sets:

- **The command line as you type** (PSReadLine), colored like code in the
  editor themes: commands in the palette's function color, keywords in its
  keyword color, strings green, parameters and numbers orange, types cyan,
  variables and members in its property color, comments muted, and the
  palette's selection behind selected text. Predictions are faint, and the
  selected one in a list gets the palette's selection background.
- **PowerShell's output** (`$PSStyle`, PowerShell 7.2 and later): table
  headers and accents in the accent color, errors red, warnings yellow,
  verbose messages in the function color, debug messages muted, progress bars
  in the accent, and in file listings, folders in the function color, links
  cyan, executables green, archives orange and PowerShell scripts yellow.

The colors are exact, 24-bit ones. Each is set on its own, and skipped if
your PowerShell or PSReadLine is too old to have it, so older versions get
every color they know. The script leaves no variables behind in your session.

The scripts are generated from `colors.ps1.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose PowerShell.
It links the palette's script to `~/.config/powershell/jenerated-colors.ps1`
and offers to load it from your profile, keeping your other settings.
Switching palettes later just points the link at another palette's script.
To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the script to `~/.config/powershell/jenerated-colors.ps1`.
   A symlink means later changes to the palette show up in new PowerShell
   sessions. Run these from the same folder where you ran `git clone`.

   ```bash
   mkdir -p ~/.config/powershell

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/pwsh-theme/jenerated-blue-purple.ps1" ~/.config/powershell/jenerated-colors.ps1

   # Or copy
   cp ./jenerated-themes/app-themes/pwsh-theme/jenerated-blue-purple.ps1 ~/.config/powershell/jenerated-colors.ps1
   ```

3. Load it from your profile. In PowerShell, `$PROFILE` is its path (on Linux
   and macOS, `~/.config/powershell/Microsoft.PowerShell_profile.ps1`). Add
   this line to the end of it:

   ```powershell
   if (Test-Path "$HOME/.config/powershell/jenerated-colors.ps1") { . "$HOME/.config/powershell/jenerated-colors.ps1" }
   ```

4. Start a new PowerShell.
