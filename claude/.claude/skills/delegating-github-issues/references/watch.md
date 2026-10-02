# Watch

One pass over every open delegated PR, built to run under `/loop`. Watch holds no state between passes beyond its session name; everything it needs is on GitHub, so a restarted loop loses nothing but waits out its old claims.

1. **Reclaim** as in **Work** step 2.
2. `gh pr list --state open --limit 100 --json number,isDraft,headRefName,headRefOid,createdAt,labels --jq '[.[] | select(.headRefName | startswith("<branch_prefix>"))]'`.
3. Classify each PR:
   - **Claimed**: another session holds a live claim on it (**Claims**). Not touched this pass. A PR that carries `<progress_label>` with no live claim is not Claimed: remove the label as **Stale label** says, then classify it below.
   - **Needs review**: at least one review thread, top-level comment or review body needs an answer (see **Delegator marker**), and the PR is a draft or `land` is off.
   - **Ready**: `land` is on and, from this query, `isDraft` is false and `ready.filteredCount` is above 0:

     ```bash
     gh api graphql -F owner=<owner> -F repo=<repo> -F pr=<PR> -f query='
     query($owner:String!,$repo:String!,$pr:Int!){
       repository(owner:$owner,name:$repo){ pullRequest(number:$pr){ isDraft headRefOid
         ready: timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT]){ filteredCount }
         latest: timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT, PULL_REQUEST_COMMIT], last:1){ nodes{ __typename } } } } }'
     ```

     That is: the human marked it ready at least once and has not returned it to draft. A PR opened as non-draft has no ready event and is never Ready. `latest` tells Land whether a commit arrived after the last Ready.
   - **Idle**: everything else. Never touched.
4. Run **Review** on each Needs-review PR, committing without asking. Then run **Land** on each Ready PR. Work oldest `createdAt` first, one PR at a time.
5. Report one line per PR: number, state, and the action taken, `claimed by <session>`, or `idle`. Name idle non-draft PRs so the human sees them. The pass holds no claim now, so set the **Session title** to its watching form.
6. Under `/loop`, schedule the next pass 1200–1800 seconds out. Land's review and CI wait run in the background, and the background task that finishes wakes the loop, so a pass never polls to babysit them. To notice a Ready click or a new comment sooner, leave a background poll running between passes. It checks each delegated PR's draft state and unanswered comments, plus any new delegated PR, about once a minute, and exits on the first change. Comments that carry the delegator marker do not count as a change.
