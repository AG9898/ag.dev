# Unified Skills Core

Canonical, harness-neutral skill definitions live here.

## Layout

- `query-workboard/SKILL.md`
- `start-task/SKILL.md`
- `ralphloop/SKILL.md`

## Adapter Contract

Adapters copy these skills into harness-specific directories and apply light rendering:

- Replace `{{CMD_PREFIX}}` with the harness command prefix (for example `/` or `$`) in usage examples.
- Keep `name` stable. Command discoverability should come from target path + harness behavior, not from rewriting skill semantics.
- Do not remove safety rules in this folder when adapting.

## Required Invariants

- Workboard source of truth is `docs/workboard.json`.
- Never dump full workboard contents into chat when a targeted query is enough.
- Never bulk-rewrite the board when a targeted task status edit is enough.
- Never use destructive cleanup (`git checkout -- .`, `git clean -fd`, reset-hard) in loop skills.

