---
description: Keep delegating under /loop (watch delegated PRs, then pick and work the next issue), or work a labelled GitHub issue to a reviewable PR, pick the next one, address review comments, watch delegated PRs, or land a PR marked ready
argument-hint: "[run] | #<issue> | next | review #<pr> | watch | land #<pr>"
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(pnpm:*), Bash(npm:*), Bash(npx:*), Bash(timeout:*), Bash(jq:*), Agent, SendMessage, mcp__claude-code-remote__get_session, mcp__claude-code-remote__set_session_title
---

Current branch:
!`git branch --show-current`

Repository:
!`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null || echo "unknown: no origin remote"`

Project delegation settings (`.claude/delegation.md`):
!`cat .claude/delegation.md 2>/dev/null || echo "none"`

## Settings

If the settings above read `none`, reply "This project has no `.claude/delegation.md`, so `/delegate` is not set up here. Add one with a **Parameters** table for the `delegating-github-issues` skill and a **Project rules** list." and stop. Never guess a project's settings.

Otherwise the settings file's **Parameters** table sets the skill's parameters; any parameter it leaves out takes the skill's default. The skill's defaults are `max_worktrees` 1, `max_open_prs` 6, `branch_prefix` `delegated/`, `claim_ttl` 4 hours, `progress_label` `in-progress`, `tier_small_max_lines` 150, `tier_small_max_packages` 1, no `risk_paths`, `walkthrough_paths` the UI root without test files, and `local_full_suite`, `walkthrough`, `oracle` and `land` off. `max_worktrees` is 1 because one session works one issue; parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue, and a project that raises it pays in that session's context. Its **Project rules** apply inside every delegated run. Owner and repo come from the **Repository** line above: strip any `https://github.com/` or `git@github.com:` prefix and `.git` suffix. A value in the settings file wins over it.

## Mode

Parse `$ARGUMENTS`:

- No arguments, or `run` → one **Run** pass: Watch, then Pick and Work. Run it as `/loop /delegate` to keep delegating until something needs the human. Several sessions can run `/loop /delegate` at once: each claims an issue or PR before touching it and labels it with the skill's `progress_label` while it holds the claim, and the others skip it. One pass works at most one issue through to its PR.
- `#<n>` or a bare number → **Work** issue `n`.
- `next` → **Pick**, then **Work** the result.
- `review #<n>` or `review <n>` → **Review** PR `n`.
- `watch` → one **Watch** pass. Run it as `/loop /delegate watch` to keep watching.
- `land #<n>` or `land <n>` → **Land** PR `n`.
- Anything else → print the six forms above and stop.

## Procedure

Load the `delegating-github-issues` skill and follow the named entry point with the parameters above.

These rules apply in every project, alongside its Project rules:

- Wait for commit approval before every commit in **Work** or **Review** started by hand. **Run**, **Watch**, the **Work**, **Review** and **Land** runs they start, and `land #<n>` commit without asking.
- **Hand-back contract** (skill): every subagent writes its report to a file and returns at most ten lines; the delegator never reads a diff, screenshot, snapshot or log, never enters a worktree, and never runs `agent-browser`.
- **Session title** (skill): the chat is named after the issue or PR the session holds (`#N <issue title>`, `Review PR #P …`, `Land PR #P …`), and `/delegate watching <owner>/<repo>` when a Run or Watch pass ends holding nothing, so the human can tell delegator sessions apart in the sidebar or the `/resume` picker. The rename never stops a run.
- **Stop rule** (skill): a run stops, releases its claims and reports where it got to at 60 % context, 150 main-session tool calls, or the third identical isolation-guard refusal; the next `/loop` pass starts fresh.
- Commit trailer `Co-Authored-By: <the model running this delegation> <noreply@anthropic.com>`. Name the model that actually did the work, not a fixed one, or the attribution is false the first time a different model runs `/delegate`. PR footer `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

The final line of the run is the PR URL, the merge SHA, the Run or Watch pass report, or the one-line reason the run stopped.
