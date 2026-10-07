"""rizin (reverse engineering)."""

from . import App
from .radare2 import install_r2_theme


def install(theme):
    install_r2_theme(theme, "rizin")


APP = App(
    id="rizin",
    label="rizin (reverse engineering)",
    category="hacking",
    templates=(
        ("app-themes/rizin-theme/theme.rz.tmpl", "app-themes/rizin-theme/jenerated-{slug}"),
    ),
    covers="Cutter",
    words=("rz", "disassembler", "debugger", "reverse", "engineering"),
    commands=("rizin",),
    one_palette=True,
    install=install,
)
