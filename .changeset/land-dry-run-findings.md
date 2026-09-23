---
"@conjurer-rich/dotfiles": patch
---

`delegating-github-issues` Land now runs its review and CI wait as background tasks, so a half-hour review no longer holds the watcher, and Watch drops its 270-second polling. Comments carrying the Claude Code footer come from another agent session and never need an answer. A human can accept bail-out findings by asking for them as follow-ups: Review files them as issues in the PR body's "Found on the way" section, and Land treats them as accepted. A bail-out on findings alone keeps verified simplifications as a pushed refactor commit instead of discarding them.
