#!/usr/bin/env bash
# Tests for Slack: making its theme from a palette, and installing it.
#
# Usage: tests/apps/test-slack.sh [part of a test's name]

source "$(dirname "$0")/apps.sh"

# --- Tests: installing -------------------------------------------------------

# GIVEN a Linux system with a clipboard tool
# WHEN choosing Slack and Blue Purple
# THEN the theme string is printed and copied to the clipboard
test_slack_prints_and_copies_the_theme_string() {
  fake_os Linux
  theme="$(tr -d '\n' <"$SANDBOX/repo/app-themes/slack-theme/blue-purple.txt")"
  install_app slack blue-purple
  assert_status 0
  assert_contains "    $theme"
  assert_contains "(Copied to your clipboard.)"
  assert_file_equals "$SANDBOX/clipboard" "$theme"
}

# GIVEN a Mac
# WHEN choosing Slack
# THEN the theme string is copied with pbcopy
test_slack_uses_pbcopy_on_macos() {
  fake_os Darwin
  fake_command pbcopy "cat > \"$SANDBOX/pbcopy-used\""
  install_app slack blue-purple
  assert_status 0
  assert_exists "$SANDBOX/pbcopy-used"
}

run_tests
