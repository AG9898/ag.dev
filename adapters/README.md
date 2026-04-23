# Harness Adapters

Use adapters to publish `skills-core` into harness-specific skill directories.

## Suggested Targets

- Claude: `.claude/skills/<skill>/SKILL.md`
- Codex: `.agents/skills/<skill>/SKILL.md` (optionally symlink into `.codex/skills/<skill>`)

## Render Rules

1. Copy `skills-core/<skill>/SKILL.md` to target path.
2. Replace `{{CMD_PREFIX}}`:
   - Claude slash style: `/`
   - Dollar style wrapper: `$`
3. Keep `name` unchanged to preserve stable skill identity.
4. Do not alter safety guardrails during render.

## Sync Script

Use:

```bash
./scripts/sync-skills.sh --target /path/to/repo --symlink-codex
```

This will:

- render `.claude/skills/*` with `{{CMD_PREFIX}}=/`
- render `.agents/skills/*` with `{{CMD_PREFIX}}=$`
- symlink `.codex/skills/*` to `.agents/skills/*`
