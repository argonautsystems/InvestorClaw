#!/usr/bin/env python3
"""Validate the InvestorClaw Claude Code plugin/skill repository.

IC_DECOMPOSITION moved the Python engine to ic-engine (pulled as a container
over MCP-HTTP) and removed the TypeScript plugin build, so this repo carries no
buildable Python package or Node project at its root. CI therefore validates
the plugin manifests and skill structure that actually ship here, rather than
running uv/npm/tsc against artifacts that no longer exist.

Exit 0 if everything is consistent; exit 1 (with a list of problems) otherwise.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []


def load_json(rel: str):
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing file: {rel}")
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {rel}: {exc}")
        return None


plugin = load_json(".claude-plugin/plugin.json")
marketplace = load_json(".claude-plugin/marketplace.json")

if plugin is not None:
    for key in ("name", "version", "description"):
        if not plugin.get(key):
            errors.append(f".claude-plugin/plugin.json missing required key: {key}")
    commands = plugin.get("commands")
    if commands and not (ROOT / commands.lstrip("./")).is_dir():
        errors.append(f"plugin.json 'commands' path does not exist: {commands}")

if plugin is not None and marketplace is not None:
    if plugin.get("name") != marketplace.get("name"):
        errors.append(
            f"name mismatch: plugin.json={plugin.get('name')!r} "
            f"marketplace.json={marketplace.get('name')!r}"
        )

# Structural surface the plugin/skill depends on.
for rel in ("SKILL.md", "skill", "commands"):
    if not (ROOT / rel).exists():
        errors.append(f"missing expected path: {rel}")

if errors:
    print("InvestorClaw plugin validation FAILED:")
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)

print(
    f"OK: plugin {plugin.get('name')!r} v{plugin.get('version')} — "
    "manifests + skill structure valid"
)
