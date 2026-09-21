# Rich's Development Guidelines

> This file layers on top of the upstream base at `~/.claude/base-CLAUDE.md`,
> which is installed verbatim from citypaul/.dotfiles. Keep additions here so
> upstream updates never conflict.

@~/.claude/base-CLAUDE.md

## Global preferences (Rich)

- **Visual companion: always allowed.** When the brainstorming (or any design) workflow could use the browser-based visual companion for mockups, diagrams, or layout comparisons, use it whenever it would help — do **not** prompt for consent each time. Treat consent as standing/granted.
- **Skills live globally.** `~/.claude/skills/` is the canonical location. A project vendors a skill into its own `.claude/skills/` only when that skill is genuinely project-specific; general-purpose skills are never duplicated per repo.


## Skill Routing

Every skill named below is installed in `~/.claude/skills/` and loadable. Do not add a routing sentence for a skill that is not installed.

### Process and workflow

For detailed TDD workflow, load the `tdd` skill.
For a behavior-changing planned slice, load `tdd`, `testing`, and applicable refactoring guidance before code changes begin. Use the `mutation-testing` skill's mutator rules for cheap test-design guidance, but do not run its harness until the end-of-phase PR-readiness gate. For a pure behavior-preserving refactor/reduction, load only the applicable testing, refactoring, and reduction skills during implementation, then apply mutation testing or alternate evidence at the same PR gate; load `reduce-system-complexity` when net mechanism removal is claimed, and record why any other skill is `N/A`. Do not load the full RED workflow merely to assert implementation shape.
For refactoring methodology, load the `refactoring` skill.
For removing total branches, states, dependencies, layers, flags, retries, jobs, or operational moving parts from a selected existing path while conserving behavior, load the `reduce-system-complexity` skill. Pure reductions use the verified REFACTOR path, not a fabricated structural RED test.
For reviewing whether a test suite's design actually pins behavior, load the `test-design-reviewer` skill.
For CI failure diagnosis, load the `ci-debugging` skill.
For pre-commit verification of a change set before staging, load the `pre-commit` skill.
For assessing or raising the quality bar of a change against a project's quality model, load the `quality` skill.
For standing up a new project from scratch, load the `scaffold-new-project` skill.

### Discovery, specification and planning

For fuzzy product/design decisions, load `grill-me` to pressure-test the decision tree before writing stories or plans.
For turning fuzzy intent into shared understanding and acceptance criteria — specification as a conversation, agent round first, then a real three-amigos round — load the `specification` skill.
For naming domain concepts, glossary work, or any new/changed domain term — the five-step language protocol, never silent coinage — load the `ubiquitous-language` skill.
For broad stories, epics, features, or backlog items, load `story-splitting` to create child stories before planning.
For tightening an existing story, plan, acceptance criteria set, or mock spec, load `find-gaps` to write confirmed answers back into the artifact.
For relentless decision-tree interrogation before story splitting, planning, or implementation — one question at a time, with recommended answers and codebase exploration where useful — load the `grill-me` skill.
For significant implementation work, load `planning` to turn one selected child story or narrow capability into implementation plans in `plans/`.
When one planned vertical slice may be too large for review, or later slices should start on the same evolving baseline before lower PRs merge, load `stack-pull-requests` with `planning` to choose independent PRs or an explicit hard-/flow-lineage stack without turning technical layers into stories or slices.

### Architecture

For hexagonal architecture projects, load the `hexagonal-architecture` skill.
For Domain-Driven Design projects, load the `domain-driven-design` skill.
For event-sourced systems or bounded contexts (events as the source of truth, the Decider write model, event stores, projections and read models, event versioning, snapshots), load the `event-sourcing` skill.
For 12-factor service projects, load the `twelve-factor` skill.
For production observability (wide events, OpenTelemetry, SLOs/alerting, telemetry testing), load the `observability` skill.
For CLI tool design (stream separation, format flags, exit codes, composability), load the `cli-design` skill.
For the backend-for-frontend pattern itself — whether to adopt a BFF, how many, what each may own, upstream aggregation and partial failure, and mediating user identity toward upstream services — load the `bff-design` skill.
For browser-facing BFF or backend HTTP entry points — public/protected access classification, authentication middleware, session cookies, CSRF/Origin policy, protected SSE/WebSocket registration, and endpoint-protection enforcement — load the `bff-entry-points` skill.
For designing a selected module's coherent responsibility, full caller-facing contract, information hiding, depth, leverage, and justified seams, load the `codebase-design` skill.
For finding and ranking evidence-backed architecture improvements across a repository or subsystem — with a self-contained visual HTML report — load the `improve-codebase-architecture` skill.
For designing or auditing source trees, frontend route/feature/state/design-system ownership, package boundaries, visible hexagonal layouts, feature folders, BFF route organization, composition roots, or folder migrations, load the `structure-codebase` skill.
Before introducing a material generic mechanism or durable new dependency, load `evaluate-existing-solutions` proportionately: run a lightweight local/platform preflight before bespoke generic machinery; run due diligence without reopening alternatives for a named but newly introduced dependency; use the full comparison for consequential unresolved choices. Do not turn this into a search tax for domain-specific logic, small glue, routine use of an already-adopted tool, or ordinary fixes and refactors.

### Legacy code and environments

For environment parity issues (works locally but not in production/staging, config or auth drift), load the `production-parity-skill-builder` skill.
For making untestable code testable, load the `finding-seams` skill.
For documenting existing behavior before changes, load the `characterisation-tests` skill.

### Frontend and UI

For frontend interface design, redesign, critique, polish, visual hierarchy, motion, theming, or design-system extraction, load the `impeccable` skill.
For general frontend design work within an existing design system, load the `frontend-design` skill.
For React component testing, load the `react-testing` skill; for broader browser/UI test strategy, load the `front-end-testing` skill.
For React composition and component API design (compound components, render props, context, React 19 changes), load the `vercel-composition-patterns` skill.
For React/Next.js performance patterns, load the `vercel-react-best-practices` skill.
For view transitions and route/element animation in React, load the `vercel-react-view-transitions` skill.
For multi-surface design audits before code (embed every mock in a scope on one reviewable page with flow diagram + gap cards + per-mock audit checklists), load the `storyboard` skill.

### Web quality

For a full performance/accessibility/SEO/best-practice sweep of a site, load the `web-quality-audit` skill; for a single dimension load `performance`, `accessibility`, `core-web-vitals`, `seo`, or `best-practices`.
For diagnosing search visibility, ranking loss, or technical SEO issues, load the `seo-audit` skill.

### Communication and learning

For structured learning of any topic (interactive tutoring, courses, quizzes, reviewable HTML lessons), use `/teach-me [topic]`.
For developer-facing prose — READMEs, guides, tutorials, reference docs, proposals, release notes — load the `technical-writing` skill (reader-first structure, falsifiable claims, agent-readable reference shape).
For diagrams and visual documentation (Mermaid, Graphviz, Vega-Lite, PlantUML, architecture diagrams), load the `diagrams` skill.
For detailed guidance on expectations and documentation, load the `expectations` skill.

### Meta

For discovering and installing agent skills from the open ecosystem (`npx skills`), load the `find-skills` skill.
For an independent second opinion on finished work — spinning up a *different* AI provider's CLI agent (codex/claude/gemini/cursor-agent) at its best model and effort, then arguing constructively until both agents genuinely agree — load the `double-check` skill.

**Project onboarding:** Run `/setup` in any new project to detect its tech stack and generate project-level CLAUDE.md, hooks, commands, and PR review agent in one shot. This replaces the need for `/init`.

**Project-level hooks:** Projects should add a PostToolUse hook in `.claude/settings.json` to run typecheck after Write/Edit on .ts/.tsx files. Use `/setup` to generate this automatically.


## Skill Inventory

59 skills in `~/.claude/skills/`. Sources: locally authored unless marked.

`accessibility`¹ · `agent-browser` · `api-design` · `best-practices`¹ · `bff-design` · `bff-entry-points` · `characterisation-tests` · `ci-debugging` · `cli-design` · `codebase-design` · `core-web-vitals`¹ · `diagrams` · `domain-driven-design` · `double-check` · `evaluate-existing-solutions` · `event-sourcing` · `expectations` · `find-gaps` · `find-skills` · `finding-seams` · `folder-structure`⁵ · `front-end-testing` · `frontend-design` · `functional` · `grill-me`² · `hexagonal-architecture` · `impeccable`³ · `improve-codebase-architecture` · `mutation-testing` · `observability` · `performance`¹ · `planning` · `pre-commit` · `production-parity-skill-builder` · `quality` · `react-testing` · `reduce-system-complexity` · `refactoring` · `scaffold-new-project` · `secure-oauth-oidc` · `seo`¹ · `seo-audit`⁶ · `specification` · `stack-pull-requests` · `story-splitting` · `storyboard` · `structure-codebase` · `tdd` · `teach-me` · `technical-writing` · `test-design-reviewer` · `testing` · `twelve-factor` · `typescript-strict` · `ubiquitous-language` · `vercel-composition-patterns`⁷ · `vercel-react-best-practices`⁷ · `vercel-react-view-transitions`⁷ · `web-quality-audit`¹

¹ [addyosmani/web-quality-skills](https://github.com/addyosmani/web-quality-skills) · ² [mattpocock/skills](https://skills.sh/mattpocock/skills/grill-me) · ³ [pbakaus/impeccable](https://github.com/pbakaus/impeccable) — the repo's 17 steering *commands* are not installed; `npx skills` installs skills only · ⁴ `flow-canvas-design-system` and `flow-canvas-ux-doctrine` are deliberately **not** installed here — they encode one product's doctrine and live only in the Flow Canvas repo's `.claude/skills/` · ⁵ deprecated alias for `structure-codebase`, `disable-model-invocation: true` · ⁶ [coreyhaines31/marketingskills](https://skills.sh/coreyhaines31/marketingskills/seo-audit) · ⁷ [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — note the repo is `agent-skills`, not `next-skills`

Provenance and adaptation notes for the locally authored architecture skills: `~/.claude/skills/REFERENCES.md`.


