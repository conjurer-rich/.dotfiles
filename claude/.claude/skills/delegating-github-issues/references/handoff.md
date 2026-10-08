# Stop, hand-off and the cost note

Read when the **Stop rule** trips: the hand-off threshold (50 % context, 80 main-session tool calls, or a finished Work) or the hard stop (80 %, 150, or three identical isolation-guard refusals).

## Run state

The counters live in `run-state.json` in the run's scratch directory: `tool_calls` (the delegator's own calls in the main session; a subagent's calls do not count), `guard_refusals` (keyed by the refused command), `step`, `issue`, `worktree`, `worked_issue` (set once Work opens a PR or goes to **Blocked**), `item_start_calls` (the value of `tool_calls` when the current claim won, for the cost note), and the **Session title** state `title` and `ccr_session_id`. The delegator rewrites the file at the start of every numbered step and after every refusal, so a wakeup can read where the stopped run got to without replaying it. Three refusals of the same command mean the command is wrong for this environment, not that a fourth phrasing will pass.

## Stopping

1. **Checkpoint.** At the hand-off threshold, finish the current item to its next checkpoint first: Work runs on to its PR (or **Blocked**); Review, Land and Sync run on to their push, or to their stop without one. At the hard stop, stop at once, leaving staged work in the worktree.
2. **Walkthrough.** Stop any walkthrough stack the run left running.
3. **Hand-off comment.** When the run holds a PR, renew its claim and post one comment on it with `delegate-status comment <PR> --body-file <file>`:

   ```markdown
   <!-- delegator:handoff -->
   **Hand-off** from delegator session `<session>` at <entry point> step <n> (<trigger>).
   - **Done:** <what this session finished, with commit SHAs>
   - **Next:** <the one step the next session runs first>
   - **Verified:** `<command>` → <result, one line each>
   - **Open threads:** <thread or comment ids still needing an answer, or none>
   - **Traps:** <commands or paths that failed and why, so the next session does not repeat them, or none>
   <!-- delegator -->
   ```

   Without a PR (a hard stop before Work opened one), post it on the issue instead, and add the worktree path and what is staged there under **Done**. The comment needs no answer, and `delegate-status pr` returns the latest one as `handoff`: a session that claims the PR next reads it before its first step and does not re-derive what it says. It never replaces the checks: a session re-runs what its own steps require.
4. **Cost note.** For each PR the session worked, `delegate-status cost-note <PR> --tool-calls <tool_calls − item_start_calls>`, adding `--handoff` when this stop hands off. It keeps one entry per session, so writing it again replaces this session's entry.
5. **Release** every claim, with the reason `handed off` or the step reached, and stop each heartbeat.
6. **Report** the step reached, the worktree path, what is staged there and what the next session should do first.

Outside `/loop`, the run ends there. Under `/loop`, continue with **Hand-off**.

## Hand-off

A skill cannot run `/clear` or `/compact`, and a `/loop` wakeup is a new turn in the same session with the same context, so the only way a loop gets an empty context is a new session. A run under `/loop` that trips the **Stop rule** ends its loop here, handing it to a new session when it can:

1. **Check.** Hand off only when the `create_session` tool of the `claude-code-remote` MCP server is in the tool list (Claude Code on the web). A stop on isolation-guard refusals never hands off: the same environment would refuse the same command in the new session. Nor does one when this session was itself started by a hand-off and trips the context or tool-call rule before finishing one pass: a fresh context that fills in one pass would fill again, and the chain would never end. When it does not hand off, skip to step 4, set the **Session title** to `[loop ended] <title>`, and report `loop ended: <reason>; start a fresh session with /loop /delegate`. On the CLI, after a finished Work, the loop may instead keep running Watch-only passes in this session (never **Pick**) until the next threshold.
2. **Start the next session.** Call `create_session` once, counted in `tool_calls`, with `prompt` set to the exact `/loop` command this session was started with (`/loop /delegate`, or with its interval and arguments), `source_url` the main checkout's `origin` URL with no `source_revision`, `outcome_branch` the branch in `ccr-outcome-branch` (`claude/delegate-handoff` when it is empty), `title` `/delegate watching <owner>/<repo>`, and `append_system_prompt` set to `Delegator hand-off from session <ccr_session_id> after <trigger> at step <step>.` Leave `environment_id` and `model` unset, so the new session inherits both. Without `outcome_branch` the new session records no repository, and the sidebar files it under "Other" instead of with this one; the delegator never pushes to that branch, it only names the repository. A session whose system prompt carries that line was started by a hand-off. The new session starts a fresh Run, not the stopped Work. It finds the hand-off comment on the PR when it claims it. A call that fails is reported in one line and ends the loop as step 1 says.
3. **Mark this session.** Set the **Session title** to `[handed off → <id>] <title>`, so the sidebar shows that this session has stopped and which session carries the loop on.
4. **End this session's loop.** Schedule no next pass: under a self-paced `/loop`, call `ScheduleWakeup` with `stop: true`; under an interval `/loop`, delete its job with `CronDelete`. Cancel a pending `next_pass_trigger` reminder as **Watch** step 1 does, or it wakes this session after the hand-off and runs a second loop beside the new session's. Stop any background poll and heartbeat, and unsubscribe every PR in `subscribed.json`, so no event wakes this session again; the new session subscribes them afresh.
5. **Report** as **Stopping** says, plus the new session's id. Do not archive this session: in a cloud container a hard stop's staged worktree lives only in this container, and the report is where the human finds it.
