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
| `walkthrough` | off | When on, run the `browser-ux-walkthrough` skill for diffs that touch the UI path the project names |
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

## Hand-back contract

Every subagent writes its full report to a file under the scratchpad directory (or `<worktree>/.delegator/` when no scratchpad is available) and returns to the delegator **at most ten lines**: the file path, a one-word verdict (`pass` / `findings` / `blocked`), and a count or one-line summary. It never returns a diff, a screenshot, a browser snapshot, a test log, or a report body. The delegator reads the file only when it has to decide something and then reads only the verdict table or findings list, never the diff. The delegator never runs `git diff` itself; when it needs to know which files changed it asks the subagent for `git diff --cached --name-only` and nothing more.

The contract applies to every subagent this skill dispatches: bootstrap, implementer, the three independent checks, walkthrough, ship, claims, and the Blocked comment. Unless a step says otherwise, a dispatch is `subagent_type: general-purpose` at its default model with `run_in_background: false`.

**Scratch layout.** One directory per run, `<scratchpad>/delegator/<session name>/`: `run-state.json` (the **Stop rule** counters and the **Session title** state), `claims.json` (**Claims**), `pick-cache.json` (**Pick**), and per issue `<N>/implementer.md`, `<N>/checks/<check>.md`, `<N>/walkthrough.md`, `<N>/commit-message.md`, `<N>/pr-body.md`, `<N>/ship.md`, and screenshots at `<N>/<surface>-<theme>-<before|after>.png`. Every brief names the files it must write.

**The delegator never enters a worktree.** The delegator stays in the main checkout for the whole run. It runs no `git` command inside a worktree other than `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune` and `git -C <path> status --porcelain` for Reclaim. Every subagent that touches a worktree is briefed with the worktree's absolute path and the instruction "work only inside `<path>`". Do not use the Agent tool's `isolation: "worktree"` for these dispatches: it gives the subagent a fresh temporary worktree of its own, not the delegated one, so the implementer's staged work and the ship subagent's push would land in different places. The worktree isolation guard that refused `cd … && git`, `git -C`, heredocs naming git, loops and `agent-browser eval` in the aborted run never fires on a delegator that issues none of them.

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

## Session title

The chat's name is how the human finds one delegator session among several, in the Claude Code on the web sidebar, the `/resume` picker and the terminal title, so a session names itself after the item it holds. The title changes at these moments, and only when the new title differs from `title` in `run-state.json`:

| Moment | Title |
|---|---|
| **Work** step 2, once the claim on issue N wins | `#N <issue title>` |
| **Review** step 1, once the claim on PR P wins | `Review PR #P <PR title>` |
| **Land** step 1, once the claim on PR P wins | `Land PR #P <PR title>` |
| A **Watch** or **Run** pass ends holding no claim | `/delegate watching <owner>/<repo>` |

Cut the item's title at a word boundary with `…` so the whole stays within 60 characters. A Work, Review or Land the human started by hand keeps its item's title when it stops, and so does a run that trips the **Stop rule** or goes to **Blocked**: the title still says where the staged work is. Only a Watch or Run pass sets the watching form, and only at its end.

Set it with one call, counted in `tool_calls`, and write the new title to `run-state.json`. A rename that fails is reported in one line of the pass report and never stops a run: the title is a convenience.

- **Claude Code on the web.** The `set_session_title` tool of the `claude-code-remote` MCP server, whenever it is in the tool list. Its `session_id` is the `ccr.id` that `get_session` returns when called once per run with no arguments; keep it in `run-state.json` as `ccr_session_id`. That is the id the sidebar knows; `CLAUDE_CODE_SESSION_ID` is a different id and is not it.
- **The CLI.** No tool renames a session and a skill cannot run `/rename`. `/rename` itself appends a `custom-title` record to the session transcript, and Claude Code picks one up that another process appended the next time it reads the end of its transcript (after about 32 KB of its own writes, or at a compaction), so append the same record:

  ```bash
  jq -nc --arg t "<title>" --arg s "$CLAUDE_CODE_SESSION_ID" \
    '{type:"custom-title",customTitle:$t,sessionId:$s}' \
    >> ~/.claude/projects/*/"$CLAUDE_CODE_SESSION_ID".jsonl
  ```

  `CLAUDE_CODE_SESSION_ID` is set in every Claude Code session and exactly one transcript carries that name, so the glob expands to the one file. The redirect fails with `ambiguous redirect` when it does not; report that and carry on.

## Stop rule

A run stops, releases its claims and reports when any of these holds: the harness reports context use above 60 %, the run has made more than 150 tool calls in the main session, or the same isolation-guard refusal has occurred three times. The report names the step reached, the worktree path, what is staged there and what the next session should do first. Staged work stays in the worktree. A `/loop` wakeup after such a stop starts a fresh Run; it does not resume the stopped Work.

The counters live in `run-state.json` in the run's scratch directory: `tool_calls` (the delegator's own calls in the main session; a subagent's calls do not count), `guard_refusals` (keyed by the refused command), `step`, `issue`, `worktree`, and the **Session title** state `title` and `ccr_session_id`. The delegator rewrites the file at the start of every numbered step and after every refusal, so a wakeup can read where the stopped run got to without replaying it. Three refusals of the same command mean the command is wrong for this environment, not that a fourth phrasing will pass.

### Running in a cloud container

Advice to the human, not instructions to the delegator:

- Run `/delegate` in a dedicated environment with only the GitHub connector attached; every attached MCP server's tool list is loaded on every turn.
- Do not run it with the `learning` output style or any output style that adds per-turn commentary.
- A worktree carries a second copy of the project's `CLAUDE.md`. With the delegator staying in the main checkout, that copy no longer loads into the delegator's context on every turn, which is one more reason the delegator never enters a worktree.
- A global stop hook that nags to commit and push (the dotfiles `stop-hook-git-check.sh`) fires on every delegator stop while staged work is intentionally uncommitted. That hook stays silent when the worktree holds a `.delegator/` marker directory or `DELEGATOR_RUN=1` is set; **Work** step 5 creates the marker.

## Entry points

### Pick

1. `gh issue list --label <label> --state open --json number,title,labels,createdAt,updatedAt --limit 100`.
2. Sort: issues with the first rank label, then the second, then unranked; oldest `createdAt` first within each group.
3. Take the first issue that is not waiting on the human, as **Work** step 3 defines it, and that no other session has taken. List the open delegated PRs once (`gh pr list --state open --limit 100 --json headRefName -q '.[].headRefName'`). Skip an issue that has an open PR from a `<branch_prefix><n>-` branch: it is already delegated. Then, in sort order, skip an issue another session holds a live claim on (the live-claims query in **Claims**) and one waiting on the human. An issue that carries `<progress_label>` but has no live claim is free: remove the label as **Stale label** in **Claims** says, and keep it as a candidate. The list carries no comments, so read each candidate's with `gh issue view <n> --json body,comments`, but only when the cache below says so. Continue at **Work** with the first issue left. If Work then loses the claim race for it, come back here and continue with the next candidate.

   **Skip cache.** Pick keeps `pick-cache.json` in the run's scratch directory with, per skipped issue: `number`, `reason` (`claimed`, `waiting-on-human`, `has-open-pr` or `not-eligible`), the issue's `updatedAt` from the list, and `checkedAt`. On the next pass an issue in the cache is re-read (body and comments, through `gh issue view`) **only** when its `updatedAt` in the list is later than the cached value, or the cached reason is `claimed` and `claim_ttl` has passed since `checkedAt`. Everything else is skipped from the cache without a `gh issue view`. A fresh skip or a re-read updates the entry; an issue that is no longer skipped leaves the cache. The aborted run re-read every skipped issue's body and comments on every loop pass when nothing on them had changed.
4. If the list is empty, or every issue is skipped, say so, naming the claimed ones, and stop. Do not widen the search. A cached skip is reported once per run with its reason, on the pass that first skips it, not re-explained on every pass.

### Work `#N`

1. **Eligibility.** `gh issue view N --json labels,body,title,state -q .` The issue must be open and carry `<label>`. If not, reply in chat "Issue #N is not labelled `<label>`; add the label to make it eligible" and stop.
2. **Budget.** Reclaim finished worktrees first, then count.

   **Reclaim.** For each worktree whose branch starts with `<branch_prefix>` (`git worktree list --porcelain`), read its PR: `gh pr list --head <branch> --state all --limit 1 --json number,state,headRefOid`. Reclaim it only when all three hold: the PR state is `MERGED`, `git -C <path> status --porcelain` prints nothing, and `git rev-parse <branch>` equals the PR's `headRefOid`. Do not test `git log origin/<default branch>..<branch>`: a squash merge leaves the branch's commits off the default branch, so that test never passes. Reclaim means `git worktree remove <path>`, then `git branch -d <branch>` (`-d`, never `-D`: it refuses anything unmerged and is the last safety net), then `git worktree prune`. If `-d` refuses because the squash merge left no ancestry, keep the branch and name it in the report. If the directory survives because another process holds it open (Windows: *"being used by another process"*; the usual culprit is a terminal parked inside it), the registration is already gone and the slot is free — delete what the platform's recursive delete will take, and name the leftover path in the run's report so the human can close whatever sits in it. Do not retry in a loop and do not kill processes to free it. If another session on the same machine reclaimed the worktree first, skip it. Leave alone, and name in the report, any worktree whose PR is open, closed without merging, or missing, or which holds uncommitted or unpushed work.

   **Count.** Delegated worktrees: `git worktree list --porcelain | grep -c 'branch refs/heads/<branch_prefix>'`. Open PRs: `gh pr list --state open --limit 100 --json number -q 'length'`. If either count is at its limit, post this issue comment and stop:

   > Delegation paused: <k> delegated worktrees active (limit <max_worktrees>) and <m> open PRs (limit <max_open_prs>). Retry when one closes.

   **Claim.** Claim the issue as **Claims** describes. If another session holds it, or once claimed an open PR from a `<branch_prefix>N-` branch now exists (a session that just opened it has released its claim), stop; when Pick started this Work, return to Pick's next candidate instead. Every stop from here on releases the claim. Once the claim is yours, set the **Session title** to `#N <issue title>`.

3. **Acceptance criteria.** Read the body. Acceptance criteria are present if the body has a heading matching `/acceptance criteria/i` followed by a numbered or bulleted list. Use them for the rest of the run.

   If absent, read the issue's comments (`gh issue view N --json comments`). Only a reaction from the authenticated login (`gh api user -q .login`) counts, because anyone can react on a public repository. Read a comment's reactions with `gh api repos/<owner>/<repo>/issues/comments/<id>/reactions --jq '[.[] | select(.content == "+1") | .user.login]'`. The delegator never reacts, so that login's 👍 is the human's.
   - **Confirmed.** A derived-criteria comment (it starts with `**Acceptance criteria (derived by the delegator`) carries that login's 👍. Use its current text, including any edits, for the rest of the run.
   - **Waiting on the human.** A derived-criteria comment without that 👍, or a delegator question (it starts with `**Question before delegation**`) with no later comment from the human (one containing neither `<!-- delegator` nor the Claude Code footer). Say in chat that issue #N is waiting on the human, post nothing, and stop.

   Otherwise derive the criteria and stop. First load `find-gaps` on the issue body and every human comment, including answers to earlier questions. If the intent has two plausible readings, or the gaps leave no observable outcome, post one question as a comment that starts with `**Question before delegation**`, names the readings or gaps, and ends with the delegator marker, then stop. Otherwise derive 2–6 criteria, each observable and testable, and post them as a comment ending with the delegator marker:

   > **Acceptance criteria (derived by the delegator; edit this comment to change them, then react 👍 to confirm)**
   > 1. …

   Say in chat that issue #N awaits criteria confirmation, and stop. The run that follows the 👍 starts again at step 1.
4. **Size check.** If the criteria cannot be met by one PR of the project's usual size (read two recent merged PRs with `gh pr list --state merged --limit 2 --json additions,deletions,changedFiles` for the norm), load `story-splitting`, post the split as an issue comment, work the first child, and file each remaining child as its own issue with the `follow-up` label and no `<label>`. Say so in the PR body under **Found on the way**.
5. **Worktree.** From the main checkout, `git fetch origin <default branch>`, then `git worktree add <path> -b <branch_prefix>N-<slug> origin/<default branch>`, where `<path>` is a directory outside the main checkout, such as `../<repo>-worktrees/N-<slug>`. Stay in the main checkout: the delegator never enters the worktree (**Hand-back contract**). Create the marker directory `<path>/.delegator/` with a file `run` holding the session name, so the stop hook stays quiet while staged work waits there, and make sure `.delegator/` is listed in the main checkout's `.git/info/exclude` so it is never staged. Then dispatch a bootstrap subagent briefed with the path and the project's root CLAUDE.md bootstrap instructions (for a pnpm monorepo: `pnpm install` then `pnpm build`), under the Hand-back contract; it returns `pass`, or `blocked` with the failing command's last line, in which case go to **Blocked**. Keep the worktree until its PR merges; the **Reclaim** sub-step of the next run's budget check removes it then. Never remove a worktree whose PR has not merged.
6. **Handoff.** Dispatch one subagent with `subagent_type: general-purpose`, `model: opus`, `run_in_background: false`. The brief must contain, verbatim from the sources: the issue title and body, the acceptance criteria, the worktree absolute path, the project's root and `.claude/` CLAUDE.md pointers to skills, and these instructions:

   > Work only inside `<worktree path>`. Load the `tdd` and `testing` skills before any code change; RED before GREEN for every behaviour change. Run the project's pre-push self-check and every quality-gate step of `<pre_pr_gate>` yourself, including any glossary or vocabulary check; stop short of its PR-creation steps. Do **not** open the PR and do **not** commit; leave the changes staged. Use `VITEST_MAX_WORKERS=2` for every test run. While working, run only the affected package's or file's tests. Where the self-check or gate requires the complete test suite, run it once, at the end, as a background task. Then wait for it to exit (Monitor or a polling loop, never a fixed sleep) and read its exit code and summary; do not return before it exits. Never run it in the foreground or pipe it through `tail`. If the previous test run in this worktree was killed, run `pnpm test:db:clean` before the next one. Write to `<scratch>/<N>/implementer.md`: (a) the list of files changed, (b) for each acceptance criterion the test name that proves it, (c) the RED-before-GREEN evidence per the gate, (d) the mutation gate outcome or `N/A` with alternate evidence, (e) the exact commands you ran for verification and their last ten lines, (f) anything you noticed but did not fix. Return at most ten lines: that path, `pass` or `blocked`, and one line per acceptance criterion reading `Covered` or `not`.

   The implementer's (a) is the delegator's only list of changed files; the delegator reads it from the file and never runs `git diff`. If the subagent returns `blocked`, go to **Blocked**.
7. **Independent checks.** The implementer's returns are claims, not evidence. Dispatch these three read-only checks in parallel on the staged diff, each at its default model. None of them edits files. Each is briefed with the worktree path and the Hand-back contract: its full report goes to `<scratch>/<N>/checks/<process|acceptance|whole-diff>.md`, and it returns at most ten lines, the path, `pass` or `findings`, and the count of blocking findings. The delegator reads a file's verdict table or findings list only in step 9.
   - **Process.** The project's `tdd-guardian` agent.
   - **Acceptance.** A `general-purpose` subagent that loads `acceptance-review`. It takes the step 3 criteria as the contract and the staged diff with its tests as the evidence, and returns a verdict for each criterion. The implementer's criterion-to-test mapping goes in as a claim to check, not as the evidence.
   - **Whole diff.** The project's whole-PR review agent (`pr-reviewer` when the project defines it). Otherwise, a `general-purpose` subagent that runs `/code-review` at medium effort on the staged diff and returns its findings without applying them.
8. **Walkthrough.** If `walkthrough` is on and the implementer's (a) contains a path under the project's UI root, dispatch one walkthrough subagent (`general-purpose`, default model, `run_in_background: false`). Its brief carries the worktree path, the changed UI files, the Hand-back contract and these instructions: load `browser-ux-walkthrough` and the project's stack skill; boot the stack per the Recipe, sign in, grade the changed surfaces in both themes, and save every screenshot under `<scratch>/<N>/<surface>-<theme>-<before|after>.png`; do **not** run its Fix step: you do not write production code; stop the stack; write the grades table and every `finding` to `<scratch>/<N>/walkthrough.md`; return at most ten lines: that path, `pass` or `findings`, and the count of `finding` rows. The delegator never runs `agent-browser`: in the aborted run its snapshots were the largest item in the transcript. If the subagent returns that the stack could not boot, file a `follow-up` issue titled `Walkthrough blocked for #N: <reason>` and use `Walkthrough blocked: <reason> (see #<follow-up>)` as the section body.
9. **Repair round.** Collect every blocking finding from steps 7 and 8:
   - any `tdd-guardian` finding;
   - any criterion that `acceptance-review` does not rate `Covered` (`Partial`, `Missing`, `Regressed` and `Unverified` all block);
   - any `pr-reviewer` finding rated Critical or High Priority, or any `/code-review` correctness finding;
   - any walkthrough `finding`.

   Lesser review findings (`pr-reviewer` Suggestions, `/code-review` cleanups) go to the PR body's **Found on the way** section. If nothing blocks, skip to the last paragraph of this step.

   Otherwise send the implementer subagent one message (`SendMessage`, not a fresh dispatch) carrying every blocking finding, copied from the check files' findings lists and the walkthrough file, and wait. It fixes them, re-runs the project's pre-push self-check and the gate's test and mutation steps for the files its fix touched, and returns (a)–(f) afresh under the Hand-back contract: the fresh report overwrites `<scratch>/<N>/implementer.md`, and the return is again the path, the verdict and one line per criterion; the PR body uses those returns, not the first ones. It may propose deferring a walkthrough or whole-diff finding with a one-line reason. You decide: accept a deferral only when the finding lies outside the acceptance criteria, and file each accepted one as a `follow-up` issue. Unmet criteria and `tdd-guardian` findings cannot be deferred.

   Then re-run `tdd-guardian` and every check that reported a blocking finding, as step 7 dispatches them. If the walkthrough had findings, send the walkthrough subagent one message naming the affected surfaces; it boots and signs in per the Recipe, re-walks them in both themes for the `-after.png` shots, stops the stack, and returns the path and the count of findings left. The re-walk never runs in the main session.

   One round only. Any blocking finding that remains goes to **Blocked**, with the findings in the **Verification** section.

   On every path out of this step except **Blocked**, write the `## UX walkthrough` section from the final grades, or `Not applicable: no UI files changed` when the walkthrough did not run.
10. **Commit.** Write the commit message to `<scratch>/<N>/commit-message.md`: a conventional-commit subject that names the issue (`fix(web): … (#N)`) and the project's co-author trailer. Write the PR body to `<scratch>/<N>/pr-body.md` per the contract below. When **Run** started this Work, commit without asking: the PR is the checkpoint, and nothing merges before the human reviews it. Otherwise ask the human for commit approval with the proposed message shown, **before** the ship subagent is dispatched. Then dispatch one ship subagent (`general-purpose`, default model, `run_in_background: false`) for steps 10–12 together, briefed with the worktree path, "work only inside `<path>`", the commit message file, the PR body file, the draft flag, the evidence rule, the issue number and the Hand-back contract. The ship subagent runs `git commit -F <commit message file>`; the delegator commits nothing.
11. **Evidence.** The ship subagent, in the same dispatch: if there are screenshots under `<scratch>/<N>/`, it pushes them per the project's evidence rule (for Flow Canvas: the `ux-evidence` orphan branch, path `<pr-number>/<surface>-<theme>-<before|after>.png`; the PR number is known only after step 12, so it pushes evidence after the PR is created and then edits the body with `gh pr edit --body-file`). Its return names the evidence commit SHA, or `none`.
12. **PR.** Confirm the claim is still yours (**Claims**) before dispatching, and renew it. The ship subagent then runs `git push -u origin <branch>` (never with a force flag) then `gh pr create --title "<subject>" --body-file <file>`; add `--draft` when `land` is on, so that the human's Ready-for-review click is the landing signal. The body follows the contract below. Then it comments `Opened <PR URL> for this issue.` on the issue, ending with the delegator marker: `gh issue comment N --body-file <file>`. It writes its log to `<scratch>/<N>/ship.md` and returns at most ten lines: the PR URL, the head SHA, the evidence commit SHA or `none`, and `pass` or `blocked` with the failing command's last line. Then the delegator releases the claim, which takes `<progress_label>` off the issue: from now on the open PR marks the issue as taken.
13. **Oracle.** If `oracle` is on, wait up to 20 minutes polling every 2 minutes for the sticky comment and apply the Preview oracle rule. Otherwise say the check will run on the next `Review`.
14. Report the PR URL and stop.

### Review `#PR`

1. Confirm the PR head branch starts with `<branch_prefix>`; otherwise say this PR was not opened by a delegated run and stop. Then claim the PR (**Claims**); if another session holds it, stop. Once the claim is yours, set the **Session title** to `Review PR #P <PR title>`.
2. Find its worktree: `git worktree list --porcelain | grep -B2 'branch refs/heads/<head branch>'`. If none exists (another machine or session opened the PR), `git fetch origin <head branch>`, then `git worktree add <path> <head branch>`, then dispatch the bootstrap subagent as **Work** step 5 does. Never enter it: every later command against it runs in a subagent briefed with its path.
3. Fetch unresolved threads and top-level comments:

   ```bash
   gh api graphql -F owner=<owner> -F repo=<repo> -F pr=<PR> -f query='
   query($owner:String!,$repo:String!,$pr:Int!){
     repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
       reviewThreads(first:50){ nodes{ id isResolved path line
         comments(first:20){ nodes{ body createdAt author{login} } } } } } } }'
   gh api repos/<owner>/<repo>/issues/<PR>/comments --paginate \
     --jq '.[] | {id, created_at, login: .user.login, body}'
   gh api repos/<owner>/<repo>/pulls/<PR>/reviews --paginate \
     --jq '.[] | select(.body != "") | {id, submitted_at, login: .user.login, body}'
   ```
   Keep unresolved threads whose last comment needs an answer, and top-level comments and review bodies that need an answer (see **Delegator marker**).
4. For each thread, classify the last human comment: **actionable** (names a change, a file, or a behaviour) or **ambiguous** (a question with two readings, or a preference without a target). Post one reply on each ambiguous thread with exactly one question and stop after handling the actionable ones. Every reply ends with the delegator marker. For a top-level comment or review body, reply with `gh pr comment <PR> --body-file <file>`, whose body starts by quoting the comment's first line (`> …`) and ends with `<!-- delegator reply-to: <comment id> -->` in place of the plain marker.

   ```bash
   gh api graphql -F t=<thread id> -F b="<text>" -f query='
   mutation($t:ID!,$b:String!){ addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t, body:$b}){ comment{ id } } }'
   ```

   A comment that asks for findings as follow-ups needs no code. File each finding as its own issue with the `follow-up` label and no `<label>`, with acceptance criteria. Add each issue to the PR body's `## Found on the way, not fixed here` section (`gh pr edit <PR> --body-file <file>`), then reply naming the issues. The body is where **Land** learns which findings are accepted.
5. Hand the actionable threads to the implementer subagent (same brief shape as **Work** step 6, with the thread bodies and paths in place of the issue), then run **Work** steps 7–9. For the acceptance check, the contract is the actionable thread requests plus the PR body's acceptance criteria, which the fix must not break. Run the walkthrough only if `walkthrough` is on and UI files changed.
   When **Watch** or **Land** started this Review and the implementer cannot pass the gate, or a blocking finding survives the repair round, have the implementer subagent discard the staged changes (`git restore --staged --worktree .`), reply on each actionable thread or comment with the failure in one sentence, and stop; under Land, go to **Bail-out**. Never go to **Blocked** from **Watch** or **Land**. When the human started this Review, the PR already exists, so **Blocked** does not apply: keep the staged changes, post the remaining findings as one PR comment ending with the delegator marker, and stop.
6. Commit after approval; when **Watch** or **Land** started this Review, commit without asking. Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10's brief without PR creation: it commits from the message file and pushes with no force flag, and returns the head SHA), then reply on each actionable thread or top-level comment with one sentence naming the commit and what changed, ending with the delegator marker (the `reply-to` form for a top-level comment). Do not resolve threads; the reviewer resolves.
7. Apply the Preview oracle rule if `oracle` is on. Report and stop.

### Watch

One pass over every open delegated PR, built to run under `/loop`. Watch holds no state between passes beyond its session name; everything it needs is on GitHub, so a restarted loop loses nothing but waits out its old claims.

1. **Reclaim** as in **Work** step 2.
2. `gh pr list --state open --limit 100 --json number,isDraft,headRefName,headRefOid,createdAt,labels --jq '[.[] | select(.headRefName | startswith("<branch_prefix>"))]'`.
3. Classify each PR:
   - **Claimed**: another session holds a live claim on it (**Claims**). Not touched this pass. A PR that carries `<progress_label>` with no live claim is not Claimed: remove the label as **Stale label** says, then classify it below.
   - **Needs review**: at least one review thread, top-level comment or review body needs an answer (see **Delegator marker**), and the PR is a draft or `land` is off.
   - **Ready**: `land` is on and, from this query, `isDraft` is false and `ready.filteredCount` is above 0:

     ```bash
     gh api graphql -F owner=<owner> -F repo=<repo> -F pr=<PR> -f query='
     query($owner:String!,$repo:String!,$pr:Int!){
       repository(owner:$owner,name:$repo){ pullRequest(number:$pr){ isDraft headRefOid
         ready: timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT]){ filteredCount }
         latest: timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT, PULL_REQUEST_COMMIT], last:1){ nodes{ __typename } } } } }'
     ```

     That is: the human marked it ready at least once and has not returned it to draft. A PR opened as non-draft has no ready event and is never Ready. `latest` tells Land whether a commit arrived after the last Ready.
   - **Idle**: everything else. Never touched.
4. Run **Review** on each Needs-review PR, committing without asking. Then run **Land** on each Ready PR. Work oldest `createdAt` first, one PR at a time.
5. Report one line per PR: number, state, and the action taken, `claimed by <session>`, or `idle`. Name idle non-draft PRs so the human sees them. The pass holds no claim now, so set the **Session title** to its watching form.
6. Under `/loop`, schedule the next pass 1200–1800 seconds out. Land's review and CI wait run in the background, and the background task that finishes wakes the loop, so a pass never polls to babysit them. To notice a Ready click or a new comment sooner, leave a background poll running between passes. It checks each delegated PR's draft state and unanswered comments, plus any new delegated PR, about once a minute, and exits on the first change. Comments that carry the delegator marker do not count as a change.

### Run

One unattended pass: **Watch**, then **Pick** and **Work**. Built to run under `/loop`, so that one command keeps delegating until it needs the human. Like Watch, it holds no state between passes beyond its session name. Nobody answers prompts during a Run, so a Run pass never waits on the human: anything that needs an answer stays on GitHub for a later pass.

1. **Watch.** Run **Watch** steps 1–4.
2. **Budget.** Count as in **Work** step 2's **Count**. If either count is at its limit, skip Pick without commenting: the paused comment would repeat on every pass. Go to step 4.
3. **Pick**, then **Work** the result, which commits without asking (**Work** step 10). One Run pass works at most one issue through to its PR before the loop reschedules; it never picks a second issue in the same pass, whatever `max_worktrees` allows. When Work stops because the issue waits on the human (a question, or criteria awaiting a 👍), the pass goes on to step 4. A later pass picks the issue up once the human answers. A pass that trips the **Stop rule** reports and ends; the next wakeup starts a fresh Run.
4. **Report** Watch step 5's lines, then one line for the issue: its number and the outcome (the PR URL, `waiting on the human`, `blocked`, `over budget`, or `no eligible issue`). The pass holds no claim now, so set the **Session title** to its watching form; a pass that stopped at **Blocked** keeps the issue's title.
5. Under `/loop`, schedule the next pass as **Watch** step 6 does. The background poll also exits when a `<label>` issue is opened or gains a comment.

### Land `#PR`

Review, simplify and merge a PR the human marked Ready for review. Land may merge only what the human approved plus changes that preserve behaviour. Anything else goes to **Bail-out**.

Land can resume. Steps 1–3 always run, including on resume. The latest land marker says how far a previous Land got:

```bash
gh api repos/<owner>/<repo>/issues/<PR>/comments --paginate \
  --jq '[.[] | select(.body | contains("<!-- delegator land: reviewed ")) | .body] | last'
```

When the SHA in it equals the PR's current `headRefOid`, Land already verified this head: after step 3, go to step 7.

1. **Eligibility.** If `land` is off, say so and stop. The head branch must start with `<branch_prefix>`; if not, say so and stop. Then claim the PR (**Claims**); if another session holds it, stop. The PR must be **Ready** as **Watch** step 3 defines it; if not, say so and stop. Once the claim is yours, set the **Session title** to `Land PR #P <PR title>`. Unless the land marker names the current head, `latest` in that query must be a `ReadyForReviewEvent`. A commit after the human's last Ready was not approved, so go to **Bail-out** with the reason `commits after Ready`.
2. **Worktree.** Find or create the branch's worktree as in **Review** step 2.
3. **Open review first.** If any thread or top-level comment needs an answer, run **Review** steps 4–6, committing without asking. The human marked the PR ready with it open, so a clear request is a request to address. An ambiguous comment gets its single question and then **Bail-out** with the reason `question pending`.
4. **Bring up to date.** Dispatch one sync subagent (`general-purpose`, default model, `run_in_background: false`) briefed with the worktree path, "work only inside `<path>`", the Hand-back contract and these instructions. A review interrupted by a restart leaves staged changes: discard them first (`git restore --staged --worktree .`). Then `git fetch origin`, then `git merge --no-edit origin/<default branch>`. Resolve a conflict in place only when it is one of these textual kinds:
   - import order;
   - a migration-prefix collision (renumber to the next free prefix);
   - a generated file that the project regenerates (for Flow Canvas, `openapi.json` via `pnpm openapi:generate`);
   - lockfile churn (re-run the install);
   - edits to adjacent lines that do not overlap in what they do.

   Any other conflict is semantic: `git merge --abort`. The sync subagent returns at most ten lines: `merged`, `resolved` with the files, or `conflict` with the conflicting files, in which case **Bail-out** naming them.
5. **Review and simplify.** Dispatch one subagent with `subagent_type: general-purpose`, `model: opus`, `run_in_background: true`, with the Work step 6 brief shape, the PR title, body and diff (`git diff origin/<default branch>...HEAD`), and these instructions. A review can take half an hour. Its completion notice resumes this Land, and other PRs are free to move in the meantime.

   > Work only inside `<worktree path>`. Run `/code-review` at medium effort and `/simplify` on the diff against `origin/<default branch>`. Apply only changes that preserve behaviour; do not change any test's assertions. Do not fix anything that needs a behaviour change: return it instead. Findings listed under the PR body's `## Found on the way, not fixed here` are accepted: name them as accepted, with their issue numbers, and do not return them. Run the project's pre-push self-check. If you changed production files, run the project's mutation gate scoped to those files and revert any simplification that lowers the covered score. Do not commit; leave the changes staged. Return: (a) the files changed, (b) every finding that needs a behaviour change, with file and line, (c) the verification commands and their last ten lines, (d) the mutation outcome or `N/A` with the reason.

   If (b) is not empty, or the pre-push self-check fails, go to **Bail-out** and list the findings. If test files changed, run the project's `tdd-guardian` agent on the staged diff; any finding goes to **Bail-out**.
6. **Commit and push.** Commit without asking. Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10's brief without PR creation): step 4's merge is one commit, which git made already when there was no conflict; after a resolved conflict it commits the merge with the project's co-author trailer; it commits step 5's changes, when there are any, as `refactor: simplify after review (#PR)` with the trailer; then `git push`, with no force flag; it returns the new head SHA. Post a PR comment whose body is `Reviewed <sha> for landing.`, followed by the line `<!-- delegator land: reviewed <sha> -->` and the delegator marker, where `<sha>` is the new `headRefOid`.
7. **Wait for CI.** Run `timeout 2400 gh pr checks <PR> --watch --fail-fast` as a background task. Its exit resumes this Land; then read `gh pr checks <PR>`.
   - A failing check: **Bail-out**, naming the check and the last lines of `gh run view <run> --log-failed`.
   - Still pending when the wait times out, or the session restarted mid-wait: leave the PR as it is. The next Watch pass resumes at this step through the land marker.
   - `no checks reported`: continue only when every changed path is one the project's CI ignores (for Flow Canvas, `docs/**`, `**/*.md`, `.claude/**`); otherwise wait as for pending.
   - Preview E2E is a merge gate only when `oracle` is on, and then by the Preview oracle rule.
8. **Merge.** Check `isDraft` again (`gh pr view <PR> --json isDraft,headRefOid`) and re-read the comments as in **Review** step 3. If the PR is now a draft, its head is no longer the verified SHA, or a comment needs an answer, stop without merging. The next Watch pass picks it up. Otherwise confirm the claim is still yours and run `gh pr merge <PR> --squash --match-head-commit <verified SHA>`. If `gh pr merge` exits non-zero, go to **Bail-out** with its error output.
9. **After merge.** Reclaim this worktree at once under **Work** step 2's Reclaim rules. Comment `Merged in <merge sha> via Land.` on the PR and `Landed in <PR URL>.` on the issue, each ending with the delegator marker. Report the merge SHA and stop.

#### Bail-out

1. `gh pr ready --undo <PR>`.
2. Clean up the worktree, through the ship subagent; the delegator runs no git command in it. Before step 6, abort any in-progress merge (`git merge --abort`). A merge commit that step 4 completed stays: removing it would rewrite history. At step 7, the pushed commits stay.

   A bail-out at step 5 on findings alone should keep verified simplifications. It qualifies when the pre-push self-check passed and `tdd-guardian`, when it ran, found nothing. Commit the staged changes as `refactor: simplify after review (#PR)` with the trailer, then `git push` with no force flag. The PR is a draft by now, so this approves nothing, and the next Land does not redo the work. Otherwise discard staged and unstaged Land changes (`git restore --staged --worktree .`) and push nothing new.
3. Post one PR comment, ending with the delegator marker, containing:
   - the Land step that stopped;
   - the reason, in one sentence;
   - any findings, as a list;
   - any commits that stay pushed;
   - `Fix or answer, then mark the PR ready again.`
   - `To accept a finding instead, ask for it as a follow-up.`
4. Stop Land for this PR. The next Watch pass sees a draft. A new Ready click makes a new ready event and a new Land.

### Blocked

Push whatever is staged as a draft PR, through the ship subagent under the Hand-back contract: commit with subject `[blocked] <issue title> (#N)` after approval (without asking when **Run** started this Work), `gh pr create --draft --title "[blocked] …" --body-file <file>` with the gate output in the **Verification** section, then comment the PR URL on the issue with the one-line reason under `## Blocked`, ending with the delegator marker. The subagent returns the PR URL and the comment id, nothing more. Then stop.

## Preview oracle rule

Read the sticky: `gh api repos/<owner>/<repo>/issues/<PR>/comments --jq '.[] | select(.body | contains("<!-- preview-e2e -->")) | .body'`.

- Contains `preview-e2e: pass` → note it in the PR body's **Preview E2E** section.
- Contains `preview-e2e: network-boundary` → leave the PR alone; the auto-retry owns it.
- Contains `preview-e2e: playwright-failure` → `gh pr ready --undo <PR>`, then comment on the PR naming the failing spec from the sticky and the most likely cause from the diff.
- Sticky absent after the wait → say so and stop.

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

`Summary` links the issue (`Closes #N`). `Acceptance criteria` lists each criterion with the test name that proves it. `TDD evidence` and `Mutation gate` carry what the implementer returned. `Verification` carries the exact commands and their last lines. `UX walkthrough` carries the walkthrough skill's output, `Walkthrough blocked: …`, or `Not applicable: no UI files changed`. `Found on the way` lists observations and any `follow-up` issues filed. `Preview E2E` carries the oracle state or `Oracle off: informational until #<oracle issue> merges`. End with the project's PR footer.

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
- Run the full test suite at the repository root in the foreground, or to check a single change.
- Point a browser at a deployed preview URL.
- Continue after an ambiguous review comment without the human's answer.
