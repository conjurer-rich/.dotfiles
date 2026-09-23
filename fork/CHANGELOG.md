# Changelog

## 4.18.0

### Minor Changes

- f2236f4: `delegating-github-issues` gains **Watch** (answer review comments on delegated PRs from a `/loop`) and **Land** (review, simplify and squash-merge a PR the human marked Ready for review), behind a new `land` parameter that defaults to `off`. Delegator comments now carry a `<!-- delegator -->` marker, and Review also answers top-level PR comments.
- 6f40e52: Add `install-rich.sh`, a fork wrapper around `install-claude.sh`. It installs from this fork, layers a local CLAUDE.md over upstream's, and installs the fork's own skills (`browser-ux-walkthrough`, `delegating-github-issues`), which upstream's manifest does not name. The installer's source repository, CLAUDE.md destination and extra skill names can now be overridden from the environment through `DOTFILES_BASE_URL`, `DOTFILES_OWN_SKILLS_REPO`, `DOTFILES_CLAUDE_MD_DEST` and `DOTFILES_EXTRA_SKILLS`. Unset, the installer behaves exactly as before.

### Patch Changes

- d52d2f8: Fix the `delegating-github-issues` Ready check. `timelineItems(itemTypes: …).totalCount` ignores the filter and counts every timeline item, so every PR looked ready. Watch now reads `filteredCount`, and a PR the human never marked ready is Idle again instead of being sent to Bail-out.
- 98b8d8d: `delegating-github-issues` now reclaims worktrees whose PR was squash-merged. Reclaim used to require `git log origin/<default>..<branch>` to print nothing, which never happens after a squash merge, so Land's own `--squash` merges were never cleaned up. It now compares the local branch tip with the merged PR's `headRefOid`, and keeps the branch when `git branch -d` refuses for lack of ancestry instead of forcing `-D`.
- 3684355: `delegating-github-issues` Review now creates the PR's worktree when none exists, as Land already did. A watcher on one machine can then answer comments on a PR that another machine or a cloud session opened.
