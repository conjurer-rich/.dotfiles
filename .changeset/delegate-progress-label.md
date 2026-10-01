---
"@conjurer-rich/dotfiles": minor
---

`delegating-github-issues` labels an issue or PR `in-progress` (the new `progress_label` parameter) while a delegator session holds a live claim on it, so the issue list shows what an agent is working on without opening the comments. The claim comment stays the lock: the label is added when a claim wins, removed on every release, and a stale label left by a crashed session is removed by the next session that finds no live claim behind it.
