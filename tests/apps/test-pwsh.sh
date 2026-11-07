#!/usr/bin/env bash
# Tests for PowerShell (pwsh): making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-pwsh.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

pwsh_colors() { printf '%s' "$SANDBOX/repo/app-themes/pwsh-theme/jenerated-$1.ps1"; }

# --- Tests: making the theme -------------------------------------------------

# GIVEN the Sunset palette
# WHEN generating its PowerShell colors
# THEN they give PSReadLine and $PSStyle Sunset's colors as 0xRRGGBB (strings
#      green, commands in its function color, errors red)
test_pwsh_colors_follow_the_palette() {
  generate sunset
  hex() { color "$1" | tr -d '#'; }
  assert_file_contains "$(pwsh_colors sunset)" "String                 = & \$jeneratedFg 0x$(hex green)"
  assert_file_contains "$(pwsh_colors sunset)" "Command                = & \$jeneratedFg 0x$(hex accent_light)"
  assert_file_contains "$(pwsh_colors sunset)" "'Formatting.Error'                  = & \$jeneratedFg 0x$(hex red)"
}

# GIVEN PowerShell (pwsh), if it's installed
# WHEN loading Sunset's PowerShell colors in it, with errors stopping it
# THEN it runs without an error, PSReadLine's string color is Sunset's green as
#      a 24-bit color code, and it leaves none of its variables behind
test_pwsh_colors_run_in_powershell() {
  command -v pwsh >/dev/null 2>&1 || return 0
  generate sunset
  rgb="$(color_rgb green | tr -d ' ' | tr ',' ';')"
  # -Command doesn't pass further arguments to the script, so the file's
  # path goes in an environment variable.
  OUTPUT="$(JENERATED_PS1="$(pwsh_colors sunset)" pwsh -NoLogo -NoProfile -Command '
$ErrorActionPreference = "Stop"
Import-Module PSReadLine
. $env:JENERATED_PS1
((Get-PSReadLineOption).StringColor -replace [char]27, "ESC")
"left: " + (@(Get-Variable jenerated* -ErrorAction SilentlyContinue).Count)
' 2>&1)"
  assert_contains "ESC[38;2;${rgb}m"
  assert_contains "left: 0"
}

# --- Tests: installing -------------------------------------------------------

# GIVEN no PowerShell profile
# WHEN choosing PowerShell and Blue Purple
# THEN the colors script is linked to ~/.config/powershell/jenerated-colors.ps1,
#      and a new profile loads it, by a path starting at $HOME
test_pwsh_links_the_colors_and_starts_a_profile() {
  fake_os Linux
  install_app pwsh blue-purple
  assert_status 0
  assert_link "$SANDBOX/home/.config/powershell/jenerated-colors.ps1" \
    "$SANDBOX/repo/app-themes/pwsh-theme/jenerated-blue-purple.ps1"
  assert_file_contains "$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    'if (Test-Path "$HOME/.config/powershell/jenerated-colors.ps1") { . "$HOME/.config/powershell/jenerated-colors.ps1" }'
}

# GIVEN a PowerShell profile with your settings, and Blue Purple installed
# WHEN choosing PowerShell and Sunset
# THEN the link points at Sunset's script, and the profile, which already
#      loads the colors, is left alone
test_pwsh_switching_palettes_repoints_the_link() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/powershell"
  printf 'Set-Alias ll Get-ChildItem\n' >"$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1"
  install_app pwsh blue-purple "y\n"
  cp "$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1" "$SANDBOX/after-first"
  install_app pwsh sunset "y\n"
  assert_status 0
  assert_link "$SANDBOX/home/.config/powershell/jenerated-colors.ps1" \
    "$SANDBOX/repo/app-themes/pwsh-theme/jenerated-sunset.ps1"
  assert_same_file "$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1" "$SANDBOX/after-first"
  assert_file_contains "$SANDBOX/after-first" "Set-Alias ll Get-ChildItem"
}

# GIVEN a PowerShell profile with your settings
# WHEN choosing PowerShell and Blue Purple, and answering no to loading it
# THEN the profile is left alone, and it says what to add
test_pwsh_leaves_the_profile_alone_when_declined() {
  fake_os Linux
  mkdir -p "$SANDBOX/home/.config/powershell"
  printf 'Set-Alias ll Get-ChildItem\n' >"$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1"
  cp "$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1" "$SANDBOX/before"
  install_app pwsh blue-purple "n\n"
  assert_status 0
  assert_same_file "$SANDBOX/home/.config/powershell/Microsoft.PowerShell_profile.ps1" "$SANDBOX/before"
  assert_contains '    if (Test-Path "$HOME/.config/powershell/jenerated-colors.ps1")'
}

run_tests
