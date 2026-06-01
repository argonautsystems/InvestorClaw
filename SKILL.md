---
name: investorclaw
description: Deterministic-first portfolio analyzer — holdings, performance, Sharpe + Sortino, FRED yield curves, bond duration, sector breakdowns, scenario rebalancing.
homepage: https://github.com/argonautsystems/InvestorClaw
user-invocable: true
metadata: {"license":"MIT-0","version":"4.1.31","upstream-runtime":"https://github.com/mnemos-os/mnemos-ic-runtime","upstream-engine":"https://github.com/argonautsystems/ic-engine"}
---

<!--
SPDX-License-Identifier: MIT-0
Copyright 2026 InvestorClaw Contributors
-->

# InvestorClaw

This repository is the **umbrella project** for InvestorClaw — README,
license, regression harness, and the public face. The agent-readable
SKILL.md that ClawHub publishes lives in the runtime repo:

- **Dockerized v4.x runtime + ClawHub-published SKILL.md**:
  [`mnemos-os/mnemos-ic-runtime`](https://github.com/mnemos-os/mnemos-ic-runtime)
- **Claude Code / Claude Desktop plugin** (container-first, this repo):
  `/plugin marketplace add argonautsystems/InvestorClaw` — same skill + container
  as every other runtime. See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).
- **Engine source** (Python analyzers): [`argonautsystems/ic-engine`](https://github.com/argonautsystems/ic-engine)

## Install (v4.x dockerized runtime)

```bash
git clone https://github.com/mnemos-os/mnemos-ic-runtime.git ~/.investorclaw
cd ~/.investorclaw
mkdir -p portfolios
docker compose up -d
```

The compose pulls
\`ghcr.io/argonautsystems/ic-engine:4.6.0-cpu\` (publicly hosted, no
auth) and runs it on \`localhost:18090\` (MCP + REST) and
\`localhost:18092\` (dashboard).

For the full agent-readable spec (12-tool catalog, first-run timeline,
per-runtime config blocks, troubleshooting), see the published
[SKILL.md in the runtime repo](https://github.com/mnemos-os/mnemos-ic-runtime/blob/main/SKILL.md).

## Documentation

This umbrella repo carries the comprehensive doc set:

- [README.md](README.md) — features, quick start, model + API key
  recommendations
- [STONKMODE.md](STONKMODE.md) — narrated commentary mode
- [CAPABILITIES.md](CAPABILITIES.md) — full feature catalog
- [PRIVACY.md](PRIVACY.md) — data-handling policy
- [DISCLAIMER.md](DISCLAIMER.md) — educational-use disclaimer
- [SECURITY.md](SECURITY.md) — vulnerability disclosure
- [CHANGELOG.md](CHANGELOG.md) — release history
- [docs/](docs/) — EOD report, glossary, philosophy, install models,
  COBOL testing, MCP tools reference, Stonkmode architecture +
  avatar legend, Windows setup guide
- [docs/references/](docs/references/) — input / output / schema /
  consultative-LLM contracts

## License

- This umbrella repo: Apache 2.0 (substantive code) + MIT-0 (SKILL.md,
  agent-skills artifacts).
- Per-file SPDX-License-Identifier headers indicate the applicable
  license.

InvestorClaw is educational only. Not financial advice.
