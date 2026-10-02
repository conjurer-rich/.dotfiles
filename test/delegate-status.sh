#!/usr/bin/env bash
#
# Test the delegating-github-issues bookkeeping script against recorded gh
# JSON. A fake gh and git (test/fixtures/delegate-status/bin) serve the
# fixtures, apply writes to the recorded comments, and log every call, so a
# test can check both what the script printed and what it wrote to GitHub.
#
# Covers the races the Claims protocol exists for (two claims at once, a
# lapsed claim with the lower id, renewing a lapsed claim, a stale progress
# label), squash-merged worktree reclaim, the needs-an-answer rules (marker,
# Claude Code footer, [bot] and Bot authors, preview stickies, reply-to), PR
# classification, Land markers and the Pick skip cache.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUS="$REPO_ROOT/claude/.claude/skills/delegating-github-issues/scripts/delegate-status"
FIXTURES="$SCRIPT_DIR/fixtures/delegate-status"
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 2026-10-02T12:00:00Z
NOW=1790942400
OURS=a1b2c3d4
OTHER=e5f6a7b8

# Fresh copy of a scenario, so writes from one test never leak into the next.
use() {
  export FAKE_STATE="$TMP/$1-$RANDOM$RANDOM"
  cp -R "$FIXTURES/$1" "$FAKE_STATE"
  : > "$FAKE_STATE/calls.log"
}

run() {
  PATH="$FIXTURES/bin:$PATH" DELEGATE_STATUS_NOW="${RUN_NOW:-$NOW}" "$STATUS" "$@" \
    --repo acme/widgets --session "$OURS" --claim-ttl 14400
}

# check <label> <json> <jq expression that must be true>
check() {
  local label="$1" json="$2" expr="$3"

  if printf '%s' "$json" | jq -e "$expr" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
    printf '      got: %s\n' "$(printf '%s' "$json" | head -c 600)"
  fi
}

called() {
  grep -Fq -- "$1" "$FAKE_STATE/calls.log"
}

check_called() {
  if called "$1"; then pass "$2"; else fail "$2"; fi
}

check_not_called() {
  if called "$1"; then fail "$2"; else pass "$2"; fi
}

if [ ! -x "$STATUS" ]; then
  fail "scripts/delegate-status exists and is executable"
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

# ---------------------------------------------------------------- usage

if PATH="$FIXTURES/bin:$PATH" "$STATUS" > /dev/null 2>&1; then
  fail "no command is a usage error"
else
  pass "no command is a usage error"
fi
if PATH="$FIXTURES/bin:$PATH" "$STATUS" status > /dev/null 2>&1; then
  fail "status without --repo is a usage error"
else
  pass "status without --repo is a usage error"
fi

# ---------------------------------------------------------------- claim

# Two sessions claimed issue 7 at once: theirs has the lower id, so they win
# and we withdraw ours.
use claims
out="$(run claim 7)"
check "a claim that loses the race reports lost and the holder" "$out" \
  '.result == "lost" and .item == 7 and .holder == "'"$OTHER"'"'
check_called "-X DELETE repos/acme/widgets/issues/comments/900" "the losing session deletes its own claim"
check_not_called "-X DELETE repos/acme/widgets/issues/comments/100" "the losing session leaves the winner's claim alone"
check_not_called "issues/7/labels" "the losing session adds no label"

# A lapsed claim keeps its lower id but no longer counts.
use claims
out="$(run claim 8)"
check "a claim beats a lapsed claim with a lower id" "$out" '.result == "won" and .id == 900'
check_called "-X POST repos/acme/widgets/issues/8/labels -f labels[]=in-progress" "a winning claim adds the progress label"
check_not_called "comments/200" "a lapsed claim of another session is not touched"

# Holding a live claim already: use it, post nothing new.
use claims
out="$(run claim 9)"
check "a live claim of our own is reused" "$out" '.result == "won" and .id == 300'
check_not_called "-X POST repos/acme/widgets/issues/9/comments" "no second claim is posted"

# The label is created when the repository lacks it, never with --force.
use claims
echo '[]' > "$FAKE_STATE/labels.json"
run claim 8 > /dev/null
check_called "label create -R acme/widgets in-progress" "a missing progress label is created"
check_not_called "--force" "the label is never created with --force"

# An open delegated PR for the issue is reported on a won claim.
use claims
out="$(run claim 12)"
check "a won claim names an open delegated PR for the issue" "$out" '.result == "won" and .open_pr == 40'

# ---------------------------------------------------------------- confirm and renew

use claims
check "confirm: our live, lowest claim is live" "$(run confirm 9 300)" '.result == "live"'
check "confirm: a claim outranked by a lower live claim is lost" "$(run confirm 7 99)" '.result == "lost"'
check "confirm: a lapsed claim is lost" "$(run confirm 10 400)" '.result == "lost" and .holder == "'"$OTHER"'"'

use claims
out="$(run renew 10 400)"
check "renew refuses a lapsed claim another session has since outranked" "$out" '.result == "lost"'
check_not_called "-X PATCH" "renewing a lapsed claim writes nothing"

use claims
out="$(run renew 9 300)"
check "renew rewrites a live claim" "$out" '.result == "renewed" and .id == 300'
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "the renewed claim's first line ends with the renewal time" "$(jq -n --arg b "$body" '$b')" \
  '(split("\n")[0] | endswith("renewed 2026-10-02T12:00:00Z")) and (split("\n")[1] == "<!-- delegator claim: '"$OURS"' -->")'
run renew 9 300 > /dev/null
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "a second renewal replaces the first timestamp" "$(jq -n --arg b "$body" '$b')" \
  '(split("\n")[0] | [scan("renewed")] | length) == 1'

# ---------------------------------------------------------------- release

use claims
out="$(run release 9 300 --reason 'PR opened')"
check "release reports released" "$out" '.result == "released"'
check_called "-X DELETE repos/acme/widgets/issues/9/labels/in-progress" "release removes the label first"
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "release rewrites the claim as released" "$(jq -n --arg b "$body" '$b')" \
  '. == "Released by delegator session `'"$OURS"'`: PR opened.\n<!-- delegator claim-released: '"$OURS"' -->"'

use claims
run release 9 300 --delete > /dev/null
check "release --delete deletes the claim" "$(cat "$FAKE_STATE/comments-9.json")" 'all(.[]; .id != 300)'

use claims
touch "$FAKE_STATE/labels-404"
check "a label already gone does not fail the release" "$(run release 9 300 --delete)" '.result == "released"'

use claims
if run release 11 500 --delete > /dev/null 2>&1; then
  fail "release refuses another session's claim"
else
  pass "release refuses another session's claim"
fi
check_not_called "-X DELETE repos/acme/widgets/issues/comments/500" "another session's claim is never deleted"
check_not_called "-X DELETE repos/acme/widgets/issues/11/labels" "another session's label is never removed"

# Release touches only the item it names, and leaves the label to a session
# that has since won the item.
use claims
if run release 11 300 --delete > /dev/null 2>&1; then
  fail "release refuses a claim comment that belongs to another item"
else
  pass "release refuses a claim comment that belongs to another item"
fi
check_not_called "-X DELETE repos/acme/widgets/issues/comments/300" "a claim on another item is never deleted"
use claims
out="$(run release 10 400 --reason 'lapsed' || true)"
check "releasing a lapsed claim reports released" "$out" '.result == "released"'
check_not_called "-X DELETE repos/acme/widgets/issues/10/labels" "releasing a lapsed claim leaves the new holder's label"

# ---------------------------------------------------------------- clear-label

use claims
if run clear-label 7 > /dev/null 2>&1; then
  fail "clear-label refuses an item with a live claim"
else
  pass "clear-label refuses an item with a live claim"
fi
check "clear-label removes a label left by a lapsed claim" "$(run clear-label 8)" '.result == "cleared"'
check_called "-X DELETE repos/acme/widgets/issues/8/labels/in-progress" "clear-label deletes the label"

# ---------------------------------------------------------------- status

use status
out="$(run status --max-worktrees 5 --max-open-prs 6 --land on)"

check "status prints one JSON object" "$out" 'type == "object"'

# Worktrees and budget
check "a squash-merged, clean worktree at the PR's head is reclaimable" "$out" \
  '.worktrees.reclaim == [{"path": "/wt/2-merged", "branch": "delegated/2-merged", "pr": 30}]'
check "worktrees that must stay are reported with a reason" "$out" \
  '[.worktrees.keep[] | [.branch, .reason]] == [["delegated/3-dirty", "uncommitted"], ["delegated/4-open", "pr-open"], ["delegated/5-nopr", "no-pr"], ["delegated/6-unpushed", "unpushed"]]'
check "the main worktree is ignored" "$out" 'all(.worktrees.keep[]; .branch != "main")'
check "budget counts worktrees after reclaim and all open PRs" "$out" \
  '.budget == {"worktrees": 4, "max_worktrees": 5, "open_prs": 6, "max_open_prs": 6, "at_limit": true}'

# Issues, in the skill's sort order
check "issues come in rank order, oldest first within a rank" "$out" \
  '[.issues[].number] == [14, 32, 31, 38, 33, 36, 37, 34, 35]'
issue() { printf '.issues[] | select(.number == %s)' "$1"; }
check "an issue with an open delegated PR is delegated" "$out" "$(issue 14) | .state == \"delegated\" and .pr == 20"
check "criteria in the body make an issue free" "$out" "$(issue 31) | .state == \"free\" and .criteria == \"body\""
check "a criteria heading with no list is not criteria" "$out" "$(issue 32) | .criteria != \"body\""
check "derived criteria without the human's thumbs-up wait on the human" "$out" \
  "$(issue 32) | .state == \"waiting-on-human\" and .reason == \"criteria-unconfirmed\""
check "derived criteria with the human's thumbs-up are confirmed" "$out" "$(issue 33) | .state == \"free\" and .criteria == \"confirmed\""
check "an answered question leaves criteria to derive" "$out" "$(issue 34) | .state == \"free\" and .criteria == \"none\""
check "an agent's reply does not answer a delegator question" "$out" \
  "$(issue 35) | .state == \"waiting-on-human\" and .reason == \"question-unanswered\""
check "an issue another session holds is claimed, with the holder" "$out" "$(issue 36) | .state == \"claimed\" and .holder == \"$OTHER\""
check "a progress label with no live claim is stale and the issue is free" "$out" \
  "$(issue 37) | .state == \"free\" and .stale_label == true"
check "an issue this session holds is held" "$out" "$(issue 38) | .state == \"held\""
check "a claimed issue's label is not stale" "$out" "$(issue 36) | .stale_label == false"

# PRs
pr() { printf '.prs[] | select(.number == %s)' "$1"; }
check "only delegated PRs are classified" "$out" '[.prs[].number] == [20, 21, 22, 23, 24]'
check "an unresolved thread whose last comment is the human's needs an answer" "$out" \
  "$(pr 20) | .needs_answer.threads == [{\"id\": \"T1\", \"comment\": 601}]"
check "marker, footer, bot, preview and reply-to comments need no answer" "$out" \
  "$(pr 20) | .needs_answer.comments == [505]"
check "an unanswered review body needs an answer; an answered or bot one does not" "$out" \
  "$(pr 20) | .needs_answer.reviews == [701]"
check "a draft with comments to answer needs review" "$out" "$(pr 20) | .class == \"needs-review\""
check "a non-draft PR marked ready is Ready" "$out" "$(pr 21) | .class == \"ready\" and .latest == \"ReadyForReviewEvent\""
check "the latest land marker is reported and matched to the head" "$out" \
  "$(pr 21) | .land_marker == {\"sha\": \"h21\", \"verified\": true}"
check "a non-draft PR never marked ready is idle with land on" "$out" "$(pr 22) | .class == \"idle\""
check "a PR another session holds is claimed" "$out" "$(pr 23) | .class == \"claimed\" and .holder == \"$OTHER\""
check "a PR with a stale label is flagged and classified" "$out" "$(pr 24) | .stale_label == true and .class == \"idle\""

out="$(run status --land off)"
check "with land off, a non-draft PR with a comment to answer needs review" "$out" "$(pr 22) | .class == \"needs-review\""
check "with land off, nothing is Ready" "$out" 'all(.prs[]; .class != "ready")'
check "the default budget limits are the skill's" "$out" '.budget.max_worktrees == 1 and .budget.max_open_prs == 6'

if grep -E -- '-X (POST|PATCH|DELETE)' "$FAKE_STATE/calls.log" > /dev/null; then
  fail "status writes nothing"
else
  pass "status writes nothing"
fi

# ---------------------------------------------------------------- budget and one issue

# A hand-started Work needs the budget and its own issue, not a full pass.
use status
out="$(run budget --max-worktrees 5 || true)"
check "budget prints the worktrees and the counts status prints" "$out" \
  '.worktrees.reclaim[0].branch == "delegated/2-merged" and .budget.worktrees == 4 and .budget.open_prs == 6 and .budget.at_limit'
if grep -Fq "issue list" "$FAKE_STATE/calls.log"; then
  fail "budget reads no issues"
else
  pass "budget reads no issues"
fi

out="$(run issue 31 || true)"
check "issue classifies one eligible issue as status does" "$out" '.number == 31 and .eligible and .state == "free" and .criteria == "body"'
out="$(run issue 32 || true)"
check "issue reports why an issue waits on the human" "$out" '.state == "waiting-on-human" and .reason == "criteria-unconfirmed"'
out="$(run issue 14 || true)"
check "issue reports an issue that already has a delegated PR" "$out" '.state == "delegated" and .pr == 20'
out="$(run issue 50 || true)"
check "a closed issue is not eligible" "$out" '.eligible == false and .state == "not-eligible"'
out="$(run issue 51 || true)"
check "an issue without the label is not eligible" "$out" '.eligible == false and .state == "not-eligible"'

# Every gh call that is not `gh api` names the repository, so a checkout of
# a fork never reads the fork's issues and PRs while claiming upstream.
use status
run status --land on > /dev/null
if grep -E '^(issue|pr|label) ' "$FAKE_STATE/calls.log" | grep -vq -- '-R acme/widgets'; then
  fail "every gh issue, pr and label call names the repository"
else
  pass "every gh issue, pr and label call names the repository"
fi
check_called "-f owner=acme -f repo=widgets" "graphql sends owner and repo as strings"

# A held issue still says how its criteria stand.
use status
out="$(run status --land on || true)"
check "a held issue reports its criteria" "$out" "$(issue 38) | .state == \"held\" and .criteria == \"none\""

# ---------------------------------------------------------------- one PR

# Review and Land read one PR: its class, and the bodies of what needs an
# answer, so the delegator can classify each request.
use status
out="$(run pr 20 --land on || true)"
check "pr reports the same class as status" "$out" '.number == 20 and .class == "needs-review"'
check "pr lists each comment needing an answer with its body" "$out" \
  '[.items[] | [.kind, .id]] == [["thread", 601], ["comment", 505], ["review", 701]]'
check "a thread item carries its thread id, path and line" "$out" \
  '.items[0] == {"kind": "thread", "id": 601, "thread": "T1", "path": "src/import.ts", "line": 42, "login": "rich", "body": "Rename this please"}'
out="$(run pr 21 --land on || true)"
check "pr reports Ready, the head and the verified land marker" "$out" \
  '.class == "ready" and .head == "h21" and .isDraft == false and .land_marker.verified and .items == []'

# ---------------------------------------------------------------- Pick skip cache

use status
CACHE="$FAKE_STATE/pick-cache.json"
run status --cache "$CACHE" > /dev/null
check "the cache records each skipped issue with its reason, but not unconfirmed criteria" "$(cat "$CACHE")" \
  '[.[] | [.number, .reason]] | sort == [[35, "waiting-on-human"], [36, "claimed"]]'

: > "$FAKE_STATE/calls.log"
out="$(run status --cache "$CACHE")"
check_called "issues/32/comments" "unconfirmed criteria are re-read every pass: a thumbs-up does not bump updatedAt"
check_not_called "issues/35/comments" "an unchanged unanswered question is not re-read"
check_not_called "issues/36/comments" "a recently claimed issue is not re-read"
check "a cached skip keeps its state" "$out" "$(issue 35) | .state == \"waiting-on-human\" and .cached == true"

jq 'map(if .number == 32 then .updatedAt = "2026-10-02T11:59:00Z" else . end)' \
  "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.tmp" && mv "$FAKE_STATE/issues.tmp" "$FAKE_STATE/issues.json"
jq 'map(if .number == 35 then .updatedAt = "2026-10-02T11:59:00Z" else . end)' \
  "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.tmp" && mv "$FAKE_STATE/issues.tmp" "$FAKE_STATE/issues.json"
: > "$FAKE_STATE/calls.log"
run status --cache "$CACHE" > /dev/null
check_called "issues/35/comments" "an issue updated since it was cached is re-read"

: > "$FAKE_STATE/calls.log"
RUN_NOW=$((NOW + 14401)) run status --cache "$CACHE" > /dev/null
check_called "issues/36/comments" "a claimed issue is re-read once claim_ttl has passed"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
