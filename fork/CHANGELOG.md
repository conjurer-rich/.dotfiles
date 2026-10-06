# Changelog

## 4.30.2

### Patch Changes

- 4fecc1b: delegating-github-issues: a handed-off session says so in its title, and its successor is grouped under the repository

  When **Hand-off** starts the next session, the stopped session renames itself `[handed off → <id>] <title>`, where `<id>` is the last 8 characters of the new session's id (the end of its URL). A loop that ends without a next session renames itself `[loop ended] <title>`. Both keep the last item's title after the prefix.

  `create_session` is now called with `outcome_branch` (this session's own outcome branch, kept in `ccr-outcome-branch` alongside `ccr-session-id`). Without it the new session recorded no repository and the Claude Code on the web sidebar filed it under "Other" instead of with the repository's other sessions.

## 4.30.1

### Patch Changes

- 8e68d2a: delegate-status: print `pick` and `counts` so Pick cannot report "no eligible issue" by mistake

  `delegate-status status` now prints `pick` (the issue Pick takes, as `{number, title}`, or `null`) and `counts` (issues per state). Pick reads `pick` as printed instead of filtering `issues` with its own `jq`, and a "nothing to pick" report quotes `counts`. A delegator had filtered on a key the status does not have, got an empty result, and reported no eligible issues while 36 were free.

## 4.30.0

### Minor Changes

- caee51f: `/delegate` now stops a run at 80 % context instead of 60 %. A delegator session also keeps the title of the last item it worked on after releasing its claim, instead of renaming itself `/delegate watching <owner>/<repo>` at the end of every pass, so each PR can be traced back to the session that handled it. Work renames the session to `PR #P (#N) <issue title>` once it opens the PR; only a session that has not worked an item yet uses the watching form.

## 4.29.0

### Minor Changes

- b8c208e: `/loop /delegate` no longer dies at the **Stop rule**. A `/loop` wakeup runs in the same session with the same context, so a run that stopped at 60 % context tripped the rule again on every later pass. On Claude Code on the web, a run that stops on context or tool calls now hands the loop to a new session through `create_session`, which starts with an empty context and runs the same `/loop` command, and ends its own loop. A session started by a hand-off that fills its context in its first pass, a stop on isolation-guard refusals, and a session without `create_session` end the loop and say so.

## 4.28.0

### Minor Changes

- 3c1a917: `/delegate` now syncs delegated PRs that have a merge conflict. `delegate-status` reads each delegated PR's mergeability and classes an otherwise idle conflicted PR `conflicted`; Watch runs the new **Sync** entry point on it, which merges the default branch in, resolves only the textual conflicts Land may, reviews its own resolution and pushes. A semantic conflict is aborted and reported once per head through a sync marker. `/delegate sync #<pr>` runs it by hand.

## 4.27.1

### Patch Changes

- b894581: `/delegate` reads `.claude/delegation.md` from the repository's top level instead of the session's working directory, so it finds the project's settings when the session starts in a subdirectory. In a linked worktree it reads that worktree's own copy. Outside a repository it still reports `none`.

## 4.27.0

### Minor Changes

- 5d83e3e: `/delegate` works in Claude Code on the web, where GitHub GraphQL is blocked. `delegate-status` now reads and writes GitHub through `gh api` REST endpoints only (paginated), plus the session proxy's `/ccr/` routes for review-thread resolution and returning a PR to draft; where those routes are absent (the plain CLI talking to github.com) the same two calls fall back to GraphQL, so the CLI path is unchanged. Ready detection reads the issue timeline's `ready_for_review` and `committed` events, and a bot is a REST `user.type` of `Bot`. Its output for the existing subcommands is unchanged. New subcommands carry the writes the references used to make with GraphQL-backed `gh` commands: `comment`, `reply`, `pr-create`, `pr-edit`, `to-draft`, `merge` (squash, pinned to the verified head SHA), `checks` (a bounded REST poll of check runs and commit statuses in place of `gh pr checks --watch`) and `merged-sizes`. The references, the `Never` list and the command call them instead of `gh pr`, `gh issue`, `gh label` and the thread-reply mutation.

### Patch Changes

- 5d83e3e: `delegating-github-issues`: in Claude Code on the web, the session id that `set_session_title` needs is fetched with `get_session` once per session instead of once per run. It is kept in `ccr-session-id` in the session's scratch directory, so every later `/loop /delegate` pass reuses it.
- 5d83e3e: `delegating-github-issues`: in Claude Code on the web, where the `subscribe_pr_activity` tool of the `claude-code-remote` MCP server is available, Watch subscribes each delegated PR once (Work subscribes the PR it opens) and leaves no background poll: a comment, a Ready click or a CI result wakes the session for one Watch pass. Elsewhere, the minute-by-minute background poll stays, over REST. `/delegate` pre-approves the subscribe and unsubscribe tools.
- 5d83e3e: `delegating-github-issues`: a Run pass reads `references/work.md` only once Pick returns a candidate, instead of on every pass, so a `/loop /delegate` pass that finds nothing to do, or is over budget, no longer loads Work's steps. Reclaim, which every Watch pass needs, moves out of Work step 2 into its own `references/reclaim.md`, which Work, Watch and Land point to. The Reclaim rules themselves are unchanged.

## 4.26.0

### Minor Changes

- a5ed85d: `delegating-github-issues` stops running the complete test suite locally where CI already runs it. The implementer runs lint, typecheck, build and the tests of the packages the diff touches, plus the mutation gate on the diff; the repair round runs the same checks limited to the files its fix touched; Land reruns the project's pre-push checks at that scope only when its review subagent changed files, and otherwise relies on its CI wait. A new `local_full_suite` parameter (default `off`) restores the local full-suite run, in the background and waited for, as before.

  **Behaviour change for every project using the plugin:** by default no delegated run executes the complete test suite locally any more. CI on the PR is the full-suite gate, and Land still merges only after CI passes on the verified head. Set `local_full_suite` to `on` in `.claude/delegation.md` to keep the old local run.

- a5ed85d: `delegating-github-issues` Land no longer re-reviews the diff the human approved by marking the PR ready. Its review subagent runs `/simplify` on the diff and runs `/code-review` only on the conflict resolution, when bringing the branch up to date resolved one. The rules stay: Land applies only behaviour-preserving changes, returns any finding that needs a behaviour change (and bails out on it), treats findings under `## Found on the way, not fixed here` as accepted, and runs `tdd-guardian` only when test files changed.

  **Behaviour change for every project using the plugin:** Land's `/code-review` is scoped to its own conflict resolution instead of the whole diff. The whole-diff review happens before the PR opens (Work step 7), where it already ran.

- a5ed85d: `delegating-github-issues` loads in parts. `SKILL.md` is now a core (role, parameters, delegator marker, Claims, Stop rule, an **Entry points** index, the PR body contract and the Never list), and each entry point lives in its own file under `references/`: `pick.md`, `work.md`, `review.md`, `watch.md`, `run.md`, `land.md`, `blocked-and-oracle.md`, plus `hand-back.md` and `session.md`. The index says which files each mode reads, so a Watch pass no longer loads Work's and Land's steps. The move changes no behaviour: every line of the old skill is in exactly one of the new files.
- a5ed85d: `delegating-github-issues` sizes each delegated diff into a tier before its independent checks. New parameters: `tier_small_max_lines` (default 150), `tier_small_max_packages` (default 1) and `risk_paths` (default none). The tier is measured from the implementer's staged diff (`git diff --cached --shortstat` and the packages it touches), never guessed before the work, and recorded in the PR body's Summary. A tier S diff gets one independent reviewer (`pr-reviewer`, or the `/code-review` fallback) whose brief also checks every acceptance criterion against the tests and re-measures the tier; a diff that turns out not to be S gets the other two checks before the walkthrough, without using up the repair round. Tier M and L keep `tdd-guardian`, `acceptance-review` and the whole-diff review. No tier skips independent verification, and the RED-before-GREEN evidence stays in the PR body.

  **Behaviour change for every project using the plugin:** with the defaults, a diff of at most 150 changed lines in one package and off every `risk_paths` glob now skips the separate `tdd-guardian` and `acceptance-review` dispatches. Set `tier_small_max_lines` to `0` to keep the old pipeline for every issue, and set `risk_paths` to the paths that must always get all three checks.

- a5ed85d: `delegating-github-issues` moves its fixed bookkeeping into a script, `scripts/delegate-status` (bash and jq). `status` prints, as one line of JSON, the worktrees that can be reclaimed and the ones to report, the budget counts, the eligible issues in the skill's sort order (each `free`, `held`, `claimed` with the holding session, `delegated` or `waiting-on-human`, with how its acceptance criteria stand, and any stale progress label), the delegated PRs classified Claimed, Needs review, Ready or Idle with the ids of every comment that needs an answer, and the latest Land marker. `budget`, `issue <n>` and `pr <n>` give the same answers for one step or one item; `pr` includes the bodies Review needs. `claim`, `confirm`, `renew`, `release` and `clear-label` implement the Claims protocol exactly as before: the lowest live comment id wins, a claim lapses `claim_ttl` after its `updated_at`, renewing confirms first, and release removes the label then rewrites or deletes the claim; the script refuses to touch another session's claim comment. Pick's skip cache is applied by `status --cache`. The bookkeeping subagent is gone. The claim is now renewed only right before the long steps (Work's handoff, walkthrough and repair round, Review's handoff, Land's review and CI waits), so each starts with a whole `claim_ttl`, and the next Confirm still catches a lapse before anything is written. The script is tested against recorded `gh` JSON in `test/delegate-status.sh`, and `/delegate` pre-approves it.
- a5ed85d: The browser walkthrough runs only when it can find something, and only as wide as the change. `delegating-github-issues` has a new `walkthrough_paths` parameter: globs of user-visible UI files that trigger a walkthrough, defaulting to the UI root minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**`, so a test-only diff never boots the stack. `browser-ux-walkthrough` gains a **Scope** step that maps the changed file kinds to the stack skill's Checklist sections (copy only: no tokens or motion; markup: no tokens; style or token: everything), grades both themes only when styles or tokens changed, and names the skipped sections and the theme in its output. A stack skill's own `## Checklist scope` section wins over the default mapping. The stack boots once: it stays up between grading and the repair round's re-walk and stops after the after-screenshots, or after grading when there are no findings; a run that stops early stops it first.

  **Behaviour change for every project using the plugin:** test files under the UI root no longer trigger a walkthrough, a walkthrough no longer grades every checklist item in both themes, and the repair round no longer reboots the stack.

### Patch Changes

- a5ed85d: `/delegate` recommends running the `/loop /delegate` session on a cheaper model: with the bookkeeping in `delegate-status`, it mostly routes. The implementer and Land's review subagent keep `model: opus`. The command pins no model; the choice stays with the human.

## 4.25.0

### Minor Changes

- 8858c4f: `delegating-github-issues` names the chat after the item the session holds: `#N <issue title>` once Work's claim wins, `Review PR #P <PR title>` and `Land PR #P <PR title>` for Review and Land, and `/delegate watching <owner>/<repo>` when a Run or Watch pass ends holding nothing, so several delegator sessions can be told apart in the Claude Code on the web sidebar, the `/resume` picker and the terminal title. In a cloud session the rename goes through the `set_session_title` tool; in the CLI it appends the `custom-title` record that `/rename` writes to the session transcript. A failed rename is reported in one line and never stops a run. The `/delegate` command pre-approves the calls.

## 4.24.0

### Minor Changes

- cdcb374: `delegating-github-issues` no longer exhausts the delegator's context. The delegator never enters a worktree (`EnterWorktree` is gone; the worktree is created from the main checkout and every subagent is briefed with its path), every mechanical step (bootstrap, walkthrough, commit, evidence, push, PR, issue comments, claims bookkeeping) runs in a subagent under a new **Hand-back contract** (a file plus at most ten lines back, never a diff, snapshot or log), claims renew at Work steps 6, 9 and 12 only, Pick caches skipped issues in `pick-cache.json` and re-reads one only when its `updatedAt` moved, `max_worktrees` defaults to 1 with parallelism from more sessions, and a **Stop rule** ends a run at 60 % context, 150 main-session tool calls or the third identical isolation-guard refusal. The `/delegate` command follows. New `claude/.claude/hooks/stop-hook-git-check.sh` carries the commit-and-push stop hook with an exemption for a `.delegator/` marker or `DELEGATOR_RUN=1`.

### Patch Changes

- 5173fc6: The craft plugin manifest (`claude/.claude/.claude-plugin/plugin.json`) now carries the fork's release version. Claude Code detects a marketplace plugin update from that field, and it had been pinned at 4.12.2 since the manifest was added, so installed copies were never offered newer releases. `release.yml` syncs it on every version bump through `fork/sync-plugin-version.mjs`, and a test fails when the two drift.
- 42b66d0: Fix the release workflow: changesets/action execs its `version` input without a shell, so the `pnpm changeset version && node …` chain from the manifest-sync change handed changesets a literal `&&` and every release run since failed before versioning anything. The workflow now runs `bash fork/version.sh`, which does both steps. Also register the commit-and-push stop hook (`claude/.claude/hooks/stop-hook-git-check.sh`, with its delegator exemption) as a `Stop` hook in the stowed `settings.json`.

## 4.23.0

### Minor Changes

- 9c7f6a4: `delegating-github-issues` labels an issue or PR `in-progress` (the new `progress_label` parameter) while a delegator session holds a live claim on it, so the issue list shows what an agent is working on without opening the comments. The claim comment stays the lock: the label is added when a claim wins, removed on every release, and a stale label left by a crashed session is removed by the next session that finds no live claim behind it.

## 4.22.0

### Minor Changes

- d0fa38b: Several `/loop /delegate` sessions can run at once. `delegating-github-issues` claims an issue (Work) or PR (Review, Land) with a marked comment before touching it, and other sessions skip it. The lowest live comment id wins a race; a session confirms its claim before renewing it at each step and before any push, PR creation or merge; claims lapse after `claim_ttl` (default 4 hours); every stop releases the claim. Pick also skips an issue that already has an open delegated PR.

## 4.21.0

### Minor Changes

- 9f9cf20: `/delegate` with no arguments runs one **Run** pass of `delegating-github-issues`: Watch, then Pick and Work. Under `/loop /delegate` it keeps delegating until something needs the human. Work started by Run commits without asking, since the PR is the checkpoint. An over-budget pass skips Pick without commenting, and a pass never waits on a human answer.

## 4.20.0

### Minor Changes

- 0f7e40a: `/delegate` ships as a global command. It carries no project's settings: it reads them from the project's `.claude/delegation.md`, takes owner and repo from the repository, and stops in a project without that file. Its startup lines no longer fail when `gh` is missing.

## 4.19.0

### Minor Changes

- 4bac4e3: `delegating-github-issues`: independent checks run before the PR opens. The run dispatches `tdd-guardian`, an `acceptance-review` subagent and a whole-PR review in parallel. It then allows one bounded repair round, in which the implementer refreshes its gate evidence and the failed checks run again. The walkthrough's Fix step goes to the implementer, not the delegator. Derived acceptance criteria wait for a 👍 from the authenticated login. An issue waiting on the human is never re-posted, and Pick skips it. The implementer runs the pre-PR gate in full, including its glossary step, and waits for the complete test suite, which runs as a background task.

  `browser-ux-walkthrough`: a caller that must not write production code skips the Fix step and re-walks the affected surfaces after its implementer's fix.

## 4.18.1

### Patch Changes

- ca57182: `delegating-github-issues` Land now runs its review and CI wait as background tasks, so a half-hour review no longer holds the watcher, and Watch drops its 270-second polling. Comments carrying the Claude Code footer come from another agent session and never need an answer. A human can accept bail-out findings by asking for them as follow-ups: Review files them as issues in the PR body's "Found on the way" section, and Land treats them as accepted. A bail-out on findings alone keeps verified simplifications as a pushed refactor commit instead of discarding them.

## 4.18.0

### Minor Changes

- f2236f4: `delegating-github-issues` gains **Watch** (answer review comments on delegated PRs from a `/loop`) and **Land** (review, simplify and squash-merge a PR the human marked Ready for review), behind a new `land` parameter that defaults to `off`. Delegator comments now carry a `<!-- delegator -->` marker, and Review also answers top-level PR comments.
- 6f40e52: Add `install-rich.sh`, a fork wrapper around `install-claude.sh`. It installs from this fork, layers a local CLAUDE.md over upstream's, and installs the fork's own skills (`browser-ux-walkthrough`, `delegating-github-issues`), which upstream's manifest does not name. The installer's source repository, CLAUDE.md destination and extra skill names can now be overridden from the environment through `DOTFILES_BASE_URL`, `DOTFILES_OWN_SKILLS_REPO`, `DOTFILES_CLAUDE_MD_DEST` and `DOTFILES_EXTRA_SKILLS`. Unset, the installer behaves exactly as before.

### Patch Changes

- d52d2f8: Fix the `delegating-github-issues` Ready check. `timelineItems(itemTypes: …).totalCount` ignores the filter and counts every timeline item, so every PR looked ready. Watch now reads `filteredCount`, and a PR the human never marked ready is Idle again instead of being sent to Bail-out.
- 98b8d8d: `delegating-github-issues` now reclaims worktrees whose PR was squash-merged. Reclaim used to require `git log origin/<default>..<branch>` to print nothing, which never happens after a squash merge, so Land's own `--squash` merges were never cleaned up. It now compares the local branch tip with the merged PR's `headRefOid`, and keeps the branch when `git branch -d` refuses for lack of ancestry instead of forcing `-D`.
- 3684355: `delegating-github-issues` Review now creates the PR's worktree when none exists, as Land already did. A watcher on one machine can then answer comments on a PR that another machine or a cloud session opened.
