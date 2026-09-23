---
"@citypaul/dotfiles": minor
---

`delegating-github-issues` gains **Watch** (answer review comments on delegated PRs from a `/loop`) and **Land** (review, simplify and squash-merge a PR the human marked Ready for review), behind a new `land` parameter that defaults to `off`. Delegator comments now carry a `<!-- delegator -->` marker, and Review also answers top-level PR comments.
