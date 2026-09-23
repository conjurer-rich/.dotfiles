#!/usr/bin/env bash
#
# Guard the delegation landing policy: who may mark a PR ready, how the
# delegator tells its own comments from the human's, and what Land may and may
# not do before it merges.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$REPO_ROOT/claude/.claude/skills/delegating-github-issues/SKILL.md"
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

require_text() {
  local pattern="$1" label="$2"

  if grep -Fq -- "$pattern" "$SKILL"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_regex() {
  local pattern="$1" label="$2"

  if grep -Eiq -- "$pattern" "$SKILL"; then
    fail "$label"
  else
    pass "$label"
  fi
}

# Task 1: parameter, drafts, marker, Never list
require_text '| `land` | off |' "land parameter defaults to off"
require_text 'add `--draft` when `land` is on' "Work opens a draft when land is on"
require_text '<!-- delegator -->' "delegator comments carry the marker"
require_text 'does not end in `[bot]`' "bot comments never need an answer"
require_text 'does not contain `<!-- preview-`' "preview stickies never need an answer"
require_text 'issues/<PR>/comments --paginate' "Review reads top-level PR comments"
require_text 'Merge a PR, except through **Land** with `land` on.' "merging is confined to Land"
require_text '`gh pr ready` runs only with `--undo`' "only the human marks a PR ready"
reject_regex 'merge a PR, resolve a review thread' "the unconditional never-merge line is gone"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
