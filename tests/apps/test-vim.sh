#!/usr/bin/env bash
# Tests for Vim / Neovim: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-vim.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

vim_scheme() { printf '%s' "$SANDBOX/repo/app-themes/vim-theme/colors/jenerated-$1.vim"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating it
# THEN the Vim colorscheme is named after the slug and uses Sunset's colors,
#      including followed references in the terminal colors
test_vim_scheme_uses_the_palette() {
  generate sunset
  scheme="$(vim_scheme sunset)"
  assert_file_contains "$scheme" "let g:colors_name = 'jenerated-sunset'"
  assert_file_contains "$scheme" "guibg=$(color bg)"
  assert_file_contains "$scheme" "'$(color term_red)'"
}

# GIVEN the Sunset palette
# WHEN generating it and loading the colorscheme in the real Vim
# THEN it loads without errors, with the palette's background
test_vim_scheme_loads_in_vim() {
  command -v vim >/dev/null 2>&1 || return 0
  generate sunset
  bg="$(color bg | tr 'A-F' 'a-f')"
  vim -Nu NONE -i NONE -es --cmd "set rtp^=$SANDBOX/repo/app-themes/vim-theme" -c "set termguicolors" \
    -c "try | colorscheme jenerated-sunset | call writefile([g:colors_name . ' ' . tolower(synIDattr(hlID('Normal'), 'bg#')) . ' [' . v:errmsg . ']'], '$SANDBOX/vim-result') | catch | call writefile([v:exception], '$SANDBOX/vim-result') | endtry" \
    -c 'qa!' </dev/null >/dev/null 2>&1
  assert_file_equals "$SANDBOX/vim-result" "jenerated-sunset $bg []"
}

# GIVEN Sunset has been generated
# WHEN removing Sunset
# THEN its Vim colorscheme is deleted, and the colors folder and Blue
#      Purple's colorscheme are kept
test_remove_deletes_the_vim_scheme() {
  generate sunset
  remove sunset
  assert_contains "Removed app-themes/vim-theme/colors/jenerated-sunset.vim"
  assert_missing "$(vim_scheme sunset)"
  assert_exists "$(vim_scheme blue-purple)"
}

# --- Tests: installing -------------------------------------------------------

VIM_PACK=".vim/pack/jenerated/start/jenerated-themes"
NVIM_PACK=".local/share/nvim/site/pack/jenerated/start/jenerated-themes"

# vim_loads scheme -> fails unless the real Vim, with the sandbox's home,
# finds and loads the colorscheme. Skipped when Vim isn't installed.
vim_loads() {
  command -v vim >/dev/null 2>&1 || return 0
  rm -f "$SANDBOX/vim-result"
  HOME="$SANDBOX/home" vim -Nu NONE -i NONE -es \
    -c "try | colorscheme $1 | call writefile([g:colors_name], '$SANDBOX/vim-result') | catch | call writefile([v:exception], '$SANDBOX/vim-result') | endtry" \
    -c 'qa!' </dev/null >/dev/null 2>&1
  assert_file_equals "$SANDBOX/vim-result" "$1"
}

# GIVEN no Neovim config
# WHEN choosing Vim and Blue Purple
# THEN app-themes/vim-theme is linked as a Vim package, Vim can load the colorscheme,
#      and it says what to add to ~/.vimrc
test_vim_links_the_package() {
  install_app vim blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$VIM_PACK" "$SANDBOX/repo/app-themes/vim-theme"
  assert_contains "colorscheme jenerated-blue-purple"
  assert_contains "~/.vimrc"
  vim_loads jenerated-blue-purple
}

# GIVEN a Neovim config folder
# WHEN choosing Vim and Blue Purple
# THEN app-themes/vim-theme is also linked as a Neovim package, and it says what to add
#      to init.lua
test_vim_links_the_package_for_neovim() {
  mkdir -p "$SANDBOX/home/.config/nvim"
  install_app vim blue-purple "y\n1\n"
  assert_status 0
  assert_link "$SANDBOX/home/$NVIM_PACK" "$SANDBOX/repo/app-themes/vim-theme"
  assert_contains 'vim.cmd.colorscheme("jenerated-blue-purple")'
}

# GIVEN Vim was set up with Blue Purple
# WHEN choosing Vim and Sunset
# THEN the link is already there, and Sunset's newly generated colorscheme
#      loads through it too
test_vim_one_link_serves_every_palette() {
  install_app vim blue-purple "y\n1\n"
  install_app vim sunset "y\n1\n"
  assert_status 0
  assert_contains "Already installed"
  assert_exists "$SANDBOX/repo/app-themes/vim-theme/colors/jenerated-sunset.vim"
  vim_loads jenerated-sunset
}

# GIVEN an old copy of the colorschemes where the Vim package goes
# WHEN choosing Vim and answering no to replacing it
# THEN it exits with status 1 and the copy is untouched
test_vim_asks_before_replacing_a_copy() {
  mkdir -p "$SANDBOX/home/$VIM_PACK/colors"
  touch "$SANDBOX/home/$VIM_PACK/colors/keep-me.vim"
  install_app vim blue-purple "y\n1\nn\n"
  assert_status 1
  assert_exists "$SANDBOX/home/$VIM_PACK/colors/keep-me.vim"
}

run_tests
