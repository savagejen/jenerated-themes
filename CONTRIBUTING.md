# Contributing to Jenerated Themes

Thanks for helping out! This covers how the project fits together, how to add
a palette or an app, and what to run before committing. For installing and
using the themes, see the [README](README.md).

## Setting up

1. Clone the repository:

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   cd jenerated-themes
   ```

2. Turn on the git hook, once per clone (git doesn't copy this setting when
   you clone):

   ```bash
   git config core.hooksPath .githooks
   ```

   It's a pre-commit hook that refuses a commit while a palette in
   `palettes/` uses a color from
   [palettes/avoid-these.txt](palettes/avoid-these.txt) (see
   [Colors to avoid](#colors-to-avoid)), or while a file being committed
   has a symbol outside plain ASCII in its name or, for a text file, its
   contents (see [Symbols stay ASCII](#symbols-stay-ascii)), or while a file
   being added has an underscore in its name (see
   [File names](#file-names)). It checks what's
   staged, the version the commit will hold. The tests check the same
   things, so nothing slips through on a clone without it.

What you need:

- **Python 3.11 or later**, for `jenerate.py`, the Palette Creator and most
  of the tests. Nothing to install beyond Python itself.
- **`curl`**, for the Palette Creator tests.
- **pip and venv** (usually part of Python; on Debian and Ubuntu, the
  `python3-pip` and `python3-venv` packages) and a network connection, for
  the package tests.
- **Node.js and npm**, only for [updating screenshots](#screenshots).

## How it works

- **Palettes** in [palettes/Dark](palettes/Dark/) and
  [palettes/Light](palettes/Light/) are TOML files with a `name`, a
  `short_name` (lowercase words and dashes, used in file names), an
  optional `scheme` (`"dark"` or `"light"`), and a list of colors
  named by role (`bg`, `text`, `accent`, `red`, `term_bright_cyan`, ...). A
  color is a `#rrggbb` value or the name of another color in the same file.
- **Templates** (the `.tmpl` files in each app's folder, under
  [app-themes/](app-themes/)) are the app's theme file with `{{color_name}}`
  placeholders where the colors go.
- **[jenerate.py](jenerate.py)** fills in every template for each palette
  you name and writes the results next to the templates, named after the
  palette's short name. For VS Code it also rebuilds
  `app-themes/vs-code-theme/package.json` from `package.json.tmpl`, listing
  every generated theme. Its code is in the
  [jenerate_themes](jenerate_themes/) package: palettes in `palettes.py`,
  color forms and contrast in `colors.py`, templates in `render.py`, and
  each app's `(template, output)` pairs in its `templates`, gathered into
  `TARGETS` in `targets.py`.
- **[jenerate](jenerate)** is the app: run with no command, it walks people
  through installing a theme (pick an app, pick a palette); `./jenerate
  --help` lists its commands. Its code is in `jenerate_themes` too: the
  menus in `menus.py`, the command line in `cli.py`, and each app in its own
  module in [jenerate_themes/apps](jenerate_themes/apps/).
- **[setup.sh](setup.sh)** is what the README tells people to run. With
  Python 3.11 or later it hands over to `jenerate`; without it, the rest of
  `setup.sh` can still install Blue Purple, in bash, into the apps where
  that only means linking files into place or showing a theme to paste in.

### A clone and an installed copy

`jenerate` runs from a clone like yours, or from an installed copy (pipx,
or a `.deb`, `.rpm` or Arch package). [paths.py](jenerate_themes/paths.py)
decides which, and where files go:

- `paths.SOURCE` is where templates, bundled palettes and Blue Purple's
  pre-made themes are read from: the repository in a clone, the package's
  read-only `data/` folder when installed.
- `paths.DATA` is where generated themes, people's own palettes and the
  Palette Creator's draft are written: the repository in a clone,
  `~/.local/share/jenerate-themes` (or `$XDG_DATA_HOME/jenerate-themes`)
  on Linux and `~/Library/Application Support/jenerate-themes` on macOS
  when installed, laid out like the repository.

In a clone the two are the same folder, so everything works as described
here. An installed copy comes with Blue Purple's themes already made: they
are copied into the data folder when first needed, and refreshed after an
upgrade. A palette of someone's own replaces a bundled one with its short
name.
The package is built from [pyproject.toml](pyproject.toml), which puts
`app-themes/` and `palettes/` whole into the package's `data/` folder, so
new templates and palettes are packaged with nothing more to do. Files git
ignores (like palettes you generated) are left out, and so are the apps'
READMEs and the palette screenshots. The package's version is
`__version__` in `jenerate_themes/__init__.py`. To try it as someone who
installed it would, without touching your other installs:

```bash
python3 -m venv /tmp/jenerate-try
/tmp/jenerate-try/bin/pip install .
/tmp/jenerate-try/bin/jenerate list
```

An installed copy writes to your real data folder
(`~/.local/share/jenerate-themes`), so remove that afterward if you don't
want to keep what you made.

To build the packages themselves (the source package and the wheel, in
`dist/`), put the build tool in a virtual environment of its own, since
many systems don't let pip install into their Python:

```bash
python3 -m venv /tmp/jenerate-build
/tmp/jenerate-build/bin/pip install build
/tmp/jenerate-build/bin/python -m build
```

### Template placeholders

- `{{accent}}` gives the color as `#rrggbb`. A template can add transparency
  after it, for example `{{accent}}33`.
- For apps that need them, each color is also available as numbers:
  `{{accent_rgb}}` gives `88, 101, 243`, `{{accent_rgb_csv}}` gives
  `88,101,243`, `{{accent_rgb_spaced}}` gives `88 101 243`,
  `{{accent_rgb16}}` gives `22616,25957,62451` (each channel from 0 to 65535,
  as Wireshark stores colors),
  `{{accent_float}}` gives `0.3451, 0.3961, 0.9529` (each channel from 0 to
  1; `{{accent_float_spaced}}` gives the same with spaces instead of
  commas), `{{accent_linear_r}}`, `{{accent_linear_g}}` and
  `{{accent_linear_b}}` give each channel in linear light (for apps that
  store colors that way, like Unreal Engine), `{{accent_h}}`, `{{accent_s}}`
  and `{{accent_l}}` give `235`, `87` and `65`, `{{accent_hex}}` gives
  `5865F3` (without the `#`), and `{{accent_int}}` gives `5793267` (the
  color as one decimal number, as LibreOffice stores colors).
- `{{green_over_bg_20}}` is one color laid over another at a percentage
  (0 to 100), as `#rrggbb`: how `{{green}}33` would look over `{{bg}}`. Use
  it for apps that don't take colors with transparency, like tinted diff
  backgrounds in Gemini CLI.
- `{{name}}` and `{{short_name}}` are the palette's name and short name.
- `{{uuid}}` is an ID made from the palette's short name, the same every time,
  for apps that identify themes by UUID.
- `{{scheme}}` is `dark` or `light`, and
  `{{scheme: "text for dark" | "text for light"}}` picks one of two texts. A
  template whose dark and light versions differ too much for that can have
  `{scheme}` in its path in its app's `templates`, like JetBrains'
  `theme-{scheme}.json.tmpl`.

`jenerate.py` works out whether a palette is dark or light from its editor
background (`bg`), unless the palette sets `scheme`.

### The text colors

Most roles explain themselves. Two are easy to mix up, and matter most for
light palettes:

- `text_bright` is text **on the accent color**: buttons, badges, selected
  menu items.
- `text_strong` is emphasized text **on ordinary backgrounds**: the active
  tab, the selected file, bold terminal text.

On a dark palette both are usually white. On a light palette `text_bright`
stays light, for the accent, and `text_strong` is dark. When a template
needs one of them, pick by what the text sits on.

### Generated files and Blue Purple

Generated files are ignored by git (see [.gitignore](.gitignore)), so each
person's copy holds only the palettes they chose. The exception is Blue
Purple, the default: its generated files are committed, along with a
`package.json` that lists only it, so the themes work without running
anything. The Vivaldi `.zip`, JetBrains `.jar` and LibreOffice `.oxt` of
Blue Purple are committed too, ready to install.

Generating other palettes changes `package.json` in your copy. Don't commit
that; [prepare for the commit](#before-you-commit) instead, which puts it
back.

Don't edit generated files by hand; change the palette or template and run
`jenerate.py` again.

## Adding a palette

Design it in the [Palette Creator](palette-creator/) (`./jenerate design`), or
copy an existing palette to `palettes/Dark/<short-name>-palette.toml` or
`palettes/Light/<short-name>-palette.toml` and edit it. (A palette saved
straight in `palettes/`, or in the wrong one of the two, still works, and
[updating the screenshots](#screenshots) files it.) Every color the templates
use must be defined; `jenerate.py` names any that are missing, and checks the
palette's other rules (see [Adding a palette](README.md#adding-a-palette) in
the README).

Then:

1. Generate it and try it in a few apps: `./jenerate.py <short-name>`.
2. Write a description as the comment at the top of the file: what the
   palette is and where its colors come from. It becomes the palette's
   section in [palettes/README.md](palettes/README.md).
3. Check its text contrast with `./jenerate.py --contrast <short-name>`: a
   recommendation, not a rule (see [Text contrast](#text-contrast)).
4. [Update the screenshots](#screenshots), which adds the palette's
   screenshot and README section.

### Text contrast

We recommend, but don't require, a contrast ratio of at least 4.5:1 (WCAG's
level for ordinary text) for the colors people read:

- `text`, `text_subtle` and `text_muted` (comments), and the syntax and
  accent colors (`accent`, `accent_soft`, `accent_light`, `accent_pale`,
  `red`, `orange`, `yellow`, `green`, `cyan`, `magenta`), against both `bg`
  and `bg_line_highlight`, since the line the cursor is on is read too.
- `text_bright` against `accent`, for button and badge labels.
- `text_strong` against `bg` and `bg_selected`. This is the one pair the
  tests do check, since a palette that fails it makes selected items hard
  to read in many apps.

Colors meant to recede, like `text_faint` (line numbers), `guide`,
`whitespace`, `border` and the bright terminal colors, aren't included.
Several published palettes fall short in places; that's allowed, but it's
worth a look when you design or change one.

To see how a palette does:

```bash
./jenerate.py --contrast sunset      # one palette, or several with commas
./jenerate.py --contrast             # every palette
```

It lists each pair below 4.5:1, with its ratio, and never fails. The Palette
Creator shows the same list when you click "Save as palette", before the save
dialog opens: OK saves anyway, and Cancel goes back to editing.

### Colors to avoid

The palettes published here leave out the exact colors listed in
[palettes/avoid-these.txt](palettes/avoid-these.txt): colors too iconic to
publish. It's a style choice. A nearby shade is fine (one digit off is
enough), and anyone is welcome to use these colors in their own palettes.

The list is one `#rrggbb` per line, with `# ` comments. The pre-commit hook
and the tests in `tests/hooks/` read it, so adding a color there is all it
takes.

## Adding an app

1. Create a folder in `app-themes/`, such as `app-themes/example-theme/`,
   with a template (`<something>.tmpl`) that uses the palette's color names.
   Start the template with a comment saying it's generated and not to edit
   it, where the format allows comments.
2. Add a module for the app in `jenerate_themes/apps/`, like `tilix.py`, with
   an `install(theme)` function and an `APP` describing it (the fields are
   explained in `App`, in `jenerate_themes/apps/__init__.py`). Then, in that
   `__init__.py`, import the module and add its `APP` to `ALL_APPS`: only the
   modules imported there run, so code can't run just by being added to the
   folder (a test checks the imports against the folder). List the app's `(template, output)` pairs in its
   `templates`. Use `{slug}` (the code's name for the short name) in the
   output path so each palette gets its own file. An app that needs several
   files per theme can use `{slug}` as a folder, like Obsidian's
   `app-themes/obsidian-theme/{slug}/theme.css`.
3. Add the output pattern to `.gitignore`, with a `!` line keeping Blue
   Purple's files, like the other apps.
4. Write a README for the app: what it themes, which palette colors go
   where, and how to install it (with `./setup.sh`, and by hand).
5. Fill in the rest of the app's `APP`, and add the app to the list in the
   main [README](README.md), under its category's heading (and marked
   (Linux) or (macOS) if it only runs on one).

   If the theme can't be installed for the user (you install it in the
   app yourself, like most browsers and Slack), set `manual=True`, so
   ALL THE APPS leaves it out. If the app uses one palette at a time
   (installing one switches the app to it, like tmux), set
   `one_palette=True`, so ALL THE PALETTES isn't offered for it. Set
   `commands`, `flatpaks` and `mac_apps` (or `libraries`, or a `present`
   check), so ALL THE APPS only installs into the app when it's there (the
   tests set `SETUP_FOUND_APPS` to decide which apps count as found). An
   app that only runs on one system gets `system="Linux"` or
   `system="Darwin"`, and is only offered there.
   In either ALL option, `ask_yes` answers yes and `choose` picks the first
   choice, so keep the first choice the safe, usual one, and don't make the
   install wait for anything else (check `state.current.auto` and stop with
   `stop()` instead, saying how to finish, like Obsidian's vault path).

   Find the theme's files with `paths.app_themes(...)`, as every app does,
   so installs link to the right copy. Code that needs other paths reads
   from `paths.SOURCE` and writes only under `paths.DATA` (see
   [A clone and an installed copy](#a-clone-and-an-installed-copy)).
   `tests/apps/test-every-app.sh` runs every app in an installed copy too,
   and fails if one writes into the package or links to it.

   The app menu groups apps into categories (`CATEGORIES`, in
   `jenerate_themes/apps/__init__.py`), so it stays short however many apps
   there are. Categories are named for what you do in the apps (browsing,
   editing, hacking and testing, art and design), and an app goes where its
   theme shows up: a tool with a command line and a desktop app files its
   theme by which of the two it colors, and one that can theme both gets an
   entry in each. Within a category, apps are listed alphabetically by
   their `label`.
   An app that doesn't fit a category can use `category=""`, which puts it
   on the main app menu. Apps can also be found by typing part of their
   name, which searches names, ids, category names, and the two optional
   lists:

   - **covers:** the apps a theme covers that don't fit in its menu name,
     written as their names and as its README lists them. Searching
     RustRover finds the JetBrains theme, and search results show this list
     under the theme's name.
   - **words:** other words someone might search for, such as "chat" for
     Slack. They aren't shown.
6. Add tests: copy the test file of an app like yours in `tests/apps/` to
   `tests/apps/test-<your app's id>.sh`, and change the paths and expected
   text. Test the generated files (that they use the palette's colors and
   are valid for the app's format) and the install (where the files go, and
   what it says). `tests/apps/test-every-app.sh` already tests every app's
   basics, new ones included: that its theme is made with nothing left
   unfilled, and that installing it works or stops with a reason.
7. [Prepare for the commit](#before-you-commit), which generates Blue
   Purple's files for the new app.

If the app installs a packaged file (like Vivaldi's `.zip`), add Blue
Purple's package to `EXAMPLE_PACKAGES` in
[maintainer-tools/prep-commit.py](maintainer-tools/prep-commit.py), so it's
rebuilt with the other defaults.

If installing Blue Purple into the app only takes linking its files into
place (or showing a theme to paste in), add it to the part of `setup.sh`
that runs without Python too: an `add_fallback_app` line in menu order, an
`install_<app>` function, and a line in the `case` in `install_app`.

## Changing a template or Blue Purple

After changing any template, or the Blue Purple palette,
[prepare for the commit](#before-you-commit), and commit the regenerated
Blue Purple files along with your change, so the default stays in sync. The
tests check that they match.

## Before you commit

1. Put the committed defaults back:

   ```bash
   ./setup.sh --prep-commit
   ```

   It regenerates Blue Purple's files (restoring any you removed, and
   updating them for any template change), rebuilds `package.json` listing
   only Blue Purple, and rebuilds the Blue Purple packages. Your other
   generated themes stay on disk, since git ignores them; it prints the
   command to list them in VS Code again afterward. (It runs
   [maintainer-tools/prep-commit.py](maintainer-tools/prep-commit.py).)

2. Run the tests:

   ```bash
   tests/run.sh
   ```

3. Commit. The pre-commit hook checks the palettes against the colors to
   avoid, what you're committing for symbols outside plain ASCII, and new
   files' names for underscores.

## Releasing

Releases are published by
[.github/workflows/release.yml](.github/workflows/release.yml) when a version
tag is pushed. It checks the tag matches `__version__` and the CHANGELOG has
the version's release date, tests and builds the packages, publishes them to
PyPI (where `pipx install jenerate-themes` gets them), and makes a GitHub
release with them and the version's CHANGELOG section. On every pull
request, it builds and tests the packages without publishing anything.
Dependabot keeps the actions it uses up to date, and its pull requests merge
themselves once that build passes. Each action is pinned to an exact commit,
with its version in a comment (`@<commit>  # v7.0.1`), since a version tag
can be moved to different code; pin any action you add the same way.

For each release:

1. Set the new version in `__version__` in `jenerate_themes/__init__.py`
   (see the CHANGELOG for which number goes up), and give its CHANGELOG
   section the release date: `## [1.0.0] - 2026-10-12`.
2. Optionally, try it first: in the repository's Actions tab, choose Release,
   then "Run workflow". That publishes to TestPyPI instead, and you can try
   the result with
   `pipx install --index-url https://test.pypi.org/simple/ jenerate-themes`.
3. Merge into `main`, then tag that commit and push the tag:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

A version can only be published to PyPI once, so a mistake found afterward
is fixed in the next version.

## Screenshots

Each palette has a screenshot in `palettes/Screenshots/Dark` or
`palettes/Screenshots/Light` and a section in the dark or light group of
[palettes/README.md](palettes/README.md). To retake them all:

```bash
./setup.sh --update-screenshots
```

To retake just some, name them by short name, with commas between several:

```bash
./setup.sh --update-screenshots=candy
./setup.sh --update-screenshots=candy,sunset
```

First it files every palette: `jenerate.py` works out whether each is dark
or light (its `scheme`, or else its `bg`), and a palette or screenshot in the
wrong folder, or straight in `palettes/`, is moved to the right one. A short
name found in two places stops it, naming both, until you keep one.

Then it shows each palette in the Palette Creator's preview (running on a
throwaway copy of the repository, so your draft is never touched), saves a
screenshot of it with [Playwright](https://playwright.dev), and updates
`palettes/README.md`: a new palette gets a section in the dark or light
group, made from its description and key colors, existing sections get their
key colors refreshed, and a section moves groups if its palette changed
scheme. The groups are `<details open>` blocks, so readers can collapse the
one they don't want. Text you've written in the README is left alone.

To file the palettes and update the README without taking screenshots:

```bash
./maintainer-tools/update-screenshots.py --readme-only
```

The first run installs Playwright and its browser into
`~/.cache/jenerated-themes/playwright`, outside the repository, which needs a
network connection. See
[maintainer-tools/update-screenshots.py](maintainer-tools/update-screenshots.py)
for the details.

## Symbols stay ASCII

Letters in any language are welcome anywhere: a palette named "Smørrebrød"
or "Ночь", or a description in Japanese. Everything else outside plain ASCII
isn't: typographic dashes, ellipses, arrows, middle dots, curly quotes,
emoji, invisible characters like non-breaking and zero-width spaces, and
control characters other than tab.
That goes for code, comments, docs, palettes and the Palette Creator.

Write plain text instead: `...`, `-`, `->`, straight quotes, a word instead
of an icon (`1 error`, not a symbol before the `1`). Don't bring a symbol
back in disguise, as an HTML entity (like `&middot;`) or an escape code
(like `\u2022`): the page would still show the symbol. The pre-commit hook
refuses a commit that adds anything else, naming each file and line, and a
test in `tests/repo/` checks the whole repository. File names follow the
same rule. Both run `.githooks/check-symbols.py`, so they can't drift apart.

## File names

File and folder names separate words with dashes: `prep-commit.py`,
`test-every-app.sh`, `blue-purple-palette.toml`, `app-themes/`. The one
exception is the Python package, `jenerate_themes/`, and the files in it:
Python loads a module by its name, and a name with a dash can't be loaded,
so they use underscores. Names inside the code (functions, variables, test
names like `test_quassel_links_the_stylesheet`) use underscores too, since
neither shell nor Python allows dashes there.

The pre-commit hook refuses a commit that adds a file with an underscore in
its name or its folders' names, outside `jenerate_themes/`, and a test in
`tests/repo/` checks the whole repository.

## Running the tests

```bash
tests/run.sh
```

It shows each test file's results as it goes, then the totals for all of
them, and lists every failed test by file, each with the first reason it
gave. To run one file's tests, run the file;
to run only some of them, add part of their names:

```bash
tests/apps/test-quassel.sh
tests/apps/test-quassel.sh flatpak
```

Tests live in [tests/](tests/):

| Folder | Tests |
|--------|-------|
| `tests/apps/` | each app, one file per app: making its theme, and installing it; plus `test-every-app.sh`, the basics for every app, in a clone and in an installed copy |
| `tests/package/` | the packages `pyproject.toml` builds (the source package and the wheel): what's in them, and that the wheel installs and runs as `jenerate` |
| `tests/installed/` | an installed copy: its data folder, bundled and own palettes, the pre-made Blue Purple, and a clone and an installed copy on one computer |
| `tests/menus/` | the menus: choosing an app and a palette, searching, ALL THE APPS and ALL THE PALETTES |
| `tests/generate/` | making themes for every app at once: palettes and their mistakes, colors, contrast, light and dark, listing and removing (through `jenerate.py`) |
| `tests/setup/` | `setup.sh` itself: handing over to `jenerate`, Blue Purple without Python, and its options |
| `tests/maintainer-tools/` | the scripts in `maintainer-tools/`: prep-commit, and updating the screenshots and `palettes/README.md` |
| `tests/cli/` | the `jenerate` command's subcommands |
| `tests/palette-creator/` | the Palette Creator (`jenerate_themes/creator/serve.py`) |
| `tests/hooks/` | the git hooks in `.githooks/` |
| `tests/repo/` | the repository as a whole, such as symbols staying plain ASCII |

Each test runs against a temporary copy of the repository, so the tests
don't touch your generated or installed themes. Tests that need Python 3.11,
`curl`, or pip, venv and a network connection are skipped without them.
Shared helpers are in `tests/lib.sh`,
and the app tests' own (`install_app`, `generate`) in `tests/apps/apps.sh`.

Tests are shell functions named `test_...`, each with a comment above it in
the form:

```bash
# GIVEN the Sunset palette
# WHEN generating it
# THEN no generated file has a {{ placeholder left in it
test_fills_in_every_placeholder() {
```

## License

The project is under the [MIT License](LICENSE). By contributing, you agree
that your contribution is licensed under it too.
