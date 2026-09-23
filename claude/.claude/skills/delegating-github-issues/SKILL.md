---
name: delegating-github-issues
description: Take a triaged GitHub issue end-to-end to a reviewable pull request in an isolated worktree, then address review threads on request. Use when a project command such as /delegate asks to pick up an issue, work a specific issue number, or address review comments on a PR the delegator opened. Not for merging, triage, or writing production code in the calling session.
---

# Delegating GitHub issues

You are the delegator. You do not write production code. You check eligibility and budget, create the worktree, hand implementation to a subagent, verify the result, open the PR, and stop. A human reviews. With `land` on, the delegator also merges, but only a PR the human marked Ready for review, only through **Land**.

## Parameters

The calling command supplies these; defaults apply when it does not.

| Parameter | Default | Meaning |
|---|---|---|
| `label` | `agent-ready` | Only issues carrying this label are eligible |
| `rank_labels` | `p1`, `p2` | Higher rank first; unranked last |
| `max_worktrees` | 2 | Active worktrees whose branch starts with `delegated/` |
| `max_open_prs` | 6 | Open PRs in the repository, all authors |
| `branch_prefix` | `delegated/` | Branch name prefix for every delegated worktree |
| `pre_pr_gate` | the project's `/pr` command | The gate the implementer must pass before the PR opens |
| `walkthrough` | off | When on, run the `browser-ux-walkthrough` skill for diffs that touch the UI path the project names |
| `oracle` | off | When on, apply the Preview oracle rule below |
| `land` | off | When on, Work opens PRs as drafts, and **Land** may merge a PR the human marked Ready for review |

## Delegator marker

The delegator posts through the human's `gh` auth, so a comment's author cannot tell the two apart. Every comment and thread reply the delegator posts therefore ends with this line:

    <!-- delegator -->

A comment **needs an answer** when all four hold:

- it does not contain `<!-- delegator`;
- its author login does not end in `[bot]`;
- it does not contain `<!-- preview-`;
- no comment containing `<!-- delegator` follows it: in the same review thread for an inline comment, or on the PR conversation for a top-level comment.

## Entry points

### Pick

1. `gh issue list --label <label> --state open --json number,title,labels,createdAt --limit 100`.
2. Sort: issues with the first rank label, then the second, then unranked; oldest `createdAt` first within each group.
3. Take the first. Continue at **Work** with that number.
4. If the list is empty, say so and stop. Do not widen the search.

### Work `#N`

1. **Eligibility.** `gh issue view N --json labels,body,title,state -q .` The issue must be open and carry `<label>`. If not, reply in chat "Issue #N is not labelled `<label>`; add the label to make it eligible" and stop.
2. **Budget.** Reclaim finished worktrees first, then count.

   **Reclaim.** For each worktree whose branch starts with `<branch_prefix>` (`git worktree list --porcelain`), read its PR: `gh pr list --head <branch> --state all --limit 1 --json number,state`. Reclaim it only when all three hold: the PR state is `MERGED`, `git -C <path> status --porcelain` prints nothing, and `git log origin/<default branch>..<branch> --oneline` prints nothing. Reclaim means `git worktree remove <path>`, then `git branch -d <branch>` (`-d`, never `-D`: it refuses anything unmerged and is the last safety net), then `git worktree prune`. If the directory survives because another process holds it open (Windows: *"being used by another process"*; the usual culprit is a terminal parked inside it), the registration is already gone and the slot is free — delete what the platform's recursive delete will take, and name the leftover path in the run's report so the human can close whatever sits in it. Do not retry in a loop and do not kill processes to free it. Leave alone, and name in the report, any worktree whose PR is open, closed without merging, or missing, or which holds uncommitted or unpushed work.

   **Count.** Delegated worktrees: `git worktree list --porcelain | grep -c 'branch refs/heads/<branch_prefix>'`. Open PRs: `gh pr list --state open --limit 100 --json number -q 'length'`. If either count is at its limit, post this issue comment and stop:

   > Delegation paused: <k> delegated worktrees active (limit <max_worktrees>) and <m> open PRs (limit <max_open_prs>). Retry when one closes.

3. **Acceptance criteria.** Read the body. Acceptance criteria are present if the body has a heading matching `/acceptance criteria/i` followed by a numbered or bulleted list. If absent, derive 2–6 criteria from the body, each observable and testable, and post them as a comment:

   > **Acceptance criteria (derived by the delegator; edit this comment to change them)**
   > 1. …

   Use those criteria for the rest of the run.
4. **Size check.** If the criteria cannot be met by one PR of the project's usual size (read two recent merged PRs with `gh pr list --state merged --limit 2 --json additions,deletions,changedFiles` for the norm), load `story-splitting`, post the split as an issue comment, work the first child, and file each remaining child as its own issue with the `follow-up` label and no `<label>`. Say so in the PR body under **Found on the way**.
5. **Worktree.** `EnterWorktree` with a name derived from `N-<slug>`, based on `origin/<default branch>`. Rename the branch: `git branch -m <branch_prefix>N-<slug>`. Bootstrap the project the way its root CLAUDE.md says (for a pnpm monorepo: `pnpm install` then `pnpm build`). Keep the worktree until its PR merges; the **Reclaim** sub-step of the next run's budget check removes it then. Never remove a worktree whose PR has not merged.
6. **Handoff.** Dispatch one subagent with `subagent_type: general-purpose`, `model: opus`, `run_in_background: false`. The brief must contain, verbatim from the sources: the issue title and body, the acceptance criteria, the worktree absolute path, the project's root and `.claude/` CLAUDE.md pointers to skills, and these instructions:

   > Work only inside `<worktree path>`. Load the `tdd` and `testing` skills before any code change; RED before GREEN for every behaviour change. Run the project's pre-push self-check and the `<pre_pr_gate>` gate's steps 1–5 yourself, but do **not** open the PR and do **not** commit; leave the changes staged. Use `VITEST_MAX_WORKERS=2` for every test run. Never run the full test suite at the repo root. If the previous test run in this worktree was killed, run `pnpm test:db:clean` before the next one. Return: (a) the list of files changed, (b) for each acceptance criterion the test name that proves it, (c) the RED-before-GREEN evidence per the gate, (d) the mutation gate outcome or `N/A` with alternate evidence, (e) the exact commands you ran for verification and their last ten lines, (f) anything you noticed but did not fix.

   If the subagent reports it cannot make the gate pass, go to **Blocked**.
7. **Independent check.** Dispatch the project's `tdd-guardian` agent (default model) on the staged diff. If it reports a behaviour change without a preceding failing test, send the implementer subagent one message naming the gap and wait for its fix. One round only; a second failure goes to **Blocked**.
8. **Walkthrough.** If `walkthrough` is on and `git diff --cached --name-only` contains a path under the project's UI root, load `browser-ux-walkthrough` with the project's stack skill. It returns the `## UX walkthrough` section text and a list of screenshot files. If it reports the stack could not boot, file a `follow-up` issue titled `Walkthrough blocked for #N: <reason>` and use `Walkthrough blocked: <reason> (see #<follow-up>)` as the section body.
9. **Commit.** Ask the human for commit approval with the proposed message shown. On approval, `git commit -F <file>` with a conventional-commit subject that names the issue (`fix(web): … (#N)`) and the project's co-author trailer.
10. **Evidence.** If there are screenshots, push them per the project's evidence rule (for Flow Canvas: the `ux-evidence` orphan branch, path `<pr-number>/<surface>-<theme>-<before|after>.png`; the PR number is known only after step 11, so push evidence after the PR is created and then edit the body with `gh pr edit --body-file`).
11. **PR.** `git push -u origin <branch>` then `gh pr create --title "<subject>" --body-file <file>`; add `--draft` when `land` is on, so that the human's Ready-for-review click is the landing signal. The body follows the contract below. Then comment `Opened <PR URL> for this issue.` on the issue, ending with the delegator marker: `gh issue comment N --body-file <file>`.
12. **Oracle.** If `oracle` is on, wait up to 20 minutes polling every 2 minutes for the sticky comment and apply the Preview oracle rule. Otherwise say the check will run on the next `Review`.
13. Report the PR URL and stop.

### Review `#PR`

1. Confirm the PR head branch starts with `<branch_prefix>`; otherwise say this PR was not opened by a delegated run and stop.
2. Find its worktree: `git worktree list --porcelain | grep -B2 'branch refs/heads/<head branch>'`. Enter it.
3. Fetch unresolved threads and top-level comments:

   ```bash
   gh api graphql -F owner=<owner> -F repo=<repo> -F pr=<PR> -f query='
   query($owner:String!,$repo:String!,$pr:Int!){
     repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
       reviewThreads(first:50){ nodes{ id isResolved path line
         comments(first:20){ nodes{ body createdAt author{login} } } } } } } }'
   gh api repos/<owner>/<repo>/issues/<PR>/comments --paginate \
     --jq '.[] | {id, created_at, login: .user.login, body}'
   ```
   Keep unresolved threads whose last comment needs an answer, and top-level comments that need an answer (see **Delegator marker**).
4. For each thread, classify the last human comment: **actionable** (names a change, a file, or a behaviour) or **ambiguous** (a question with two readings, or a preference without a target). Post one reply on each ambiguous thread with exactly one question and stop after handling the actionable ones. Every reply ends with the delegator marker. For a top-level comment, reply with `gh pr comment <PR> --body-file <file>`, whose body starts by quoting the comment's first line (`> …`).

   ```bash
   gh api graphql -F t=<thread id> -F b="<text>" -f query='
   mutation($t:ID!,$b:String!){ addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t, body:$b}){ comment{ id } } }'
   ```
5. Hand the actionable threads to the implementer subagent (same brief shape as **Work** step 6, with the thread bodies and paths in place of the issue), then run step 7's independent check and, if `walkthrough` is on and UI files changed, step 8.
6. Commit after approval; when **Watch** started this Review, commit without asking. Push, then reply on each actionable thread or top-level comment with one sentence naming the commit and what changed, ending with the delegator marker. Do not resolve threads; the reviewer resolves.
7. Apply the Preview oracle rule if `oracle` is on. Report and stop.

### Blocked

Push whatever is staged as a draft PR: commit with subject `[blocked] <issue title> (#N)` after approval, `gh pr create --draft --title "[blocked] …" --body-file <file>` with the gate output in the **Verification** section, comment the PR URL on the issue with the one-line reason, and stop.

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
- Run the full test suite at the repository root.
- Point a browser at a deployed preview URL.
- Continue after an ambiguous review comment without the human's answer.
