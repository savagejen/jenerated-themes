# Changelog

The changes in each version of Jenerated Themes. Versions follow
[semantic versioning](https://semver.org/): the first number goes up for
changes that break how you use it, the second for new things (apps, palettes,
commands), and the third for fixes. `./setup.sh --version` shows which version
you have.

The themes themselves (like the VS Code extension or the JetBrains plugin)
keep their own version numbers, separate from these.

## [1.0.0] - Unreleased

The first numbered version.

### What's in it

- **Themes for 45 apps**, from VS Code, JetBrains IDEs, Vim and Emacs to
  terminals, desktops (GTK3, KDE Plasma, Qt), browsers, chat apps, media
  players, art apps and hacking tools. See the list in the
  [README](README.md).
- **15 palettes**, dark and light, previewed in
  [palettes/README.md](palettes/README.md).
- **`./setup.sh`**, which walks you through installing a theme: pick an app
  and a palette, and it generates the theme and installs it. **ALL THE APPS**
  installs one palette into every app it finds, and **ALL THE PALETTES**
  installs every palette into one app.
- **The Palette Creator** (`./setup.sh --design`), for designing a palette of
  your own in your browser, with a live preview.

### Changed, for anyone who used it before

- The setup experience is now a Python app, `./jenerate`, which `./setup.sh`
  hands over to. It works as before, and `./jenerate` can also be run
  directly: `./jenerate --help` lists its commands (`install`, `generate`,
  `remove`, `list`, `contrast` and `design`).
- `./setup.sh` needs Python 3.11 or later for everything but Blue Purple.
  Without Python, it now offers to install Blue Purple only, into the apps
  where that just means linking files into place.
- `./jenerate.py` works as before.
