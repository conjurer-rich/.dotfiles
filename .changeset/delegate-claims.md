---
"@conjurer-rich/dotfiles": minor
---

Several `/loop /delegate` sessions can run at once. `delegating-github-issues` claims an issue (Work) or PR (Review, Land) with a marked comment before touching it, and other sessions skip it. The lowest live comment id wins a race; a session confirms its claim before renewing it at each step and before any push, PR creation or merge; claims lapse after `claim_ttl` (default 4 hours); every stop releases the claim. Pick also skips an issue that already has an open delegated PR.
