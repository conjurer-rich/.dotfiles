---
"@conjurer-rich/dotfiles": patch
---

delegate-status: print `pick` and `counts` so Pick cannot report "no eligible issue" by mistake

`delegate-status status` now prints `pick` (the issue Pick takes, as `{number, title}`, or `null`) and `counts` (issues per state). Pick reads `pick` as printed instead of filtering `issues` with its own `jq`, and a "nothing to pick" report quotes `counts`. A delegator had filtered on a key the status does not have, got an empty result, and reported no eligible issues while 36 were free.
