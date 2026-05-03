# Doc Routing

Open only the docs implied by the proposal.

## Routing

- Product scope, capability, or success criteria: `docs/PRD.md`
- Runtime ownership, subsystem boundaries, auth/data flow, deployment: `docs/ARCHITECTURE.md`
- Engineering guardrails, coding patterns, and constraints: `docs/CONVENTIONS.md`
- Existing decisions, tradeoffs, or open architectural questions: `docs/DECISIONS.md`
- Environment variables and configuration behavior: `docs/ENV_VARS.md`
- Test strategy and required verification depth: `docs/TESTING.md`
- UI direction, layout, motion, visual language: `docs/styleguide.md`
- Animation guidance and GSAP usage: `docs/GSAP.md`
- Bits UI usage patterns: `docs/bits-ui.md`
- Docs map and where canonical sources live: `docs/INDEX.md`
- Workboard usage contract and edit rules: `docs/workboard.md`
- Workboard machine schema and required fields: `docs/workboard.schema.json`
- Active task queue and task metadata: `docs/workboard.json` (only when task planning or edits are requested)

## Selection Heuristics

- Start with the narrowest likely docs.
- Expand only when the proposal crosses subsystem boundaries.
- For mixed proposals, read one doc per concern instead of preloading everything.

Common combinations:

- New product feature: `docs/PRD.md` + `docs/ARCHITECTURE.md` + `docs/CONVENTIONS.md`
- Data or migration change: `docs/ARCHITECTURE.md` + `docs/DECISIONS.md` + `docs/workboard.md`
- Auth/session or env behavior change: `docs/ARCHITECTURE.md` + `docs/ENV_VARS.md` + `docs/DECISIONS.md`
- UI redesign/component behavior: `docs/styleguide.md` + `docs/bits-ui.md` + `docs/GSAP.md`
- Work planning and sequencing: `docs/workboard.md` + `docs/workboard.schema.json` + targeted `docs/workboard.json` queries
