---
name: investorclaw
description: Deterministic-first portfolio analyzer — holdings, performance, Sharpe + Sortino, FRED yield curves, bond duration, sector breakdowns, scenario rebalancing — via MCP-HTTP.
homepage: https://github.com/argonautsystems/InvestorClaw
user-invocable: true
metadata: {"license":"MIT-0","version":"4.1.17","image":"ghcr.io/perlowja/ic-engine:4.1.17-cpu","mcp-endpoint":"http://localhost:18090/mcp","transport":"streamable-http","runtime-repo":"https://github.com/mnemos-os/mnemos-ic-runtime"}
---

<!--
SPDX-License-Identifier: MIT-0
Copyright 2026 InvestorClaw Contributors
-->

# InvestorClaw — distribution shell

This `SKILL.md` lives in the v4.x distribution shell. The runtime SKILL.md
that agents and ClawHub consume is at:

**https://github.com/mnemos-os/mnemos-ic-runtime/blob/main/SKILL.md**

That repository bundles `compose.yml`, `install.yaml`, per-runtime
config snippets, and the canonical install instructions for OpenClaw,
ZeroClaw, Hermes, Claude Code, Claude Desktop, and any other MCP-capable
agent.

## Quick install

```bash
docker compose -f https://raw.githubusercontent.com/mnemos-os/mnemos-ic-runtime/main/compose.yml up -d
```

Then point your agent at `http://localhost:18090/mcp` (transport: `streamable-http`).

Image: `ghcr.io/perlowja/ic-engine:4.1.17-cpu` (public, no auth required).

## v2.6.x users

The v2.6.x in-process plugin install path is gone from `main`. The v2.6.3
git tag preserves the legacy code if you need it. The recommended migration
is the v4.x dockerized-skill convention above — one container, one MCP
endpoint, no per-runtime install paths.

See [README.md](README.md) for the full v4.x architecture overview and
[mnemos-os/mnemos-ic-runtime](https://github.com/mnemos-os/mnemos-ic-runtime)
for the canonical install + upgrade path.
