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
require_text 'Every comment and thread reply the delegator posts therefore ends with' "every delegator post is marked"
require_text 'does not end in `[bot]`' "bot comments never need an answer"
require_text 'does not contain `<!-- preview-`' "preview stickies never need an answer"
require_text 'issues/<PR>/comments --paginate' "Review reads top-level PR comments"
require_text 'Merge a PR, except through **Land** with `land` on.' "merging is confined to Land"
require_text '`gh pr ready` runs only with `--undo`' "only the human marks a PR ready"
reject_regex 'merge a PR, resolve a review thread' "the unconditional never-merge line is gone"

# Task 2: Watch
require_text '### Watch' "Watch entry point exists"
require_text 'READY_FOR_REVIEW_EVENT' "Ready is read from the PR timeline"
# timelineItems' totalCount ignores itemTypes and counts every timeline item,
# so a gate on it calls every PR ready. filteredCount is the filtered count.
require_text 'ready: timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT]){ filteredCount }' "Ready counts only ready events"
require_text '`ready.filteredCount` is above 0' "Ready gates on the filtered count"
reject_regex 'totalCount' "no gate reads the unfiltered timeline count"
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
require_text 'force-push, or rebase a pushed branch' "the Never list forbids force-push and rebase"
require_text 'If the PR is now a draft, its head is no longer the verified SHA, or a comment needs an answer, stop without merging.' "a PR changed mid-land is not merged"
require_text 'continue only when every changed path is one the project'"'"'s CI ignores' "no checks passes only for CI-ignored paths"

# Review findings: resume, late commits, answers, unattended failures
require_text 'Steps 1–3 always run, including on resume.' "resuming Land still checks eligibility"
require_text 'Bail-out** with the reason `commits after Ready`' "a commit pushed after Ready is not landed"
require_text '<!-- delegator reply-to: <comment id> -->' "a top-level answer names the comment it answers"
require_text 'pulls/<PR>/reviews --paginate' "a review summary body is read as a comment"
require_text 'Never go to **Blocked** from **Watch** or **Land**.' "an unattended run never waits on approval"
require_text 'timeout 540 gh pr checks' "each CI wait fits one tool call"
require_text 'If `gh pr merge` exits non-zero, go to **Bail-out**' "a refused merge hands the PR back"
reject_regex 'search "head:' "Watch filters branches locally, not by fuzzy search"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
