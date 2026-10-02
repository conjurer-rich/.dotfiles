---
"@conjurer-rich/dotfiles": minor
---

`delegating-github-issues` stops running the complete test suite locally where CI already runs it. The implementer runs lint, typecheck, build and the tests of the packages the diff touches, plus the mutation gate on the diff; the repair round runs the same checks limited to the files its fix touched; Land reruns the project's pre-push checks at that scope only when its review subagent changed files, and otherwise relies on its CI wait. A new `local_full_suite` parameter (default `off`) restores the local full-suite run, in the background and waited for, as before.

**Behaviour change for every project using the plugin:** by default no delegated run executes the complete test suite locally any more. CI on the PR is the full-suite gate, and Land still merges only after CI passes on the verified head. Set `local_full_suite` to `on` in `.claude/delegation.md` to keep the old local run.
