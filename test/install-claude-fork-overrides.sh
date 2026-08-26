#!/usr/bin/env bash
#
# A fork needs to install its own content without editing the installer, so the
# source repository, the CLAUDE.md destination, and the first-party skill list
# are all environment-overridable. Defaults must stay exactly as upstream ships
# them: an unset variable installs citypaul/.dotfiles, unchanged.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
FAILURES=0

# The stubs shadow git on PATH but still need the real binary for local
# queries. Resolve it now, before the stub directory is prepended: Git Bash on
# Windows ships git at /mingw64/bin/git, not /usr/bin/git.
REAL_GIT="$(command -v git)"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo -e "${GREEN}PASS${NC}: $1"; }

RELEASE_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
mkdir -p "$TMPDIR/bin"

# git stub: the remote publishes one release tag. Local queries stay real so
# own_checkout / rev-parse behave normally.
cat > "$TMPDIR/bin/git" <<STUB
#!/usr/bin/env bash
args="\$*"
case "\$args" in
  *ls-remote*--tags*)
    echo "$RELEASE_SHA	refs/tags/v4.12.1"
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
printf '%s\n' "$*" >> "$NPX_LOG"
exit 0
STUB

# curl stub: log every URL, and create whatever -o target was requested so
# download_file's success path runs.
cat > "$TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CURL_LOG"
out=""; prev=""
for a in "$@"; do
  [[ "$prev" == "-o" ]] && out="$a"
  prev="$a"
done
[[ -n "$out" ]] && printf '# stub content\n' > "$out"
exit 0
STUB

chmod +x "$TMPDIR/bin/git" "$TMPDIR/bin/npx" "$TMPDIR/bin/curl"

run_installer() {
  ( cd "$REPO_ROOT" && HOME="$HOME_DIR" PATH="$TMPDIR/bin:$PATH" \
      NPX_LOG="$NPX_LOG" CURL_LOG="$CURL_LOG" \
      "$REPO_ROOT/install-claude.sh" "$@" 2>&1 )
}

new_case() {
  HOME_DIR="$TMPDIR/home_$1"; NPX_LOG="$TMPDIR/npx_$1.log"; CURL_LOG="$TMPDIR/curl_$1.log"
  mkdir -p "$HOME_DIR/.claude"
  : > "$NPX_LOG"; : > "$CURL_LOG"
}

echo "Testing fork overrides..."
echo ""

# --- 1. OWN_SKILLS_REPO_BASE redirects the skills source --------------------
new_case own
set +e
OUT=$(OWN_SKILLS_REPO_BASE="conjurer-rich/.dotfiles" \
      run_installer --skills-only --no-external --no-impeccable)
set -e

if printf '%s' "$OUT" | grep -q "conjurer-rich/.dotfiles"; then
  pass "OWN_SKILLS_REPO_BASE redirects the skills source"
else
  fail "the overridden skills repo must be used"
fi

# --- 2. Default is unchanged when unset ------------------------------------
new_case own_default
set +e
OUT2=$(run_installer --skills-only --no-external --no-impeccable)
set -e

if printf '%s' "$OUT2" | grep -q "citypaul/.dotfiles"; then
  pass "an unset OWN_SKILLS_REPO_BASE still resolves citypaul/.dotfiles"
else
  fail "the default source must be preserved"
fi

# --- 3. BASE_URL redirects artifact downloads ------------------------------
new_case base
set +e
BASE_URL="https://raw.githubusercontent.com/conjurer-rich/.dotfiles" \
  run_installer --claude-only >/dev/null
set -e

if grep -q "conjurer-rich/.dotfiles" "$CURL_LOG"; then
  pass "BASE_URL redirects artifact downloads"
else
  fail "the overridden base URL must be used for downloads"
fi

# --- 4. BASE_URL default is unchanged when unset ---------------------------
new_case base_default
set +e
run_installer --claude-only >/dev/null
set -e

if grep -q "citypaul/.dotfiles" "$CURL_LOG"; then
  pass "an unset BASE_URL still downloads from citypaul/.dotfiles"
else
  fail "the default base URL must be preserved"
fi

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
