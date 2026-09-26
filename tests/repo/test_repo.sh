#!/usr/bin/env bash
# Tests for the repository as a whole.
#
# Usage: tests/repo/test_repo.sh
#
# Each test looks at a throwaway copy of the repository as git sees it.

source "$(dirname "$0")/../lib.sh"

# --- Tests: symbols stay ASCII -----------------------------------------------

# GIVEN every text file in the repository (tracked, or new and not ignored)
# WHEN looking for characters outside ASCII that aren't letters or accent
#      marks, the same rule as the pre-commit hook
# THEN there are none: letters in any language are fine, but symbols are
#      written as plain text ("...", "-", "->")
test_symbols_are_plain_ascii() {
  command -v perl >/dev/null 2>&1 || return 0
  OUTPUT="$(cd "$SANDBOX/repo" && find . -type f ! -path './.git/*' -print0 |
    LC_ALL=C xargs -0 grep -Il "$(printf '[\200-\377]')" 2>/dev/null |
    while IFS= read -r file; do
      perl -MEncode -ne '
        $_ = decode("UTF-8", $_, sub { "\x{FFFD}" });
        print "$ARGV:$.\n" if /[^\x00-\x7F\p{L}\p{M}]/;
      ' "$file"
    done)"
  [ -z "$OUTPUT" ] || fail "these lines have symbols outside plain ASCII:
$OUTPUT"
}

run_tests
