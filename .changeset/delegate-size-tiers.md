---
"@conjurer-rich/dotfiles": minor
---

`delegating-github-issues` sizes each delegated diff into a tier before its independent checks. New parameters: `tier_small_max_lines` (default 150), `tier_small_max_packages` (default 1) and `risk_paths` (default none). The tier is measured from the implementer's staged diff (`git diff --cached --shortstat` and the packages it touches), never guessed before the work, and recorded in the PR body's Summary. A tier S diff gets one independent reviewer (`pr-reviewer`, or the `/code-review` fallback) whose brief also checks every acceptance criterion against the tests and re-measures the tier; a diff that turns out not to be S gets the other two checks before the walkthrough, without using up the repair round. Tier M and L keep `tdd-guardian`, `acceptance-review` and the whole-diff review. No tier skips independent verification, and the RED-before-GREEN evidence stays in the PR body.

**Behaviour change for every project using the plugin:** with the defaults, a diff of at most 150 changed lines in one package and off every `risk_paths` glob now skips the separate `tdd-guardian` and `acceptance-review` dispatches. Set `tier_small_max_lines` to `0` to keep the old pipeline for every issue, and set `risk_paths` to the paths that must always get all three checks.
