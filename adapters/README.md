# Harness Adapters

Use adapters to publish `skills-core` into harness-specific skill directories.

## Suggested Targets

- Claude: `.claude/skills/<skill>/SKILL.md`
- Codex: `.agents/skills/<skill>/SKILL.md` (optionally symlink into `.codex/skills/<skill>`)

## Placeholders

Source skills use placeholders that are substituted per harness during rendering:

| Placeholder | Claude | Codex |
|---|---|---|
| `{{CMD_PREFIX}}` | `/` | `$` |
| `{{INSTRUCTION_FILE}}` | `CLAUDE.md` | `AGENTS.md` |

## Render Rules

1. Copy `skills-core/<skill>/SKILL.md` to target path.
2. Substitute all declared placeholders (see table above).
3. Keep `name` unchanged to preserve stable skill identity.
4. Do not alter safety guardrails during render.

## Sync Scripts

| Script | Output | Use when |
|---|---|---|
| `sync-skills-claude.sh` | `.claude/skills/` | Claude-only target |
| `sync-skills-codex.sh` | `.agents/skills/`, `.codex/skills/` | Codex-only target |
| `sync-skills-all.sh` | Both | New repo setup (recommended) |

```bash
# Sync all harnesses:
./scripts/sync-skills-all.sh --target /path/to/repo

# Codex with symlinks:
./scripts/sync-skills-codex.sh --target /path/to/repo --symlink-codex

# Dry-run:
./scripts/sync-skills-all.sh --target /path/to/repo --dry-run
```

## Adding a New Placeholder

To introduce a new harness-specific substitution (e.g., `{{TOOL_PREFIX}}`):

1. Add the placeholder to source `SKILL.md` files where needed.
2. Add the sed substitution to both `sync-skills-claude.sh` and `sync-skills-codex.sh`
   in the `render_skill_file` function.
3. Update this table and the `CLAUDE.md` placeholder table.
4. Do not add harness-specific logic to `sync-skills-all.sh` — it only delegates.
