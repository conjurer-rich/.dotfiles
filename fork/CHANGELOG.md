# Changelog

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
