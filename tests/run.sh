#!/usr/bin/env bash
# Runs every test file (tests/<folder>/test-*.sh), then sums up: how many
# tests passed and failed in all, and each failed test, by file, with the
# first reason it gave.
#
# Usage: tests/run.sh

set -u

cd "$(dirname "$0")"

status=0
passed=0
failed=0
# Each failed file, then its failed tests, each with its first reason.
failures=()
log="$(mktemp "${TMPDIR:-/tmp}/jenerated-run.XXXXXX")"
trap 'rm -f "$log"' EXIT

for file in */test-*.sh; do
  [ -f "$file" ] || continue
  printf '\n### %s\n\n' "$file"
  # Shown as it runs, and kept to read the file's "N passed, M failed" line.
  bash "$file" 2>&1 | tee "$log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
  counts="$(sed -n 's/^\([0-9][0-9]*\) passed, \([0-9][0-9]*\) failed$/\1 \2/p' "$log" | tail -n 1)"
  if [ -z "$counts" ]; then
    # It stopped before reporting, so count it as failed.
    status=1
    failures+=("$file (stopped before reporting its results)")
    continue
  fi
  passed=$((passed + ${counts% *}))
  failed=$((failed + ${counts#* }))
  [ "${counts#* }" -eq 0 ] && continue
  failures+=("$file (${counts#* } failed)")
  # Each "FAIL  test_name" line, with the first "    FAIL: reason" line
  # since the test before it.
  while IFS= read -r line; do
    failures+=("$line")
  done < <(awk '
    /^ok    / { reason = "" }
    /^    FAIL: / && reason == "" { reason = substr($0, 11) }
    /^FAIL  / {
      print "  " substr($0, 7)
      if (reason != "") print "    " reason
      reason = ""
    }' "$log")
done

printf '\n### All tests\n\n%d passed, %d failed\n' "$passed" "$failed"
if [ "${#failures[@]}" -gt 0 ]; then
  printf '\nFailures:\n'
  printf '  %s\n' "${failures[@]}"
  printf '\nTo run one again: tests/<file> <test name>\n'
fi

exit "$status"
