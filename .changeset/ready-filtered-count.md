---
"@citypaul/dotfiles": patch
---

Fix the `delegating-github-issues` Ready check. `timelineItems(itemTypes: …).totalCount` ignores the filter and counts every timeline item, so every PR looked ready. Watch now reads `filteredCount`, and a PR the human never marked ready is Idle again instead of being sent to Bail-out.
