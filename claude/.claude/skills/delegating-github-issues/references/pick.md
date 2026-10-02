# Pick

1. Run `delegate-status status --cache <scratch>/pick-cache.json`. Its `issues` are every open `<label>` issue in the skill's order: issues with the first rank label, then the second, then unranked; oldest `createdAt` first within each group. Each carries a `state`:
   - `delegated`: an open PR from a `<branch_prefix><n>-` branch exists (`pr`). Skip an issue that has an open PR from a `<branch_prefix><n>-` branch: it is already delegated.
   - `claimed`: another session holds a live claim on it (`holder`): skip an issue another session holds a live claim on.
   - `waiting-on-human`: a delegator question or derived criteria wait on the human, as **Work** step 3 defines it (`reason`). Skip it.
   - `held`: this session holds the claim.
   - `free`, with `criteria` `body`, `confirmed` or `none`.

   An issue marked `stale_label` carries `<progress_label>` but has no live claim, so it is free: remove the label as **Stale label** in **Claims** says, and keep it as a candidate.

   **Skip cache.** `--cache` keeps `pick-cache.json` in the run's scratch directory with, per skipped issue (`claimed` or `waiting-on-human`), its `updatedAt` and `checkedAt`. The script re-reads a cached issue's comments **only** when its `updatedAt` is later than the cached value, or it was `claimed` and `claim_ttl` has passed since `checkedAt`; a skip it reuses carries `cached: true`. The aborted run re-read every skipped issue's body and comments on every loop pass when nothing on them had changed.
2. Take the first issue that is not waiting on the human and that no other session has taken: the first `free` or `held` one. Continue at **Work** with it. If Work then loses the claim race for it, come back here and continue with the next candidate.
3. If the list is empty, or every issue is skipped, say so, naming the claimed ones, and stop. Do not widen the search. A cached skip is reported once per run with its reason, on the pass that first skips it, not re-explained on every pass.
