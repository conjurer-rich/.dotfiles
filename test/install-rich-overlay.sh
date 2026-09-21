#!/usr/bin/env bash
#
# The fork wrapper installs a CLAUDE.md overlay that @-imports upstream's file
# at ~/.claude/base-CLAUDE.md. The overlay is only half of a pair: installing it
# when install-claude.sh did not write the base leaves a dangling import and
# silently replaces the user's real CLAUDE.md. So the overlay must follow the
# same gate as upstream's CLAUDE.md -- skipped by --help and by every mode flag
# that sets INSTALL_CLAUDE=false.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
FAILURES=0

REAL_GIT="$(command -v git)"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo -e "${GREEN}PASS${NC}: $1"; }

mkdir -p "$TMPDIR/bin"

cat > "$TMPDIR/bin/git" <<STUB
#!/usr/bin/env bash
args="\$*"
case "\$args" in
  *ls-remote*--tags*)
    echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	refs/tags/v4.12.1"
    exit 0 ;;
  *ls-remote*)
    echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb	refs/heads/main"
    exit 0 ;;
  *"remote -v"*) exec "$REAL_GIT" "\$@" ;;
  *merge-base*) exit 1 ;;
  *fetch*) exit 0 ;;
  *rev-parse*|*show-ref*) exec "$REAL_GIT" "\$@" ;;
esac
exit 0
STUB

cat > "$TMPDIR/bin/npx" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

cat > "$TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do
  [[ "$prev" == "-o" ]] && out="$a"
  prev="$a"
done
[[ -n "$out" ]] && printf '# stub content\n' > "$out"
exit 0
STUB

chmod +x "$TMPDIR/bin/git" "$TMPDIR/bin/npx" "$TMPDIR/bin/curl"

new_case() {
  HOME_DIR="$TMPDIR/home_$1"
  mkdir -p "$HOME_DIR/.claude"
  printf '# the user existing CLAUDE.md\n' > "$HOME_DIR/.claude/CLAUDE.md"
}

run_wrapper() {
  ( cd "$REPO_ROOT" && HOME="$HOME_DIR" PATH="$TMPDIR/bin:$PATH" \
      "$REPO_ROOT/install-rich.sh" "$@" 2>&1 )
}

echo "Testing the fork wrapper overlay..."
echo ""

# --- 1. --help must not touch the user's CLAUDE.md -------------------------
new_case help
set +e
run_wrapper --help >/dev/null
set -e

if grep -q "the user existing CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"; then
  pass "--help leaves the existing CLAUDE.md untouched"
else
  fail "--help must not install the overlay"
fi

if ! ls "$HOME_DIR/.claude/CLAUDE.md.backup."* >/dev/null 2>&1; then
  pass "--help creates no backup"
else
  fail "--help must not back up a file it has no business replacing"
fi

# --- 2. A mode that skips upstream's CLAUDE.md skips the overlay too -------
new_case skills
set +e
run_wrapper --skills-only --no-external --no-impeccable >/dev/null
set -e

if grep -q "the user existing CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"; then
  pass "--skills-only leaves the existing CLAUDE.md untouched"
else
  fail "--skills-only must not install the overlay: the base is never written"
fi

# --- 3. A run that does install upstream's CLAUDE.md installs the overlay --
new_case claude
set +e
run_wrapper --claude-only >/dev/null
set -e

if grep -q "@~/.claude/base-CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"; then
  pass "--claude-only installs the overlay"
else
  fail "the overlay must be installed when the base is"
fi

if [[ -f "$HOME_DIR/.claude/base-CLAUDE.md" ]]; then
  pass "upstream's CLAUDE.md lands at base-CLAUDE.md, so the import resolves"
else
  fail "the overlay's import target must exist"
fi

if ls "$HOME_DIR/.claude/CLAUDE.md.backup."* >/dev/null 2>&1; then
  pass "the replaced CLAUDE.md is backed up"
else
  fail "an existing CLAUDE.md must be backed up before replacement"
fi

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
