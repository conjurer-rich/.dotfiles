---
"@conjurer-rich/dotfiles": minor
---

delegating-github-issues: cut the token cost of delegated runs without lowering the quality bar

A review of recent delegated sessions found that about 70% of spend came from long sessions re-reading 110–175k tokens on every turn, from subagents forked with the whole conversation, from idle `/loop` passes, and from full-suite runs on trivial diffs.

- **Tiers and verification scope** come from the project's delegation file: `tier_small_max_lines`, `tier_small_max_packages`, `risk_paths`, the new `full_suite_paths`, and a **Verification scope** section, which replaces the `/pr` gate's complete-suite rule. Tier S writes no plan document and gets one self-review. The PR body records the tier and the scope it followed. The rules live in the new `references/tiers.md`.
- **Short sessions.** The Stop rule hands off at 50 % context, 80 tool calls, or once the session's one issue has a PR. It stops at once only at the old 80 % / 150 limits. A hand-off leaves a `<!-- delegator:handoff -->` PR comment with what is done, the next step, verified commands, open threads and traps; `delegate-status pr` returns it as `handoff`. Hand-off moved to `references/handoff.md`.
- **Lean subagents.** Commit, push, PR creation and the CI wait run inline, with their output in a log file. Every subagent gets a self-contained brief and is never a fork of the conversation. Mechanical steps run on `model: haiku`.
- **Cheap Watch.** `delegate-status watch-digest` compares delegated PRs and eligible issues with a baseline that the last full pass recorded. `/delegate` ends an unchanged pass before it loads the skill. The interval backs off from 10 to 60 minutes, and a full pass still runs once per `claim_ttl`.
- **Claims.** `claim` refuses with exit 4 when another session holds a live claim, without posting. A background `heartbeat` keeps a claim live, and `claim_ttl` drops to 45 minutes.
- **CI.** `checks <pr> --head <sha>` waits on that exact commit, treats no checks as pending, and with `--table` prints a pass/fail table with each failing job's annotations and the last 60 lines of its log. `checks --ref <branch>` reads the default branch.
- **Not this PR's.** A finding or red check in code the diff does not touch, which also fails on the default branch, gets one PR comment and one `follow-up` issue (`issue-create` reuses an open one). It never blocks the PR or widens it.
- **Reclaim** ignores untracked agent scratch (`AGENTS.md`, `.claude/` files) in a merged worktree.
- **Walkthroughs** follow the stack skill's *Themes* rule and print `Walkthrough: n/a — no rendered change` for diffs that render nothing.
- **Preflight.** A `preflight:` line in the delegation file lists the project's drift fixers, which the implementer runs before a PR's first push.
- **Measure.** Each delegated PR body ends with a `Delegation cost:` line (sessions, tool calls, hand-offs), written by `cost-note`. `delegate-status cost` sums it across recent merged PRs.
- The README documents the `git worktree` allow rules that unattended runs need.
