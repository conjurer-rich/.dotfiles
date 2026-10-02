# Run

One unattended pass: **Watch**, then **Pick** and **Work**. Built to run under `/loop`, so that one command keeps delegating until it needs the human. Like Watch, it holds no state between passes beyond its session name. Nobody answers prompts during a Run, so a Run pass never waits on the human: anything that needs an answer stays on GitHub for a later pass.

1. **Watch.** Run **Watch** steps 1–4.
2. **Budget.** Count as in **Work** step 2's **Count**. If either count is at its limit, skip Pick without commenting: the paused comment would repeat on every pass. Go to step 4.
3. **Pick**, then **Work** the result, which commits without asking (**Work** step 10). One Run pass works at most one issue through to its PR before the loop reschedules; it never picks a second issue in the same pass, whatever `max_worktrees` allows. When Work stops because the issue waits on the human (a question, or criteria awaiting a 👍), the pass goes on to step 4. A later pass picks the issue up once the human answers. A pass that trips the **Stop rule** reports and ends; the next wakeup starts a fresh Run.
4. **Report** Watch step 5's lines, then one line for the issue: its number and the outcome (the PR URL, `waiting on the human`, `blocked`, `over budget`, or `no eligible issue`). The pass holds no claim now, so set the **Session title** to its watching form; a pass that stopped at **Blocked** keeps the issue's title.
5. Under `/loop`, schedule the next pass as **Watch** step 6 does. The background poll also exits when a `<label>` issue is opened or gains a comment.
