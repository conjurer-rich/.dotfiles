---
"@conjurer-rich/dotfiles": minor
---

`delegating-github-issues` Land no longer re-reviews the diff the human approved by marking the PR ready. Its review subagent runs `/simplify` on the diff and runs `/code-review` only on the conflict resolution, when bringing the branch up to date resolved one. The rules stay: Land applies only behaviour-preserving changes, returns any finding that needs a behaviour change (and bails out on it), treats findings under `## Found on the way, not fixed here` as accepted, and runs `tdd-guardian` only when test files changed.

**Behaviour change for every project using the plugin:** Land's `/code-review` is scoped to its own conflict resolution instead of the whole diff. The whole-diff review happens before the PR opens (Work step 7), where it already ran.
