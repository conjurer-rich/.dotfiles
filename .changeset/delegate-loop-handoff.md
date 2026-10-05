---
"@conjurer-rich/dotfiles": minor
---

`/loop /delegate` no longer dies at the **Stop rule**. A `/loop` wakeup runs in the same session with the same context, so a run that stopped at 60 % context tripped the rule again on every later pass. On Claude Code on the web, a run that stops on context or tool calls now hands the loop to a new session through `create_session`, which starts with an empty context and runs the same `/loop` command, and ends its own loop. A session started by a hand-off that fills its context in its first pass, a stop on isolation-guard refusals, and a session without `create_session` end the loop and say so.
