---
"@conjurer-rich/dotfiles": minor
---

`/delegate` now syncs delegated PRs that have a merge conflict. `delegate-status` reads each delegated PR's mergeability and classes an otherwise idle conflicted PR `conflicted`; Watch runs the new **Sync** entry point on it, which merges the default branch in, resolves only the textual conflicts Land may, reviews its own resolution and pushes. A semantic conflict is aborted and reported once per head through a sync marker. `/delegate sync #<pr>` runs it by hand.
