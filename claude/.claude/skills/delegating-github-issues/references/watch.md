# Watch

One pass over every open delegated PR, built to run under `/loop`. Watch holds no state between passes beyond its session name; everything it needs is on GitHub, so a restarted loop loses nothing but waits out its old claims.

1. **Status.** Run `delegate-status status` (under **Run**, with Pick's `--cache`). Reclaim each `worktrees.reclaim` entry as **Work** step 2 does.
2. Its `prs` lists every open PR whose head branch starts with `<branch_prefix>`, oldest `createdAt` first.
3. Each PR carries a `class`:
   - **Claimed** (`claimed`): another session holds a live claim on it (`holder`). Not touched this pass. A PR marked `stale_label` carries `<progress_label>`, and one with no live claim is not Claimed: remove the label as **Stale label** says; its class already ignores the label.
   - **Needs review** (`needs-review`): at least one review thread, top-level comment or review body needs an answer (see **Delegator marker**; the ids are under `needs_answer`), and the PR is a draft or `land` is off.
   - **Ready** (`ready`): `land` is on, `isDraft` is false and `ready.filteredCount` is above 0 (reported as `ready`), counted over `READY_FOR_REVIEW_EVENT` timeline items only. That is: the human marked it ready at least once and has not returned it to draft. A PR opened as non-draft has no ready event and is never Ready. `latest` tells Land whether a commit arrived after the last Ready.
   - **Idle** (`idle`): everything else. Never touched.
4. Run **Review** on each Needs-review PR, committing without asking. Then run **Land** on each Ready PR. Work oldest `createdAt` first, one PR at a time.
5. Report one line per PR: number, state, and the action taken, `claimed by <session>`, or `idle`. Name idle non-draft PRs so the human sees them. The pass holds no claim now, so set the **Session title** to its watching form.
6. Under `/loop`, schedule the next pass 1200–1800 seconds out. Land's review and CI wait run in the background, and the background task that finishes wakes the loop, so a pass never polls to babysit them. To notice a Ready click or a new comment sooner, leave a background poll running between passes. It checks each delegated PR's draft state and unanswered comments, plus any new delegated PR, about once a minute, and exits on the first change. Comments that carry the delegator marker do not count as a change.
