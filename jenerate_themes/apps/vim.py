"""Vim / Neovim."""

import shutil

from .. import paths
from ..install import plan_link, run_install_plan
from ..system import HOME, folder_from_env
from ..ui import say, step
from . import App


def install(theme):
    vim_pack = HOME / ".vim/pack/jenerated/start/jenerated-themes"
    nvim_pack = folder_from_env("XDG_DATA_HOME",
                        HOME / ".local/share") / "nvim/site/pack/jenerated/start/jenerated-themes"
    has_vim = bool(shutil.which("vim")) or (HOME / ".vim").is_dir()
    has_nvim = bool(shutil.which("nvim")) or (HOME / ".config/nvim").is_dir()
    # With neither found, set it up for Vim.
    if not has_nvim:
        has_vim = True

    # app-themes/vim-theme is a Vim package: linked once, every generated
    # palette's colorscheme (in its colors/ folder) is available.
    if has_vim:
        plan_link(vim_pack, paths.app_themes("vim-theme"), shared="Vim")
    if has_nvim:
        plan_link(nvim_pack, paths.app_themes("vim-theme"), shared="Neovim")
    if has_vim and has_nvim:
        run_install_plan("the colorschemes for Vim and Neovim")
    elif has_vim:
        run_install_plan("the colorschemes for Vim")
    else:
        run_install_plan("the colorschemes for Neovim")

    step("Done! To turn the colorscheme on:")
    say(f"Try it now with :colorscheme jenerated-{theme.slug}")
    say("")
    if has_vim:
        say("To keep it, add these lines to ~/.vimrc:")
        say("    set termguicolors")
        say(f"    colorscheme jenerated-{theme.slug}")
    if has_nvim:
        say("To keep it in Neovim, add these lines to ~/.config/nvim/init.lua:")
        say("    vim.opt.termguicolors = true")
        say(f'    vim.cmd.colorscheme("jenerated-{theme.slug}")')
    say("")
    say("termguicolors gives the palette's exact colors. If your terminal doesn't")
    say("support true color, leave it out: the colorscheme then uses the terminal's")
    say("16 colors, which the Ptyxis and Tilix themes set to the same palette.")


APP = App(
    id="vim",
    label="Vim / Neovim",
    category="editors",
    templates=(
        ("app-themes/vim-theme/colorscheme.vim.tmpl",
         "app-themes/vim-theme/colors/jenerated-{slug}.vim"),
    ),
    words=("nvim",),
    commands=("vim", "nvim"),
    install=install,
)
