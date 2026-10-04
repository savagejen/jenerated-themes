#!/usr/bin/env bash
# Runs every test file (tests/<script>/test_*.sh), then sums up: how many
# tests passed and failed in all, and which files had failures.
#
# Usage: tests/run.sh

set -u

cd "$(dirname "$0")"

status=0
passed=0
failed=0
failed_files=()
log="$(mktemp "${TMPDIR:-/tmp}/jenerated-run.XXXXXX")"
trap 'rm -f "$log"' EXIT

for file in */test_*.sh; do
  [ -f "$file" ] || continue
  printf '\n### %s\n\n' "$file"
  # Shown as it runs, and kept to read the file's "N passed, M failed" line.
  bash "$file" 2>&1 | tee "$log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
  counts="$(sed -n 's/^\([0-9][0-9]*\) passed, \([0-9][0-9]*\) failed$/\1 \2/p' "$log" | tail -n 1)"
  if [ -z "$counts" ]; then
    # It stopped before reporting, so count it as failed.
    status=1
    failed_files+=("$file (stopped before reporting its results)")
    continue
  fi
  passed=$((passed + ${counts% *}))
  failed=$((failed + ${counts#* }))
  [ "${counts#* }" -eq 0 ] || failed_files+=("$file (${counts#* } failed)")
done

printf '\n### All tests\n\n%d passed, %d failed\n' "$passed" "$failed"
if [ "${#failed_files[@]}" -gt 0 ]; then
  printf '\nFailures in:\n'
  printf '  %s\n' "${failed_files[@]}"
fi

exit "$status"
