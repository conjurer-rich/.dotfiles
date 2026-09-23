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

# Task 2: Watch
require_text '### Watch' "Watch entry point exists"
require_text 'READY_FOR_REVIEW_EVENT' "Ready is read from the PR timeline"
require_text 'never Ready' "a PR opened as non-draft is never landed"
require_text 'holds no state between passes' "Watch keeps no local state"
require_text 'about 270 seconds while any Land is waiting on CI' "Watch paces faster only while CI is pending"

# Task 3: Land
require_text '### Land `#PR`' "Land entry point exists"
require_text 'If `land` is off, say so and stop.' "Land refuses when land is off"
require_text 'git merge --no-edit origin/<default branch>' "conflicts are resolved by merging main in"
require_text '<!-- delegator land: reviewed <sha> -->' "Land records the SHA it verified"
require_text 'no checks reported' "a docs-only PR with no CI checks can land"
require_text 'Check `isDraft` again' "a PR returned to draft mid-land is not merged"
require_text '--squash --match-head-commit <verified SHA>' "only the verified head is merged"
require_text 'Fix or answer, then mark the PR ready again.' "bail-out hands the PR back to the human"
reject_regex 'git rebase|git push (--force|-f)' "Land never rebases or force-pushes"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
