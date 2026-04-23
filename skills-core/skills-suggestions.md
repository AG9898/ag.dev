# Skill Suggestions And Research Notes

This file captures:

- What was found in current projects (`Techy`, `WW Webap`, `PigeonCoup`, `von-ralph`)
- Suggested additional reusable skills from broader agent-engineering practices
- What each suggested skill should theoretically do

## 1) Reusable Patterns Found In Current Projects

### A. `query-workboard`

What works well:

- Treats `docs/workboard.json` as canonical queue
- Uses targeted query strategy instead of unrelated context loading
- Uses dependency-aware startability rules (`depends_on`, `blocked_by`)

What to keep in shared skills:

- Strict startability checks
- Compact outputs by default
- Full task payload only on explicit request

### B. `start-task`

What works well:

- One-task-per-run discipline
- Read `docs[]` and `files[]` before implementation
- Verification + docs update + status update in one cycle

What to keep in shared skills:

- Targeted board status edits only (no bulk rewrite)
- Do not mark `done` before checks pass
- Explicit blocked handling (`in_progress -> todo` rollback when unresolved)

### C. `ralphloop`

What works well:

- Monitor/worker separation
- Threshold controls (`iterations:N`, `tasks:N`)
- Summary trailer contract for parsing outcomes

Critical tightening applied:

- No destructive cleanup (`git checkout -- .`, `git clean -fd`, reset-hard)
- Publish only when explicitly requested
- Parse summary block as contract output

### D. `von-ralph taskq` utility

What works well:

- Board abstraction across JSON/YAML/Markdown formats
- Dependency and chain queries centralized in one tool

What to keep in shared approach:

- Prefer one reusable board interface over ad-hoc per-repo jq variants

## 2) Additional Skills To Add (Industry-Informed)

### Skill: `eval-flywheel`

Why:

- Strong teams maintain a continuous loop of traces -> datasets -> eval runs -> regressions.

What it should theoretically do:

1. Collect representative traces from real runs.
2. Convert high-signal failures into eval dataset cases.
3. Run automated graders/evals on each prompt/toolchain change.
4. Produce pass/fail deltas and regression summary.
5. Block publish when critical evals regress.

Expected artifacts:

- `evals/datasets/*.jsonl`
- `evals/runs/<timestamp>.md`
- `evals/baselines/*.json`

### Skill: `tool-contract-evals`

Why:

- Agent failures often come from bad tool selection/arguments, not pure reasoning.

What it should theoretically do:

1. Define tool-call contract tests (tool choice + argument schema + argument semantics).
2. Execute controlled prompts against tool-enabled agent.
3. Compare expected vs actual tool calls.
4. Report mismatch classes (wrong tool, missing arg, invalid arg, over-calling).

Expected artifacts:

- `evals/tool_contract_cases.jsonl`
- `evals/tool_contract_report.md`

### Skill: `model-router`

Why:

- Cost/latency/performance balance usually requires task-based model routing.

What it should theoretically do:

1. Classify requests by complexity/risk.
2. Route low complexity to cheaper models.
3. Route high-risk/high-ambiguity to stronger models.
4. Emit routing decision logs for later tuning.

Expected artifacts:

- `config/model-routing.yaml`
- `logs/model-routing/*.jsonl`

### Skill: `hitl-approval-gates`

Why:

- High-trust teams add mandatory approval for irreversible or sensitive actions.

What it should theoretically do:

1. Detect gated action classes (prod writes, migrations, permission changes, destructive ops).
2. Pause execution and produce concise approval request.
3. Continue only on explicit approval token.
4. Log approver identity and decision rationale.

Expected artifacts:

- `policies/hitl-gates.yaml`
- `logs/approvals/*.jsonl`

### Skill: `durable-replay`

Why:

- Reliable agent systems need resumability and deterministic replay for debugging.

What it should theoretically do:

1. Persist run state checkpoints at step boundaries.
2. Record tool inputs/outputs with deterministic identifiers.
3. Support resume from last good checkpoint.
4. Support replay mode for failure analysis.

Expected artifacts:

- `runs/checkpoints/*`
- `runs/replay/*`

### Skill: `mcp-contract`

Why:

- Standardized connector contracts reduce per-tool integration drift.

What it should theoretically do:

1. Validate available MCP tools/resources against expected contract.
2. Smoke-test key operations.
3. Flag schema/availability drift.
4. Emit compatibility report before automation runs.

Expected artifacts:

- `contracts/mcp/*.yaml`
- `reports/mcp-compat.md`

### Skill: `agent-security-redteam`

Why:

- Prompt injection and excessive agency are common failure classes.

What it should theoretically do:

1. Run adversarial prompt suites against key flows.
2. Check policy boundaries (data exfiltration, privilege escalation, unsafe tool use).
3. Produce severity-scored findings.
4. Create mitigation tasks in workboard format.

Expected artifacts:

- `security/redteam-cases.jsonl`
- `security/findings.md`

### Skill: `release-risk-governance`

Why:

- Teams need consistent go/no-go criteria for agent workflow releases.

What it should theoretically do:

1. Aggregate eval quality, security findings, reliability metrics, and open blockers.
2. Apply release policy thresholds.
3. Emit explicit decision: `GO`, `GO_WITH_EXCEPTIONS`, or `NO_GO`.
4. Generate required follow-up tasks for exceptions.

Expected artifacts:

- `release/risk-scorecard.md`
- `release/decision-<date>.md`

## 3) Suggested Adoption Order

1. `eval-flywheel`
2. `tool-contract-evals`
3. `hitl-approval-gates`
4. `agent-security-redteam`
5. `model-router`
6. `durable-replay`
7. `mcp-contract`
8. `release-risk-governance`

## 4) Source References (initial research)

- Anthropic: Building Effective AI Agents
  - https://www.anthropic.com/engineering/building-effective-agents
- OpenAI: A practical guide to building agents
  - https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI: Evaluate agent workflows
  - https://developers.openai.com/api/docs/guides/agent-evals
- OpenAI: Evaluation best practices
  - https://developers.openai.com/api/docs/guides/evaluation-best-practices
- Model Context Protocol Specification
  - https://modelcontextprotocol.io/specification/2025-11-25/basic
- LangGraph: durable execution
  - https://docs.langchain.com/oss/python/langgraph/durable-execution
- LangGraph: interrupts / human-in-the-loop
  - https://docs.langchain.com/oss/python/langgraph/interrupts
- OWASP Top 10 for LLM Applications
  - https://owasp.org/www-project-top-10-for-large-language-model-applications/
- NIST AI RMF GenAI Profile
  - https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-generative-artificial-intelligence

