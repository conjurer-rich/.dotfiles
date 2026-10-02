---
"@conjurer-rich/dotfiles": minor
---

The browser walkthrough runs only when it can find something, and only as wide as the change. `delegating-github-issues` has a new `walkthrough_paths` parameter: globs of user-visible UI files that trigger a walkthrough, defaulting to the UI root minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**`, so a test-only diff never boots the stack. `browser-ux-walkthrough` gains a **Scope** step that maps the changed file kinds to the stack skill's Checklist sections (copy only: no tokens or motion; markup: no tokens; style or token: everything), grades both themes only when styles or tokens changed, and names the skipped sections and the theme in its output. A stack skill's own `## Checklist scope` section wins over the default mapping. The stack boots once: it stays up between grading and the repair round's re-walk and stops after the after-screenshots, or after grading when there are no findings; a run that stops early stops it first.

**Behaviour change for every project using the plugin:** test files under the UI root no longer trigger a walkthrough, a walkthrough no longer grades every checklist item in both themes, and the repair round no longer reboots the stack.
