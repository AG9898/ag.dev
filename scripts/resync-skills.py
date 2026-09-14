#!/usr/bin/env python3
"""Safely re-sync opted-in core skills to multiple local repositories.

The registry and state file are machine-local by default. State records the source
and rendered target hashes from the last successful sync, so a target-side edit is
reported as customized or conflicting instead of being overwritten.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


OUTPUTS = {
    "claude": {
        "directory": ".claude/skills",
        "replacements": {
            "{{CMD_PREFIX}}": "/",
            "{{INSTRUCTION_FILE}}": "CLAUDE.md",
            "{{USER_INPUT_TOOL}}": "AskUserQuestion",
        },
    },
    "agents": {
        "directory": ".agents/skills",
        "replacements": {
            "{{CMD_PREFIX}}": "$",
            "{{INSTRUCTION_FILE}}": "AGENTS.md",
            "{{USER_INPUT_TOOL}}": "request_user_input",
        },
    },
    "codex": {
        "directory": ".codex/skills",
        "replacements": {
            "{{CMD_PREFIX}}": "$",
            "{{INSTRUCTION_FILE}}": "AGENTS.md",
            "{{USER_INPUT_TOOL}}": "request_user_input",
        },
    },
}
STATE_VERSION = 1


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ValueError(f"{label} does not exist: {path}") from None
    except json.JSONDecodeError as error:
        raise ValueError(f"{label} is not valid JSON: {path}: {error}") from None
    if not isinstance(value, dict):
        raise ValueError(f"{label} must contain a JSON object: {path}")
    return value


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": STATE_VERSION, "targets": {}}
    state = load_json(path, "state file")
    if state.get("version") != STATE_VERSION or not isinstance(state.get("targets"), dict):
        raise ValueError(f"unsupported state file shape: {path}")
    return state


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.replace(path)


def source_skills(source_root: Path) -> dict[str, Path]:
    if not source_root.is_dir():
        raise ValueError(f"source skills directory does not exist: {source_root}")
    result = {
        path.name: path
        for path in source_root.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    }
    if not result:
        raise ValueError(f"no skills found under source directory: {source_root}")
    return result


def rendered_bytes(source: Path, relative_path: Path, output: str) -> bytes:
    data = source.read_bytes()
    if relative_path.as_posix() != "SKILL.md":
        return data
    text = data.decode("utf-8")
    for placeholder, replacement in OUTPUTS[output]["replacements"].items():
        text = text.replace(placeholder, replacement)
    return text.encode("utf-8")


def source_files(skill_dir: Path) -> list[tuple[Path, Path]]:
    return [
        (path, path.relative_to(skill_dir))
        for path in sorted(skill_dir.rglob("*"))
        if path.is_file()
    ]


def target_dirty(target: Path) -> bool | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(target), "status", "--porcelain"],
            check=False,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    return bool(result.stdout.strip())


def configured_skills(target: dict[str, Any], available: dict[str, Path], requested: set[str]) -> list[str]:
    raw_skills = target.get("skills")
    if not isinstance(raw_skills, list) or not raw_skills or not all(isinstance(item, str) for item in raw_skills):
        raise ValueError("each target requires a non-empty string array: skills")
    names = set(available) if "*" in raw_skills else set(raw_skills)
    unknown = names - set(available)
    if unknown:
        raise ValueError(f"target requests skills absent from source: {', '.join(sorted(unknown))}")
    if requested:
        names &= requested
    return sorted(names)


def target_path(config_path: Path, value: Any) -> Path:
    if not isinstance(value, str) or not value:
        raise ValueError("each target requires a non-empty path")
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = config_path.parent / path
    return path.resolve()


def state_files(state: dict[str, Any], target: Path, output: str, skill: str) -> dict[str, Any]:
    targets = state.setdefault("targets", {})
    target_state = targets.setdefault(str(target), {"outputs": {}})
    outputs = target_state.setdefault("outputs", {})
    output_state = outputs.setdefault(output, {"skills": {}})
    skill_state = output_state.setdefault("skills", {}).setdefault(skill, {"files": {}})
    return skill_state.setdefault("files", {})


def classify(
    baseline: dict[str, Any] | None,
    source_hash: str,
    expected_hash: str,
    destination: Path,
    known_skill: bool,
    allow_new_skills: bool,
) -> tuple[str, str | None]:
    if not destination.exists():
        if baseline:
            return "target_missing", None
        if known_skill or allow_new_skills:
            return "safe_new", None
        return "new_skill_not_allowed", None

    actual = sha256(destination.read_bytes())
    if baseline is None:
        if actual == expected_hash:
            return "adoptable", actual
        return "unmanaged", actual

    baseline_source = baseline.get("source_sha256")
    baseline_target = baseline.get("target_sha256")
    mode = baseline.get("mode")
    if not isinstance(baseline_source, str) or not isinstance(baseline_target, str) or mode not in {"managed", "custom"}:
        return "unmanaged", actual

    source_changed = source_hash != baseline_source
    target_changed = actual != baseline_target
    if mode == "custom":
        return ("customized" if not source_changed else "conflict"), actual
    if not source_changed and not target_changed:
        return "up_to_date", actual
    if source_changed and not target_changed:
        return "safe_update", actual
    if not source_changed and target_changed:
        return "customized", actual
    return "conflict", actual


def atomic_write(destination: Path, data: bytes, mode: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", dir=destination.parent, delete=False) as handle:
        handle.write(data)
        temporary = Path(handle.name)
    os.chmod(temporary, mode)
    temporary.replace(destination)


def render_report(report: dict[str, Any], json_output: bool) -> None:
    if json_output:
        print(json.dumps(report, indent=2, sort_keys=True))
        return
    print(f"Source: {report['source']}")
    print(f"Mode: {report['mode']}")
    for target in report["targets"]:
        print(f"\n{target['name']} ({target['path']})")
        if target["dirty"] is True:
            print("  worktree: dirty (writes skipped unless --allow-dirty)")
        elif target["dirty"] is None:
            print("  worktree: not a Git repository or Git unavailable")
        counts = Counter(item["status"] for item in target["files"])
        print("  " + ", ".join(f"{status}={count}" for status, count in sorted(counts.items())))
        for item in target["files"]:
            if item["status"] not in {"up_to_date", "adoptable"}:
                print(f"  {item['status']}: {item['output']}/{item['skill']}/{item['file']}")
    totals = Counter(item["status"] for target in report["targets"] for item in target["files"])
    print("\nTotal: " + ", ".join(f"{status}={count}" for status, count in sorted(totals.items())))


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=repo_root / "config/skill-targets.local.json", type=Path, help="machine-local target registry")
    parser.add_argument("--state", default=repo_root / "config/skill-sync-state.local.json", type=Path, help="machine-local sync state")
    parser.add_argument("--source", default=repo_root / "skills-core", type=Path, help="canonical skill source directory")
    parser.add_argument("--target", action="append", default=[], help="target name to include (repeatable)")
    parser.add_argument("--skill", action="append", default=[], help="skill name to include (repeatable)")
    parser.add_argument("--apply", action="store_true", help="write only safe updates and record their baseline")
    parser.add_argument("--adopt", action="store_true", help="record unmanaged target files as custom or managed without changing them")
    parser.add_argument("--allow-dirty", action="store_true", help="permit --apply in a target with uncommitted changes")
    parser.add_argument("--json", action="store_true", help="emit a machine-readable report")
    args = parser.parse_args()
    if args.apply and args.adopt:
        parser.error("--apply and --adopt cannot be combined")

    config_path = args.config.expanduser().resolve()
    state_path = args.state.expanduser().resolve()
    try:
        config = load_json(config_path, "target registry")
        if config.get("version") != 1 or not isinstance(config.get("targets"), list):
            raise ValueError("target registry requires version 1 and a targets array")
        state = load_state(state_path)
        available = source_skills(args.source.expanduser().resolve())
    except ValueError as error:
        parser.error(str(error))

    selected_targets = set(args.target)
    requested_skills = set(args.skill)
    unknown_requested = requested_skills - set(available)
    if unknown_requested:
        parser.error(f"requested skill absent from source: {', '.join(sorted(unknown_requested))}")
    report: dict[str, Any] = {
        "source": str(args.source.expanduser().resolve()),
        "mode": "apply" if args.apply else "adopt" if args.adopt else "dry-run",
        "targets": [],
    }
    changed_state = False

    for target_config in config["targets"]:
        if not isinstance(target_config, dict):
            parser.error("every target registry entry must be an object")
        name = target_config.get("name")
        if not isinstance(name, str) or not name:
            parser.error("every target requires a non-empty name")
        if selected_targets and name not in selected_targets:
            continue
        try:
            target = target_path(config_path, target_config.get("path"))
            if not target.is_dir():
                raise ValueError(f"target does not exist: {target}")
            outputs = target_config.get("outputs")
            if not isinstance(outputs, list) or not outputs or not all(item in OUTPUTS for item in outputs):
                raise ValueError(f"target {name} has invalid outputs; choose from {', '.join(OUTPUTS)}")
            skills = configured_skills(target_config, available, requested_skills)
        except ValueError as error:
            parser.error(str(error))

        dirty = target_dirty(target)
        target_report = {"name": name, "path": str(target), "dirty": dirty, "files": []}
        allow_new_skills = target_config.get("allow_new_skills", False)
        if not isinstance(allow_new_skills, bool):
            parser.error(f"target {name} allow_new_skills must be boolean")

        for output in outputs:
            output_root = target / OUTPUTS[output]["directory"]
            for skill in skills:
                files_state = state_files(state, target, output, skill)
                known_skill = bool(files_state)
                for source_file, relative_file in source_files(available[skill]):
                    relative_key = relative_file.as_posix()
                    source_data = source_file.read_bytes()
                    expected = rendered_bytes(source_file, relative_file, output)
                    destination = output_root / skill / relative_file
                    status, actual_hash = classify(
                        files_state.get(relative_key),
                        sha256(source_data),
                        sha256(expected),
                        destination,
                        known_skill,
                        allow_new_skills,
                    )
                    item = {
                        "output": output,
                        "skill": skill,
                        "file": relative_key,
                        "status": status,
                    }
                    target_report["files"].append(item)
                    baseline = {
                        "source_sha256": sha256(source_data),
                        "target_sha256": sha256(expected),
                        "mode": "managed",
                    }
                    write_allowed = args.apply and (dirty is not True or args.allow_dirty)
                    if args.adopt and status in {"adoptable", "unmanaged"}:
                        baseline["target_sha256"] = actual_hash or baseline["target_sha256"]
                        baseline["mode"] = "managed" if status == "adoptable" else "custom"
                        files_state[relative_key] = baseline
                        changed_state = True
                    elif write_allowed and status in {"adoptable", "safe_update", "safe_new"}:
                        if status != "adoptable":
                            atomic_write(destination, expected, source_file.stat().st_mode & 0o777)
                        files_state[relative_key] = baseline
                        changed_state = True
        report["targets"].append(target_report)

    if selected_targets and not report["targets"]:
        parser.error(f"no configured target matched: {', '.join(sorted(selected_targets))}")
    if changed_state:
        write_json(state_path, state)
    render_report(report, args.json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
