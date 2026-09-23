---
"@citypaul/dotfiles": patch
---

`delegating-github-issues` now reclaims worktrees whose PR was squash-merged. Reclaim used to require `git log origin/<default>..<branch>` to print nothing, which never happens after a squash merge, so Land's own `--squash` merges were never cleaned up. It now compares the local branch tip with the merged PR's `headRefOid`, and keeps the branch when `git branch -d` refuses for lack of ancestry instead of forcing `-D`.
