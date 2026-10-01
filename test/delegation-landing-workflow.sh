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
# The watcher may run on a machine that did not open the PR, so Review, not
# just Land, must be able to create the worktree it needs.
require_text 'If none exists (another machine or session opened the PR), `git fetch origin <head branch>`, then `git worktree add <path> <head branch>`' "Review creates a missing worktree"
require_text 'Find or create the branch'"'"'s worktree as in **Review** step 2.' "Land reuses Review's worktree step"
require_text 'holds no state between passes' "Watch keeps no local state"
# A foreground CI wait held the whole watcher for up to 27 minutes in dry run 2.
# Land's long waits run in the background and wake the loop when they finish.
require_text 'the background task that finishes wakes the loop' "a Land waiting in the background wakes the loop itself"
reject_regex '270 seconds' "Watch no longer polls fast to babysit CI"

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
require_text 'gh pr checks <PR> --watch --fail-fast` as a background task' "the CI wait runs in the background"
reject_regex 'timeout 540' "no foreground CI wait sized to one tool call"
require_text 'If `gh pr merge` exits non-zero, go to **Bail-out**' "a refused merge hands the PR back"
reject_regex 'search "head:' "Watch filters branches locally, not by fuzzy search"

# Dry run 2 findings (#1708, #1710)
# Land's review took 24 minutes; a foreground subagent froze the watcher.
require_text 'with `subagent_type: general-purpose`, `model: opus`, `run_in_background: true`' "Land's review runs in the background"
require_text 'A review interrupted by a restart leaves staged changes' "a restarted Land discards a dead review's changes"
# Another agent session answered a thread without the marker, and the watcher
# treated its reply as the human's.
require_text 'it does not contain the Claude Code footer' "an unmarked agent reply is not the human's"
# Rich accepted three bail-out findings as follow-ups; the next Land must not
# bail on them again, and must learn that from GitHub, not local state.
require_text 'Findings listed under the PR body'"'"'s `## Found on the way, not fixed here` are accepted' "Land's review skips accepted findings"
require_text 'asks for findings as follow-ups' "Review files follow-ups when the human asks"
require_text 'To accept a finding instead, ask for it as a follow-up.' "bail-out says how to accept a finding"
# A bail-out on findings threw away a verified simplification that the next
# Land then had to redo.
require_text 'keep verified simplifications' "a bail-out on findings keeps verified simplifications"
# A squash merge leaves no ancestry, so reclaim compares head SHAs.
require_text 'equals the PR'"'"'s `headRefOid`' "reclaim matches a squash-merged branch by head SHA"
reject_regex 'and `git log origin/[^`]*` prints nothing' "reclaim never gates on ancestry"

# Skill-graph review: nothing independent checked the acceptance criteria or
# the whole diff before the human saw the PR, and the walkthrough's Fix step
# had the delegator writing production code after tdd-guardian had run.
require_text 'The implementer'"'"'s returns are claims, not evidence.' "the implementer's own report is not the evidence"
require_text 'loads `acceptance-review`' "acceptance criteria are checked independently"
require_text 'The project'"'"'s whole-PR review agent' "the whole diff is reviewed before the PR opens"
require_text 'do **not** run its Fix step' "the delegator never applies walkthrough fixes itself"
require_text 'Then re-run `tdd-guardian` and every check that reported a blocking finding, as step 7 dispatches them.' "the repair round is re-checked"
require_text 'edit this comment to change them, then react' "derived acceptance criteria wait for the human"
require_text 'including any glossary or vocabulary check' "the gate's glossary step is not dropped"
reject_regex 'gate'"'"'s steps 1–5' "the pre-PR gate is not truncated"

# Second pass on the skill-graph changes: a waiting issue must not be
# re-posted or jam Pick, only the human's own reaction confirms, the repair
# round refreshes the gate evidence, and the verdict words match the checkers.
require_text 'post nothing, and stop' "a waiting issue is never re-posted"
require_text 'Take the first issue that is not waiting on the human' "Pick skips issues waiting on the human"
require_text '`gh api user -q .login`' "only the authenticated login's reaction confirms"
require_text 'does not rate `Covered`' "acceptance verdicts use acceptance-review's statuses"
require_text 'rated Critical or High Priority' "whole-diff severity uses pr-reviewer's scale"
require_text 'returns (a)–(f) afresh' "the repair round refreshes the gate evidence"
require_text 'wait for it to exit' "the implementer waits for the background suite"
require_text 'On every path out of this step except **Blocked**' "the UX walkthrough section is written with or without a repair"
require_text 'the PR already exists, so **Blocked** does not apply' "a human-started Review never opens a second PR"

# Run: one unattended pass of Watch then Pick and Work, built for /loop.
require_text '### Run' "the skill has a Run entry point"
require_text 'When **Run** started this Work, commit without asking' "Work under Run commits without asking"
require_text 'skip Pick without commenting' "an over-budget Run pass never posts a paused comment"
require_text 'a Run pass never waits on the human' "Run never blocks on a human answer"

# Several sessions run /loop /delegate at once through one gh login, so
# assignees and labels cannot tell them apart. A claim comment names the
# session; the lowest live comment id settles a race; a lease lets a crashed
# session's claim lapse instead of locking the issue for good.
require_text '| `claim_ttl` | 4 hours |' "claims lapse after a default lease"
require_text '<!-- delegator claim: <session> -->' "a claim names the session holding it"
require_text 'live claim with the lowest comment id wins' "a race between two sessions has one winner"
require_text 'delete your own claim comment' "the losing session withdraws its claim"
require_text 'Every stop releases the claim' "a session releases its claim on every exit"
require_text '<!-- delegator claim-released: <session> -->' "a released claim stays readable on the issue"
require_text 'Skip an issue that has an open PR from a `<branch_prefix><n>-` branch' "Pick never re-picks an issue that already has a PR"
require_text 'skip an issue another session holds a live claim on' "Pick skips issues another session claimed"
require_text 'otherwise say this PR was not opened by a delegated run and stop. Then claim the PR (**Claims**)' "Review claims the PR before touching it"
require_text 'say so and stop. Then claim the PR (**Claims**); if another session holds it, stop. The PR must be **Ready**' "Land claims the PR before it can bail out"
require_text 'Confirm before any push, PR creation or merge.' "a session that lost its claim writes nothing more"
require_text 'Confirm the claim is still yours (**Claims**) before dispatching, and renew it. The ship subagent then runs `git push -u origin <branch>`' "Work confirms its claim before the ship subagent pushes"
require_text 'Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10'"'"'s brief without PR creation: it commits from the message file and pushes with no force flag' "Review confirms its claim before the ship subagent pushes"
require_text 'then `git push`, with no force flag; it returns the new head SHA' "Land's ship subagent pushes with no force flag"
require_text 'Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10'"'"'s brief without PR creation): step 4'"'"'s merge' "Land confirms its claim before the ship subagent pushes"
require_text 'Otherwise confirm the claim is still yours and run `gh pr merge <PR>' "Land confirms its claim before merging"
# Review of the first draft: a lapsed claim keeps its low id, so renewing it
# blindly steals the item back; and a session that released on opening its PR
# left a window for another session to claim the issue again.
require_text 'confirm the claim, then rewrite its first line' "renewal never revives a lapsed claim"
require_text 'If you already hold a live claim on the item, use it.' "a session never claims the same item twice"
require_text 'once claimed an open PR from a `<branch_prefix>N-` branch now exists' "a claim won just after another session opened its PR stops"
require_text 'A stop that posted nothing else on the item deletes the claim comment' "a waiting issue is still left without new comments"
require_text 'Comments that carry the delegator marker do not count as a change' "one session's claims do not wake every other session's poll"
require_text 'Edit or delete another session'"'"'s claim' "the Never list protects other sessions' claims"
# A claim comment is only visible once the issue is opened, so the issue list
# could not show what an agent was working on. A label shows it at a glance,
# but a label cannot carry a session name or lapse, so it stays a signal and
# the comment stays the lock.
require_text '| `progress_label` | `in-progress` |' "a label marks an item an agent is working on"
require_text 'The claim comment is the lock.' "the label never decides who holds an item"
require_text "issues/<n>/labels -f 'labels[]=<progress_label>'" "a winning claim adds the label"
require_text 'If it is yours, add the label' "only the winning session adds the label"
require_text 'First remove the label (`gh api -X DELETE repos/<owner>/<repo>/issues/<n>/labels/<progress_label>`' "every release removes the label"
require_text 'gh label create <progress_label>' "a missing label is created"
require_text 'Never `--force`' "an existing label keeps the human's colour and description"
require_text '**Stale label.**' "a crashed session's label is cleaned up"
require_text 'remove the label as **Stale label** in **Claims** says, and keep it as a candidate' "Pick does not skip an issue on a stale label"
require_text 'with no live claim is not Claimed' "Watch does not skip a PR on a stale label"
require_text 'Put `<progress_label>` on an item without holding a live claim on it' "the Never list forbids a label without a claim"

# A /loop /delegate run in a cloud container worked three issues at once and
# used the delegator's whole context in one pass: EnterWorktree pinned it to one
# worktree so every other git command was refused by the isolation guard, the
# browser walkthrough and the commit/push/PR steps ran inline, claims
# bookkeeping was thirty gh calls in the main context, every subagent report
# came back in full, Pick re-read every skipped issue on every pass, and nothing
# told the run to stop. Each guard below pins one of the fixes.
# A. The delegator never enters a worktree.
reject_regex 'EnterWorktree' "the skill no longer uses EnterWorktree"
require_text 'git worktree add <path> -b <branch_prefix>N-<slug> origin/<default branch>' "the worktree is created from the main checkout"
require_text 'Stay in the main checkout: the delegator never enters the worktree' "the delegator stays in the main checkout"
require_text 'It runs no `git` command inside a worktree other than `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune` and `git -C <path> status --porcelain` for Reclaim.' "the delegator's in-worktree git commands are the five Reclaim ones"
require_text 'then dispatch the bootstrap subagent as **Work** step 5 does. Never enter it' "Review never enters the worktree either"
require_text 'work only inside `<path>`' "subagents are briefed with the worktree path"
# B. Mechanical steps run in subagents under one hand-back contract.
require_text '## Hand-back contract' "the skill has a Hand-back contract section"
require_text 'returns to the delegator **at most ten lines**' "a subagent returns at most ten lines"
require_text 'It never returns a diff, a screenshot, a browser snapshot, a test log, or a report body.' "a subagent never returns its output body"
require_text 'The delegator never runs `git diff` itself' "the delegator never reads a diff"
require_text 'Write to `<scratch>/<N>/implementer.md`: (a) the list of files changed' "the implementer report goes to a file"
require_text 'its full report goes to `<scratch>/<N>/checks/<process|acceptance|whole-diff>.md`' "the three checks report to files"
require_text '   - **Process.** The project'"'"'s `tdd-guardian` agent.' "the tdd-guardian check is unchanged"
require_text 'dispatch one walkthrough subagent' "the walkthrough runs in a subagent"
require_text 'The delegator never runs `agent-browser`' "the delegator never drives the browser"
require_text 'The re-walk never runs in the main session.' "the repair-round re-walk runs in a subagent"
require_text 'Then dispatch one ship subagent' "commit, evidence, push, PR and comment run in a ship subagent"
require_text 'The ship subagent runs `git commit -F <commit message file>`; the delegator commits nothing.' "the delegator commits nothing"
require_text '11. **Evidence.** The ship subagent, in the same dispatch' "evidence is pushed by the ship subagent"
require_text 'returns at most ten lines: the PR URL, the head SHA, the evidence commit SHA or `none`' "the ship subagent returns the PR URL and evidence SHA"
require_text 'with the proposed message shown, **before** the ship subagent is dispatched' "a hand-started Work asks for commit approval before shipping"
require_text 'Push whatever is staged as a draft PR, through the ship subagent under the Hand-back contract' "Blocked ships through the subagent too"
# C. Claims bookkeeping goes to one subagent, renewed less often.
require_text '**Bookkeeping subagent.**' "claims bookkeeping has its own subagent"
require_text 'returns only comment ids and one word per item: `won`, `lost`, `live` or `lapsed`' "the claims subagent returns ids and one word"
require_text 'keeps the ids in `claims.json`' "claim ids live in claims.json"
require_text 'At the start of Work steps 6, 9 and 12' "renewal happens at steps 6, 9 and 12 only"
# D. Pick caches skips across loop passes.
require_text 'number,title,labels,createdAt,updatedAt' "Pick lists updatedAt"
require_text '`pick-cache.json`' "Pick keeps a skip cache"
require_text 'is re-read (body and comments, through `gh issue view`) **only** when its `updatedAt` in the list is later than the cached value' "a cached skip is re-read only when the issue changed"
require_text 'A cached skip is reported once per run' "a cached skip is reported once"
# E. One issue per session.
require_text '| `max_worktrees` | 1 |' "max_worktrees defaults to 1"
require_text 'Parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue; it does not come from one session working several issues.' "parallelism comes from more sessions"
require_text 'One Run pass works at most one issue through to its PR before the loop reschedules' "a Run pass works one issue"
# F. A run-level stop rule.
require_text '## Stop rule' "the skill has a Stop rule section"
require_text 'context use above 60 %, the run has made more than 150 tool calls in the main session, or the same isolation-guard refusal has occurred three times' "the stop rule names its three triggers"
require_text '`run-state.json`' "the stop counters live in run-state.json"
require_text 'A `/loop` wakeup after such a stop starts a fresh Run; it does not resume the stopped Work.' "a wakeup after a stop starts fresh"
# G. Cloud container guidance.
require_text '### Running in a cloud container' "the skill has cloud container guidance"
require_text 'only the GitHub connector attached' "the guidance names the connector cost"
require_text '`.delegator/` marker directory or `DELEGATOR_RUN=1`' "the stop hook exemption is named"
# H. Never-rules that the rewrite must keep.
require_text 'You do not write production code' "the delegator writes no production code"
require_text 'A session touches only its own claim comments.' "the claims never-rule survives"
require_text 'a command that a subagent'"'"'s own permission system refused' "no permission laundering"
require_text 'Put a model identifier in anything pushed' "no model identifier is pushed"
require_text '`git stash`, `git commit --amend` on a pushed branch, or `git branch -D`' "stash, amend and branch -D stay forbidden"
require_text 'One round only.' "one repair round only"

WALKTHROUGH="$REPO_ROOT/claude/.claude/skills/browser-ux-walkthrough/SKILL.md"
if grep -Fq -- 'A caller that must not write production code' "$WALKTHROUGH"; then
  pass "the walkthrough lets a no-code caller skip its Fix step"
else
  fail "the walkthrough lets a no-code caller skip its Fix step"
fi

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
