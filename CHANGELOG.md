# Changelog

This file documents the changes in each version of Jenerated Themes.
Versions follow [semantic versioning](https://semver.org/):

- The first number (1st.x.x) goes up for changes that break how you use it.
- The second (x.2nd.x) goes up for new things (apps, palettes, commands).
- The third (x.x.3rd) goes up for fixes.

`./setup.sh --version` shows which version of the app you have.

The themes themselves (like the VS Code extension or the JetBrains plugin)
keep their own version numbers, separate from the app version.

## [1.0.0] - Unreleased

The first numbered version.

### What's in it

- **Themes for 45 apps**, from VS Code, JetBrains IDEs, Vim and Emacs to
  terminals, desktops (GTK3, KDE Plasma, Qt), browsers, chat apps, media
  players, art apps and hacking tools. See the list in the
  [README](README.md).
- **15 palettes**, divided into dark and light, previewed in
  [palettes/README.md](palettes/README.md).
- **`./setup.sh`**, which walks you through installing a theme: pick an app
  and a palette, and it generates the theme and installs it.
- **The Palette Creator** (`./setup.sh --design`), for designing a palette of
  your own in your browser, with a live preview.
- A complete refactor from the unversioned app.

