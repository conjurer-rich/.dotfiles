# Review `#PR`

1. Confirm the PR head branch starts with `<branch_prefix>`; otherwise say this PR was not opened by a delegated run and stop. Then claim the PR (**Claims**); if another session holds it, stop. Once the claim is yours, set the **Session title** to `Review PR #P <PR title>`.
2. Find its worktree: `git worktree list --porcelain | grep -B2 'branch refs/heads/<head branch>'`. If none exists (another machine or session opened the PR), `git fetch origin <head branch>`, then `git worktree add <path> <head branch>`, then dispatch the bootstrap subagent as **Work** step 5 does. Never enter it: every later command against it runs in a subagent briefed with its path.
3. Fetch unresolved threads and top-level comments:

   ```bash
   gh api graphql -F owner=<owner> -F repo=<repo> -F pr=<PR> -f query='
   query($owner:String!,$repo:String!,$pr:Int!){
     repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
       reviewThreads(first:50){ nodes{ id isResolved path line
         comments(first:20){ nodes{ body createdAt author{login} } } } } } } }'
   gh api repos/<owner>/<repo>/issues/<PR>/comments --paginate \
     --jq '.[] | {id, created_at, login: .user.login, body}'
   gh api repos/<owner>/<repo>/pulls/<PR>/reviews --paginate \
     --jq '.[] | select(.body != "") | {id, submitted_at, login: .user.login, body}'
   ```
   Keep unresolved threads whose last comment needs an answer, and top-level comments and review bodies that need an answer (see **Delegator marker**).
4. For each thread, classify the last human comment: **actionable** (names a change, a file, or a behaviour) or **ambiguous** (a question with two readings, or a preference without a target). Post one reply on each ambiguous thread with exactly one question and stop after handling the actionable ones. Every reply ends with the delegator marker. For a top-level comment or review body, reply with `gh pr comment <PR> --body-file <file>`, whose body starts by quoting the comment's first line (`> …`) and ends with `<!-- delegator reply-to: <comment id> -->` in place of the plain marker.

   ```bash
   gh api graphql -F t=<thread id> -F b="<text>" -f query='
   mutation($t:ID!,$b:String!){ addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t, body:$b}){ comment{ id } } }'
   ```

   A comment that asks for findings as follow-ups needs no code. File each finding as its own issue with the `follow-up` label and no `<label>`, with acceptance criteria. Add each issue to the PR body's `## Found on the way, not fixed here` section (`gh pr edit <PR> --body-file <file>`), then reply naming the issues. The body is where **Land** learns which findings are accepted.
5. Hand the actionable threads to the implementer subagent (same brief shape as **Work** step 6, with the thread bodies and paths in place of the issue), then run **Work** steps 7–9, with the tier measured from this staged diff. For the acceptance check, the contract is the actionable thread requests plus the PR body's acceptance criteria, which the fix must not break. Run the walkthrough only if `walkthrough` is on and a changed file matches `walkthrough_paths`.
   When **Watch** or **Land** started this Review and the implementer cannot pass the gate, or a blocking finding survives the repair round, have the implementer subagent discard the staged changes (`git restore --staged --worktree .`), reply on each actionable thread or comment with the failure in one sentence, and stop; under Land, go to **Bail-out**. Never go to **Blocked** from **Watch** or **Land**. When the human started this Review, the PR already exists, so **Blocked** does not apply: keep the staged changes, post the remaining findings as one PR comment ending with the delegator marker, and stop.
6. Commit after approval; when **Watch** or **Land** started this Review, commit without asking. Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10's brief without PR creation: it commits from the message file and pushes with no force flag, and returns the head SHA), then reply on each actionable thread or top-level comment with one sentence naming the commit and what changed, ending with the delegator marker (the `reply-to` form for a top-level comment). Do not resolve threads; the reviewer resolves.
7. Apply the Preview oracle rule if `oracle` is on. Report and stop.
