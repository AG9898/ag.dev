#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Thin wrapper: runs sync-skills-claude.sh and sync-skills-codex.sh with the same arguments.
# Flags not recognised by a sub-script are silently ignored by that script.
# Both scripts share: --target, --source, --dry-run
# Codex-only flags passed through: --no-agents, --no-codex, --symlink-codex

usage() {
  cat <<'EOF'
Usage:
  sync-skills-all.sh --target <repo-path> [options]

Options:
  --target PATH       Target repo root (required)
  --source PATH       Source skills-core path (default: <this-repo>/skills-core)
  --no-agents         Skip syncing .agents/skills  (Codex script only)
  --no-codex          Skip syncing .codex/skills   (Codex script only)
  --symlink-codex     Symlink .codex -> .agents    (Codex script only)
  --dry-run           Print planned actions only
  -h, --help          Show this help
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARGS=("$@")

HAS_TARGET=0
for arg in "${ARGS[@]}"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --target)  HAS_TARGET=1 ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]] || (( HAS_TARGET == 0 )); then
  echo "Error: --target is required." >&2
  usage >&2
  exit 1
fi

echo "=== Claude ==="
"$SCRIPT_DIR/sync-skills-claude.sh" "${ARGS[@]}"

echo
echo "=== Codex ==="
"$SCRIPT_DIR/sync-skills-codex.sh" "${ARGS[@]}"
