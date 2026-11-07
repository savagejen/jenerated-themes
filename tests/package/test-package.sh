#!/usr/bin/env bash
# Tests for the package pyproject.toml builds: what's in it, and that it
# installs and runs as the jenerate command. It's built once, from a copy of
# the repository as git sees it (so palettes you generated aren't in it),
# and installed once into a throwaway virtual environment, which the tests
# share. tests/installed/ tests what an installed copy does in detail.
#
# Building fetches the build tools (build and hatchling) the first time, so
# it needs a network connection; without one, these tests are skipped.
#
# Usage: tests/package/test-package.sh [part of a test's name]

source "$(dirname "$0")/../lib.sh"

PYTHON="$(find_python)"
if [ -z "$PYTHON" ] || ! "$PYTHON" -m pip --version >/dev/null 2>&1 ||
  ! "$PYTHON" -c 'import venv, ensurepip' >/dev/null 2>&1; then
  printf 'skipped: the package tests need Python 3.11 or later, with pip and venv\n'
  exit 0
fi

# --- Building and installing, once -------------------------------------------

make_sandbox
BUILD="$SANDBOX"
trap 'rm -rf "$BUILD"' EXIT
# The build tool (build) goes in a virtual environment of its own, since
# many systems don't let pip install into their Python. It builds the
# source package, then the installable package (the wheel) from it, as a
# release does.
build_log="$("$PYTHON" -m venv "$BUILD/build-venv" 2>&1 &&
  "$BUILD/build-venv/bin/pip" install --quiet --disable-pip-version-check build 2>&1 &&
  "$BUILD/build-venv/bin/python" -m build --outdir "$BUILD/dist" "$BUILD/repo" 2>&1)"
if [ $? -ne 0 ]; then
  case "$build_log" in
    *"No matching distribution found"* | *"Could not find a version that satisfies"*)
      printf 'skipped: building the package needs a network connection, to fetch its build tools\n'
      exit 0
      ;;
  esac
  printf 'FAIL  building the package:\n%s\n\n0 passed, 1 failed\n' "$build_log"
  exit 1
fi
WHEEL="$(ls "$BUILD"/dist/*.whl)"
SDIST="$(ls "$BUILD"/dist/*.tar.gz)"
"$PYTHON" -m venv "$BUILD/venv" &&
  "$BUILD/venv/bin/pip" install --quiet --disable-pip-version-check "$WHEEL" || {
  printf 'FAIL  installing the package into a virtual environment\n\n0 passed, 1 failed\n'
  exit 1
}

# wheel_files -> prints every file in the package, one per line.
wheel_files() {
  "$PYTHON" -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$WHEEL"
}

# run_package args... -> runs the installed jenerate command, as someone who
# installed it would, from a folder of the sandbox, and sets OUTPUT and
# STATUS.
run_package() {
  mkdir -p "$SANDBOX/elsewhere"
  OUTPUT="$(cd "$SANDBOX/elsewhere" &&
    in_sandbox env PATH="$BUILD/venv/bin:$SANDBOX/bin:$PATH" jenerate "$@" 2>&1)"
  STATUS=$?
}

after_sandbox() {
  quiet_desktop
  fake_os Linux
  DATA="$SANDBOX/home/$INSTALLED_DATA_PATH"
}

# --- Tests: what's in the package --------------------------------------------

# GIVEN the package
# WHEN listing its files
# THEN every app's templates and Blue Purple's pre-made themes are in its
#      data folder, laid out as in the repository
test_package_has_every_template_and_blue_purple() {
  local files missing
  files="$(wheel_files)"
  missing="$("$PYTHON" -c '
import sys
sys.path.insert(0, sys.argv[1])
from jenerate_themes.targets import TARGETS
files = set(sys.stdin.read().split("\n"))
for template, output in TARGETS:
    needed = {template.format(scheme=s) for s in ("dark", "light")}
    needed.add(output.format(slug="blue-purple"))
    for path in sorted(needed):
        if "jenerate_themes/data/" + path not in files:
            print(path)
' "$SANDBOX/repo" <<<"$files")"
  [ -z "$missing" ] || fail "expected these in the package's data folder: $missing"
  case "$files" in
    *"jenerate_themes/data/app-themes/vs-code-theme/package.json.tmpl"*) ;;
    *) fail "expected the VS Code package.json template in the package" ;;
  esac
}

# GIVEN the package
# WHEN listing its files
# THEN every palette in the repository is in it
test_package_has_every_palette() {
  local files palette
  files="$(wheel_files)"
  for palette in "$SANDBOX"/repo/palettes/*/*-palette.toml; do
    palette="${palette#"$SANDBOX/repo/"}"
    case "$files" in
      *"jenerate_themes/data/$palette"*) ;;
      *) fail "expected $palette in the package" ;;
    esac
  done
}

# GIVEN the package
# WHEN listing its files
# THEN what's only for the repository is left out: the READMEs, the palette
#      screenshots, the colors-to-avoid list, and the tests
test_package_leaves_out_the_repositorys_own_files() {
  local files
  files="$(wheel_files)"
  case "$files" in *README.md*) fail "expected no READMEs in the package" ;; esac
  case "$files" in *Screenshots*) fail "expected no screenshots in the package" ;; esac
  case "$files" in *avoid-these.txt*) fail "expected no avoid-these.txt in the package" ;; esac
  case "$files" in *tests/*) fail "expected no tests in the package" ;; esac
  case "$files" in *__pycache__*) fail "expected no __pycache__ in the package" ;; esac
}

# GIVEN the package
# WHEN reading its details
# THEN it's jenerate-themes, at the version in jenerate_themes, for Python
#      3.11 or later, with a jenerate command
test_package_details() {
  local version metadata
  version="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$SANDBOX/repo/jenerate_themes/__init__.py")"
  case "$WHEEL" in
    */jenerate_themes-"$version"-py3-none-any.whl) ;;
    *) fail "expected the package to be version $version, got $(basename "$WHEEL")" ;;
  esac
  metadata="$("$PYTHON" -c '
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for name in z.namelist():
    if name.endswith(".dist-info/METADATA") or name.endswith(".dist-info/entry_points.txt"):
        print(z.read(name).decode())
' "$WHEEL")"
  OUTPUT="$metadata"
  assert_contains "Name: jenerate-themes"
  assert_contains "Version: $version"
  assert_contains "Requires-Python: >=3.11"
  assert_contains "jenerate = jenerate_themes.cli:main"
}

# GIVEN the package
# WHEN reading the README in its details (its page on PyPI)
# THEN every link goes to GitHub, since neither a relative link nor a link
#      to a section works on PyPI, and the screenshot links to the image
#      itself
test_package_readme_links_work_on_pypi() {
  OUTPUT="$("$PYTHON" -c '
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
metadata = next(z.read(n).decode() for n in z.namelist() if n.endswith(".dist-info/METADATA"))
for link in re.findall(r"\]\(([^)]+)\)", metadata):
    print(link)
' "$WHEEL")"
  assert_contains "https://raw.githubusercontent.com/savagejen/jenerated-themes/main/Screenshot.png"
  assert_contains "https://github.com/savagejen/jenerated-themes/blob/main/app-themes/tilix-theme/"
  assert_contains "https://github.com/savagejen/jenerated-themes#setting-up-by-hand"
  local relative
  relative="$(printf '%s\n' "$OUTPUT" | grep -v '^https://')"
  [ -z "$relative" ] || fail "expected no relative links in the PyPI README, got: $relative"
}

# GIVEN the source package (what the wheel is built from, and what PyPI
#       keeps alongside it)
# WHEN listing its files
# THEN it has the code, the templates, the palettes and the project's
#      files, and leaves out the tests, the maintainer tools and the
#      screenshots
test_source_package_has_what_a_build_needs() {
  local files
  files="$(tar -tzf "$SDIST" | sed 's|^[^/]*/||')"
  OUTPUT="$files"
  for file in pyproject.toml LICENSE README.md CHANGELOG.md jenerate_themes/cli.py \
    jenerate_themes/creator/palette-creator.html app-themes/tilix-theme/scheme.json.tmpl \
    app-themes/tilix-theme/blue-purple.json palettes/Dark/blue-purple-palette.toml; do
    printf '%s\n' "$files" | grep -qxF "$file" || fail "expected $file in the source package"
  done
  assert_not_contains "tests/"
  assert_not_contains "maintainer-tools/"
  assert_not_contains "Screenshots"
  assert_not_contains "setup.sh"
}

# --- Tests: the installed command --------------------------------------------

# GIVEN the package installed
# WHEN running jenerate --version
# THEN it prints the version
test_installed_command_runs() {
  local version
  version="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' "$SANDBOX/repo/jenerate_themes/__init__.py")"
  run_package --version
  assert_status 0
  [ "$OUTPUT" = "jenerate-themes $version" ] || fail "expected 'jenerate-themes $version', got '$OUTPUT'"
}

# GIVEN the package installed
# WHEN listing and generating palettes, and installing Blue Purple into Tilix
# THEN its messages call it jenerate, the themes go in the data folder, and
#      Tilix is linked to the data folder's pre-made Blue Purple
test_installed_command_generates_and_installs() {
  run_package list
  assert_status 0
  assert_contains "  blue-purple "
  run_package generate sunset
  assert_status 0
  assert_exists "$DATA/app-themes/tilix-theme/sunset.json"
  OUTPUT="$(cd "$SANDBOX/elsewhere" && printf 'y\n1\n' |
    in_sandbox env PATH="$BUILD/venv/bin:$SANDBOX/bin:$PATH" jenerate install tilix blue-purple 2>&1)"
  STATUS=$?
  assert_status 0
  assert_contains "Run jenerate again any time"
  assert_link "$SANDBOX/home/.config/tilix/schemes/jenerated-blue-purple.json" \
    "$DATA/app-themes/tilix-theme/blue-purple.json"
}

run_tests
