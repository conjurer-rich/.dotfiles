#!/usr/bin/env bash
#
# Guard the plugin manifest version. Claude Code detects a marketplace plugin
# update from plugin.json's `version`, not from git commits, so a manifest
# that lags fork/package.json pins every installed copy to an old release.
# The manifest sat at 4.12.2 for eleven releases before this test existed.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE="$REPO_ROOT/fork/package.json"
MANIFEST="$REPO_ROOT/claude/.claude/.claude-plugin/plugin.json"
SYNC="$REPO_ROOT/fork/sync-plugin-version.mjs"
WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
}

json_version() {
  node -p "require('$1').version"
}

# 1. The committed manifest matches the committed release version.
release_version="$(json_version "$RELEASE")"
manifest_version="$(json_version "$MANIFEST")"
if [ "$release_version" = "$manifest_version" ]; then
  pass "plugin.json version ($manifest_version) matches fork/package.json"
else
  fail "plugin.json version ($manifest_version) lags fork/package.json ($release_version); run node fork/sync-plugin-version.mjs"
fi

# 2. The release workflow runs the sync in the same step as changeset version,
#    so the "chore: version packages" PR carries both bumps.
if grep -Fq 'version: pnpm changeset version && node fork/sync-plugin-version.mjs' "$WORKFLOW"; then
  pass "release.yml syncs the manifest after changeset version"
else
  fail "release.yml syncs the manifest after changeset version"
fi

# 3. The sync script rewrites the version line and nothing else, and is
#    idempotent. Exercised on a copy of the repo layout so the checkout stays
#    untouched.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/fork" "$TMP/claude/.claude/.claude-plugin"
cp "$SYNC" "$TMP/fork/"
printf '{\n  "name": "@conjurer-rich/dotfiles",\n  "version": "9.9.9"\n}\n' > "$TMP/fork/package.json"
cp "$MANIFEST" "$TMP/claude/.claude/.claude-plugin/plugin.json"

if node "$TMP/fork/sync-plugin-version.mjs" > /dev/null \
  && [ "$(json_version "$TMP/claude/.claude/.claude-plugin/plugin.json")" = "9.9.9" ]; then
  pass "sync script copies the release version into the manifest"
else
  fail "sync script copies the release version into the manifest"
fi

expected="$(sed "s/\"version\": \"$manifest_version\"/\"version\": \"9.9.9\"/" "$MANIFEST")"
if [ "$(cat "$TMP/claude/.claude/.claude-plugin/plugin.json")" = "$expected" ]; then
  pass "sync script changes only the version line"
else
  fail "sync script changes only the version line"
fi

before="$(cat "$TMP/claude/.claude/.claude-plugin/plugin.json")"
if node "$TMP/fork/sync-plugin-version.mjs" > /dev/null \
  && [ "$(cat "$TMP/claude/.claude/.claude-plugin/plugin.json")" = "$before" ]; then
  pass "sync script is idempotent"
else
  fail "sync script is idempotent"
fi

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
