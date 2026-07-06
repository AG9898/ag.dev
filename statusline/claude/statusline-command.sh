#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"

STATUSLINE_INPUT="$input" python3 - <<'PY'
import json
import os
import sys
import time
from pathlib import Path, PurePath


def color(code, value):
    return f"\033[{code}m{value}\033[00m"


def sep():
    return "\033[00m \033[02;38;5;124m|\033[00m "


try:
    data = json.loads(os.environ.get("STATUSLINE_INPUT", "") or "{}")
except json.JSONDecodeError:
    data = {}

cwd = data.get("cwd") or os.getcwd()
parts = PurePath(cwd).parts
if len(parts) >= 2:
    short_cwd = f".../{parts[-2]}/{parts[-1]}"
else:
    short_cwd = cwd

segments = [color("01;38;5;197", short_cwd)]

transcript = data.get("transcript_path") or ""
if transcript and os.path.isfile(transcript):
    last_usage = None
    try:
        with open(transcript, encoding="utf-8") as handle:
            for line in handle:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                usage = (event.get("message") or {}).get("usage")
                if usage:
                    last_usage = usage
    except OSError:
        last_usage = None

    if last_usage:
        used = (
            last_usage.get("input_tokens", 0)
            + last_usage.get("cache_read_input_tokens", 0)
            + last_usage.get("cache_creation_input_tokens", 0)
        )
        window = 200000
        remaining = max(0, window - used)
        ctx_pct = int(remaining * 100 / window)
        if ctx_pct >= 40:
            code = "01;38;5;209"
        elif ctx_pct >= 15:
            code = "01;38;5;203"
        else:
            code = "01;38;5;196"
        segments.append(f"ctx {color(code, str(ctx_pct) + '%')}")

state_file = Path(
    os.environ.get(
        "CLAUDE_STATUSLINE_STATE_FILE",
        str(Path.home() / ".claude" / "statusline-5h-window.json"),
    )
)
now = int(time.time())
window_seconds = 18000
start = None

try:
    if state_file.exists():
        start = int((json.loads(state_file.read_text(encoding="utf-8")) or {}).get("start"))
except (OSError, ValueError, TypeError, json.JSONDecodeError):
    start = None

if start is None or now - start >= window_seconds:
    start = now
    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(json.dumps({"start": start}) + "\n", encoding="utf-8")
    except OSError:
        pass

left = max(0, start + window_seconds - now)
hours = left // 3600
minutes = (left % 3600) // 60
if left >= 3600:
    code = "01;38;5;209"
elif left >= 1800:
    code = "01;38;5;203"
else:
    code = "01;38;5;196"
segments.append(f"5h {color(code, f'{hours}h{minutes:02d}m')}")

used_pct = (
    (data.get("rate_limits") or {})
    .get("five_hour", {})
    .get("used_percentage")
)
if used_pct is not None:
    try:
        remaining_pct = max(0, min(100, round(100 - float(used_pct))))
    except (TypeError, ValueError):
        remaining_pct = None
    if remaining_pct is not None:
        if remaining_pct >= 40:
            code = "01;38;5;209"
        elif remaining_pct >= 15:
            code = "01;38;5;203"
        else:
            code = "01;38;5;196"
        segments.append(f"5h {color(code, str(remaining_pct) + '% left')}")

sys.stdout.write(sep().join(segments))
PY
