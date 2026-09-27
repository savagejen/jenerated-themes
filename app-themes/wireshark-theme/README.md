# Jenerated Themes for Wireshark

Coloring rules for [Wireshark](https://www.wireshark.org/), the network
protocol analyzer. [jenerate.py](../../jenerate.py) writes a `colorfilters`
file for each palette you generate, in `<slug>/colorfilters`, for example
`blue-purple/colorfilters`.

They're Wireshark's own default coloring rules, with the same filters in the
same order, in the palette's colors:

- **Problems** (bad TCP, checksum errors) stand out on the palette's red,
  and **state changes** (HSRP, spanning tree, OSPF) and **ICMP errors** on
  its yellow and orange, with the editor background as their text.
- **Other protocols** get the palette's colors as text: TCP in its function
  blue, UDP in its cyan, HTTP in its string green, ARP in yellow, ICMP in
  magenta, resets and aborts in red, and so on.
- **Every other packet** gets the palette's background and text, from one
  last rule that matches everything, so the whole packet list follows the
  palette.

Wireshark's windows and panes follow your system's theme; only the packet
list's colors come from these rules.

The files are generated from `colorfilters.tmpl`. To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The rules go in a Wireshark configuration profile of their own, named
"Jenerated" plus the palette's name, so your own coloring rules (in the
Default profile) are left alone, and each palette is a profile you can
switch to.

The easiest way is `./setup.sh` from the repository root: choose Wireshark.
To install by hand:

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Make the profile's folder in Wireshark's settings folder, and symlink or
   copy the rules into it. A symlink means later changes to the palette show
   up when you switch to the profile again. Run these from the same folder
   where you ran `git clone`. (Help -> About Wireshark -> Folders shows your
   settings folder as "Personal configuration": usually `~/.config/wireshark`,
   or `~/.var/app/org.wireshark.Wireshark/config/wireshark` for the
   Flatpak.)

   ```bash
   mkdir -p ~/.config/wireshark/profiles/"Jenerated Blue Purple"

   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/app-themes/wireshark-theme/blue-purple/colorfilters" ~/.config/wireshark/profiles/"Jenerated Blue Purple"/colorfilters

   # Or copy
   cp ./jenerated-themes/app-themes/wireshark-theme/blue-purple/colorfilters ~/.config/wireshark/profiles/"Jenerated Blue Purple"/colorfilters
   ```

3. In Wireshark, right-click the profile name at the right end of the status
   bar ("Default" at first) and choose **Jenerated Blue Purple**, or use
   **Edit -> Configuration Profiles**.

4. Check that **View -> Colorize Packet List** is on.

The profile holds just the coloring rules, so Wireshark's other settings
start from their defaults in it. If you edit the coloring rules in
Wireshark while using a symlinked profile, Wireshark writes your changes
into this folder's file, and they're replaced the next time the palette is
generated; copy the file instead if you want to change the rules.

## Coloring rules format

Each rule is one line: `@name@display filter@[background][text]`, with each
color as three numbers from 0 to 65535 (red, green, blue). The template uses
`{{color_rgb16}}` placeholders for them. Wireshark applies the first rule a
packet matches, so the catch-all rule is last.
