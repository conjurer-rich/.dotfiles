---
"@conjurer-rich/dotfiles": patch
---

`delegating-github-issues`: a Run pass reads `references/work.md` only once Pick returns a candidate, instead of on every pass, so a `/loop /delegate` pass that finds nothing to do, or is over budget, no longer loads Work's steps. Reclaim, which every Watch pass needs, moves out of Work step 2 into its own `references/reclaim.md`, which Work, Watch and Land point to. The Reclaim rules themselves are unchanged.
