# Jenerated Themes for Quassel IRC

Stylesheets for the [Quassel IRC](https://quassel-irc.org/) client.
[jenerate.py](../../jenerate.py) writes one `jenerated-<slug>.qss` file for
each palette you generate, for example `jenerated-blue-purple.qss`. Only the
client needs one: if you run Quassel as a core on a server, install the
stylesheet on the computer you chat from.

A stylesheet colors the whole Quassel window, not just the chat:

- **Window:** menus, the channel and nickname lists, the input box and
  the topic bar in the same colors as the
  [qt5ct and qt6ct theme](../qtct-theme/): windows in the sidebar color,
  views and inputs in the editor background, selections in the accent.
- **Chat:** text on the editor background, timestamps muted, links in the
  soft accent, a marker line in the accent where you left off reading, and
  lines that mention you tinted orange.
- **Messages:** notices in orange, actions (`/me`) in magenta, errors in
  red, messages from the server in the soft accent, and joins, parts, quits
  and other comings and goings muted.
- **Nicknames:** your own in the strong text color, and everyone else's in
  16 colors from the palette: its syntax colors, bright terminal colors and
  accents. They show while Use Sender Coloring is on, under Settings ->
  Configure Quassel... -> Interface -> Chat View Colors (it's on to begin
  with).
- **Colors in messages:** the 16 IRC colors people type into messages come
  from the palette's terminal colors, the way terminal IRC clients show
  them. As in a terminal, text someone colors black is hard to read on a
  dark palette, and text colored white on a light one.
- **Channel list:** channels you've left muted, new activity in cyan, unread
  messages in the light accent, and mentions in orange.

The files are generated from `stylesheet.qss.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Quassel
IRC. It links the stylesheet into a `stylesheets` folder in Quassel's
settings folder. If you have the Flatpak, it also copies the stylesheet into
the Flatpak's settings folder, since the Flatpak can't see files outside its
own folders; run `./setup.sh` again after changing the palette to update
that copy.

To install by hand, link it there yourself, so later changes to the palette
show up after you restart Quassel. Quassel's settings folder is
`~/.config/quassel-irc.org` on Linux,
`~/Library/Application Support/Quassel` on macOS, and
`~/.var/app/org.quassel_irc.QuasselClient/config/quassel-irc.org` for the
Flatpak. Run this from the folder where you ran `git clone`:

```bash
mkdir -p ~/.config/quassel-irc.org/stylesheets
ln -s "$PWD/jenerated-themes/app-themes/quassel-theme/jenerated-blue-purple.qss" ~/.config/quassel-irc.org/stylesheets/
```

The Flatpak can't see files outside its own folders, so for the Flatpak,
copy the stylesheet with `cp` instead of linking it, and copy it again after
changing the palette.

Then turn it on:

1. In Quassel, open **Settings -> Configure Quassel... -> Interface**.
2. Check **Use custom stylesheet**, and choose the file, for example
   `~/.config/quassel-irc.org/stylesheets/jenerated-blue-purple.qss`.
3. Click **OK**. The colors change right away.

To go back to Quassel's own colors, uncheck **Use custom stylesheet**.

## Stylesheet format

A Quassel stylesheet is a Qt stylesheet with some blocks of Quassel's own:

- `Palette { ... }` sets Qt's palette for the whole window (`window`,
  `base`, `text`, `highlight` and the rest), and Quassel's own colors: the
  `marker-line` and the nickname colors, `sender-color-self` and
  `sender-color-00` to `sender-color-0f`. `Palette:disabled { ... }` sets the
  colors of things you can't use right now.
- `ChatLine` blocks color the chat. `ChatLine#notice` and the like pick a
  message type, `ChatLine::timestamp` and `ChatLine::url` a part of each
  line, `ChatLine[label="highlight"]` the lines that mention you, and
  `ChatLine[fg-color="04"]` and `ChatLine[bg-color="04"]` an IRC color.
- `ChatListItem` and `NickListItem` blocks color the channel and nickname
  lists, by `state` and `type`.

Anything else, like `ChatView { background: ... }`, goes to Qt as an
ordinary stylesheet. Quassel loads the colors from its own settings first
and the custom stylesheet after, so the stylesheet's colors win. Comments
start with `//`.
