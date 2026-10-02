---
name: delegating-github-issues
description: Take a triaged GitHub issue end-to-end to a reviewable pull request in an isolated worktree, then address review comments on request. With the land parameter on, also watch delegated PRs and review, simplify and merge one the human marked Ready for review. Use when a project command such as /delegate asks to pick up an issue, work a specific issue number, address review comments on a PR the delegator opened, watch delegated PRs, land one, or run one unattended pass that watches and then picks and works the next issue (for example under `/loop /delegate`). Not for triage, merging PRs the delegator did not open, or writing production code in the calling session.
---

# Delegating GitHub issues

You are the delegator. You do not write production code, and you do no mechanical work in your own context: it runs in subagents under the **Hand-back contract**, and you read their verdicts, not their output. Your job is eligibility, budget, claims (through the claims subagent in **Claims**), reading and deriving acceptance criteria, the size check, creating the worktree, dispatching subagents, reading verdict tables, deciding deferrals, writing the PR body and commit message files, and reporting. Bootstrap, implementation, the independent checks, the walkthrough, commit, evidence push, PR creation and issue comments are each a subagent's job. You never enter a worktree. A human reviews. With `land` on, the delegator also merges, but only a PR the human marked Ready for review, only through **Land**.

A run that follows the skill literally in one context fills that context: the aborted run that shaped this version worked three issues at once, re-phrased worktree-guarded git commands dozens of times, ran browser walkthroughs inline, and read every subagent report in full. The **Stop rule** ends a run before that happens.

## Parameters

The calling command supplies these; defaults apply when it does not.

| Parameter | Default | Meaning |
|---|---|---|
| `label` | `agent-ready` | Only issues carrying this label are eligible |
| `rank_labels` | `p1`, `p2` | Higher rank first; unranked last |
| `max_worktrees` | 1 | Active worktrees whose branch starts with `delegated/`. Parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue; it does not come from one session working several issues. A project may raise this, at the cost of that session's context |
| `max_open_prs` | 6 | Open PRs in the repository, all authors |
| `branch_prefix` | `delegated/` | Branch name prefix for every delegated worktree |
| `pre_pr_gate` | the project's `/pr` command | The gate the implementer must pass before the PR opens |
| `tier_small_max_lines` | 150 | A staged diff of at most this many changed lines (insertions plus deletions) can be tier S. `0` turns tier S off |
| `tier_small_max_packages` | 1 | A staged diff touching at most this many packages can be tier S |
| `local_full_suite` | off | When on, the implementer also runs the complete test suite locally before the PR opens. Off, CI runs it on the PR and Land waits for CI |
| `risk_paths` | none | Globs. A diff touching any of them is never tier S. A project lists its migrations and its riskiest packages |
| `walkthrough` | off | When on, run the `browser-ux-walkthrough` skill for diffs with a file that matches `walkthrough_paths` |
| `walkthrough_paths` | the UI root, minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**` | Globs of user-visible UI files that trigger a walkthrough. A glob starting with `!` excludes. A project narrows it to leave out data-layer and other non-visible code under its UI root |
| `oracle` | off | When on, apply the Preview oracle rule below |
| `land` | off | When on, Work opens PRs as drafts, and **Land** may merge a PR the human marked Ready for review |
| `claim_ttl` | 4 hours | A claim not renewed for this long lapses, and another session may take the issue or PR |
| `progress_label` | `in-progress` | Carried by an issue or PR while a delegator session holds a live claim on it, so a human sees at a glance that an agent is working on it |

## Delegator marker

The delegator posts through the human's `gh` auth, so a comment's author cannot tell the two apart. Every comment and thread reply the delegator posts therefore ends with this line:

    <!-- delegator -->

Other agent sessions post through the same auth without the marker. The footer Claude Code adds (`[Claude Code](https://claude.`) identifies their posts.

A comment **needs an answer** when all five hold:

- it does not contain `<!-- delegator`;
- it does not contain the Claude Code footer: another agent posted it, not the human;
- its author login does not end in `[bot]`;
- it does not contain `<!-- preview-`;
- it has not been answered. An inline comment is answered when a comment containing `<!-- delegator` or the Claude Code footer follows it in the same review thread. A top-level comment or review body is answered when a PR comment contains `<!-- delegator reply-to: <comment id> -->` with its id; Land's own status comments answer nothing.

## Claims

Several delegator sessions can run at once, and all post through the same `gh` login, so a session claims an issue (Work) or PR (Review, Land) with a comment before it changes anything, and the others leave a claimed item alone.

The claim comment is the lock. The `<progress_label>` label is the signal for humans: a session adds it when its claim wins and removes it when it releases, so the issue list shows what an agent is working on without anyone opening the comments. The label never decides anything: a crashed session leaves its label behind, and only the live-claims query below says whether a claim is live.

**Session name.** Before its first claim, a session names itself with 8 random hex characters and uses that name for every claim it makes. The name is for claims; the chat name the human sees is the **Session title** below, and the two never mix.

**Bookkeeping subagent.** The delegator runs none of the `gh api` calls below itself: in the aborted run they were thirty-plus calls in the main context. One lightweight `general-purpose` subagent per run (model `haiku` is fine) does claim, confirm, renew and release. Its first brief carries the session name, owner/repo, `claim_ttl` in seconds, the commands in this section and the **Hand-back contract**; each later request (`SendMessage` to the same subagent, never a fresh one) carries the item number, the action and the comment id. It returns only comment ids and one word per item: `won`, `lost`, `live` or `lapsed`. The delegator keeps the ids in `claims.json` in the run's scratch directory, keyed by item number, and reads nothing else about a claim.

**Label.** Before its first claim, a session makes sure the repository has the label. `gh label list --search <progress_label> --json name --jq '.[] | select(.name == "<progress_label>") | .name'` prints nothing when it is missing; then `gh label create <progress_label> --color FBCA04 --description 'A delegator session is working on this'`. Never `--force`: an existing label keeps the colour and description the human gave it.

**Claim.** If you already hold a live claim on the item, use it. Otherwise post one and keep its id:

```bash
gh api repos/<owner>/<repo>/issues/<n>/comments -f body='Claimed by delegator session `<session>` until released, or <claim_ttl> without renewal.
<!-- delegator claim: <session> -->' --jq .id
```

Then list the live claims, the ones updated within `claim_ttl`:

```bash
gh api repos/<owner>/<repo>/issues/<n>/comments --paginate \
  --jq '.[] | select((.body | contains("<!-- delegator claim: ")) and (now - (.updated_at | fromdateiso8601) < <claim_ttl in seconds>)) | {id, updated_at, body}'
```

The live claim with the lowest comment id wins, so two sessions that claim at the same moment agree on one winner. If it is not yours, delete your own claim comment (`gh api -X DELETE repos/<owner>/<repo>/issues/comments/<id>`): another session holds the item, and a human-started entry point says `#<n> is claimed by delegator session <session>` and stops. If it is yours, add the label:

```bash
gh api -X POST repos/<owner>/<repo>/issues/<n>/labels -f 'labels[]=<progress_label>'
```

This endpoint takes issues and PRs alike, and adding a label the item already carries is a no-op.

**Confirm.** Re-run the live-claims query and check that your claim is live and still wins. If not, the item is lost: stop without writing anything more to it, and report it as lost to the named session. Staged work stays in the worktree for the human. Confirm before any push, PR creation or merge.

**Renew.** At the start of Work steps 6, 9 and 12 (before the long dispatches and before the push), Review step 6 and Land steps 4, 6 and 8, not at every numbered step, confirm the claim, then rewrite its first line to end `renewed <UTC time>` (`gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> -f body='…'`). Confirming first matters: a lapsed claim keeps its low id, and renewing it blindly would take the item back from the session that claimed it since.

**Release.** Every stop releases the claim. First remove the label (`gh api -X DELETE repos/<owner>/<repo>/issues/<n>/labels/<progress_label>`; a 404 means it was already gone). A stop that posted nothing else on the item deletes the claim comment; any other stop rewrites it as:

```text
Released by delegator session `<session>`: <the one-line reason the run stopped>.
<!-- delegator claim-released: <session> -->
```

A Land waiting on a background task has not stopped, so its claim and its label hold. A crashed or restarted session's claims lapse after `claim_ttl`; the human frees one sooner by deleting its comment. Its label does not lapse: **Stale label** below removes it. Review steps run inside Land use Land's claim.

**Stale label.** An item that carries `<progress_label>` with no live claim was left by a session that crashed or was restarted. Any session that finds one while classifying (Pick step 3, Watch step 3) removes the label, with the same command Release uses, and then treats the item as free. The label is not a claim, so this does not touch another session's claim comment.

## Stop rule

A run stops, stops any walkthrough stack it left running, releases its claims and reports when any of these holds: the harness reports context use above 60 %, the run has made more than 150 tool calls in the main session, or the same isolation-guard refusal has occurred three times. The report names the step reached, the worktree path, what is staged there and what the next session should do first. Staged work stays in the worktree. A `/loop` wakeup after such a stop starts a fresh Run; it does not resume the stopped Work.

The counters live in `run-state.json` in the run's scratch directory: `tool_calls` (the delegator's own calls in the main session; a subagent's calls do not count), `guard_refusals` (keyed by the refused command), `step`, `issue`, `worktree`, and the **Session title** state `title` and `ccr_session_id`. The delegator rewrites the file at the start of every numbered step and after every refusal, so a wakeup can read where the stopped run got to without replaying it. Three refusals of the same command mean the command is wrong for this environment, not that a fourth phrasing will pass.

## Entry points

Read only the reference files for the entry point you are running. Paths are relative to this skill's directory.

| Entry point | Read |
|---|---|
| **Pick** | `references/pick.md` |
| **Work** `#N` | `references/work.md` |
| **Review** `#PR` | `references/review.md`, and `references/work.md` for its steps 6–9 |
| **Watch** | `references/watch.md`, then the files for any Review or Land it runs |
| **Run** | `references/run.md`, `references/watch.md` and `references/pick.md`, then `references/work.md` when Pick returns an issue |
| **Land** `#PR` | `references/land.md`, and `references/review.md` when its step 3 has review to answer |
| **Blocked**, **Preview oracle rule** | `references/blocked-and-oracle.md`, when Work or Review sends you there or `oracle` is on |
| **Hand-back contract** | `references/hand-back.md`, before dispatching any subagent |
| **Session title**, **Running in a cloud container** | `references/session.md`, when the title changes |

## PR body contract

Use these eight headings, in this order, every time. A section that does not apply says why in one line; it is never omitted.

```markdown
## Summary
## Acceptance criteria
## TDD evidence
## Mutation gate
## Verification
## UX walkthrough
## Found on the way, not fixed here
## Preview E2E
```

`Summary` links the issue (`Closes #N`) and names the tier with its measurement (`Tier S: +83/−4, 1 package, no risk path`). `Acceptance criteria` lists each criterion with the test name that proves it. `TDD evidence` and `Mutation gate` carry what the implementer returned. `Verification` carries the exact commands and their last lines. `UX walkthrough` carries the walkthrough skill's output, `Walkthrough blocked: …`, or `Not applicable: no changed file matches walkthrough_paths`. `Found on the way` lists observations and any `follow-up` issues filed. `Preview E2E` carries the oracle state or `Oracle off: informational until #<oracle issue> merges`. End with the project's PR footer.

## Never

- Add `<label>` to an issue, resolve a review thread, force-push, or rebase a pushed branch.
- Merge a PR, except through **Land** with `land` on.
- Mark a PR ready for review. `gh pr ready` runs only with `--undo`; only the human marks a PR ready.
- Remove a worktree whose PR has not merged, or delete any branch other than the local `<branch_prefix>` branch of a worktree being reclaimed — and that one only with `git branch -d`.
- Kill a process to free a worktree directory; report the leftover path instead.
- Edit or delete another session's claim. A session touches only its own claim comments.
- Enter a worktree, or run any git command inside one beyond `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune` and `git -C <path> status --porcelain`.
- Read a subagent's diff, screenshot, browser snapshot, test log or report body into the main context; read its verdict table or findings list from the file instead.
- `git stash`, `git commit --amend` on a pushed branch, or `git branch -D`.
- Re-run, or hand to another agent, a command that a subagent's own permission system refused: a refusal is an answer, not an obstacle.
- Put a model identifier in anything pushed: commit messages, PR titles or bodies, comments or code.
- Work a second issue in the same session while one is in progress; run another session instead.
- Put `<progress_label>` on an item without holding a live claim on it, or leave it on one you released. The label says an agent is working on the item now, and a wrong one sends the human to look at nothing.
- Run the full test suite locally unless `local_full_suite` is on, and never at the repository root in the foreground or to check a single change.
- Point a browser at a deployed preview URL.
- Continue after an ambiguous review comment without the human's answer.
