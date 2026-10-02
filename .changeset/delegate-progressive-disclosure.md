---
"@conjurer-rich/dotfiles": minor
---

`delegating-github-issues` loads in parts. `SKILL.md` is now a core (role, parameters, delegator marker, Claims, Stop rule, an **Entry points** index, the PR body contract and the Never list), and each entry point lives in its own file under `references/`: `pick.md`, `work.md`, `review.md`, `watch.md`, `run.md`, `land.md`, `blocked-and-oracle.md`, plus `hand-back.md` and `session.md`. The index says which files each mode reads, so a Watch pass no longer loads Work's and Land's steps. The move changes no behaviour: every line of the old skill is in exactly one of the new files.
