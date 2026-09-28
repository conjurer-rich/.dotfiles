---
"@conjurer-rich/dotfiles": minor
---

`/delegate` with no arguments runs one **Run** pass of `delegating-github-issues`: Watch, then Pick and Work. Under `/loop /delegate` it keeps delegating until something needs the human. Work started by Run commits without asking, since the PR is the checkpoint. An over-budget pass skips Pick without commenting, and a pass never waits on a human answer.
