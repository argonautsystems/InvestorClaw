# InvestorClaw

> Deterministic-first portfolio analysis. Real money math, no LLM math.

InvestorClaw is a portfolio analysis skill — holdings snapshots, performance
metrics (Sharpe, Sortino, max drawdown, beta, value-at-risk), bond duration,
FRED yield curves, sector breakdowns, scenario rebalancing — exposed to AI
agents over MCP-HTTP. The math is deterministic Python; the narrative is an
LLM with strict no-fabrication validation.

This repository is the **distribution shell**: README, license, regression
harness, and pointers to the live source. The actual code lives in three
substrate repositories.

## Architecture (v4.x)

| Layer | Repository | Purpose |
|---|---|---|
| **AI primitives** | [`argonautsystems/clio`](https://github.com/argonautsystems/clio) | Schema-map, normalize, vision-extract. Apache 2.0. |
| **Engine** | [`argonautsystems/ic-engine`](https://github.com/argonautsystems/ic-engine) | Portfolio math, FINOS-CDM-inspired data model, deterministic analyzers. Apache 2.0. |
| **Runtime + skill** | [`mnemos-os/mnemos-ic-runtime`](https://github.com/mnemos-os/mnemos-ic-runtime) | Docker container, MCP-HTTP server, agent SKILL.md, ClawHub-publishable. Apache 2.0 (service) + MIT-0 (skill files). |
| **Distribution shell** | this repo | Cobol regression harness + project-level docs. Apache 2.0. |

The previous v2.6.x architecture bundled all of the above into this single
repository as a per-runtime install path (TypeScript plugin shim, npm package,
per-runtime SKILL.md, in-process Python). That path is dead in v4.x. Run the
container, point your MCP client at it.

## Install (v4.x)

The skill is a Docker Compose stack:

```bash
docker compose -f https://raw.githubusercontent.com/mnemos-os/mnemos-ic-runtime/main/compose.yml up -d
```

Pulls `ghcr.io/perlowja/ic-engine:4.1.17-cpu` (public, no auth) and runs the
MCP server on `localhost:18090/mcp` plus a dashboard on `localhost:18092`.

Then point any MCP-capable agent (Claude Code, OpenClaw, ZeroClaw, Hermes,
Cursor, custom MCP clients) at `http://localhost:18090/mcp` with transport
`streamable-http`. Full setup instructions in
[mnemos-os/mnemos-ic-runtime/SKILL.md](https://github.com/mnemos-os/mnemos-ic-runtime/blob/main/SKILL.md).

## Why this architecture

- **Two install models, one engine** — the claw runtimes (OpenClaw,
  ZeroClaw, Hermes) use a dockerized-skill convention (one container,
  MCP-HTTP, agents are pure clients) because they're daemon-style runtimes
  without a "workspace" concept. Claude Code uses the same path today,
  but will eventually get a native-workspace SKILL.md install model
  layered on top once Anthropic marketplace approval lands. Both consume
  the same `ic-engine` source. Architectural rationale + diagrams in
  [`mnemos-ic-runtime/docs/INSTALL_MODELS.md`](https://github.com/mnemos-os/mnemos-ic-runtime/blob/main/docs/INSTALL_MODELS.md).
- **Cobol determinism testing** — every release ships through the 250-prompt
  Agentic COBOL regression set with a strict verdict (rejects catalog
  blurbs, hallucinated portfolio context, and rejection markers). This is
  the v4.x ship gate. Methodology + empirical narrative in
  [`mnemos-ic-runtime/docs/COBOL_TESTING.md`](https://github.com/mnemos-os/mnemos-ic-runtime/blob/main/docs/COBOL_TESTING.md);
  long-form publishable rationale in
  [`harness/cobol/BLOG_DRAFT_techbroiler.md`](harness/cobol/BLOG_DRAFT_techbroiler.md).

## Cobol regression harness

`harness/cobol/` is the canonical 250-NLQ regression test set used to validate
end-to-end agent behavior across runtimes. Spec in
[`harness/cobol/AGENTIC_COBOL_SPEC.md`](harness/cobol/AGENTIC_COBOL_SPEC.md);
prompt set in [`harness/cobol/nlq-prompts.json`](harness/cobol/nlq-prompts.json).

Run it against a live ic-engine container:

```bash
python3 harness/cobol/cobol_barrage_cross_runtime.py \
  --prompts harness/cobol/nlq-prompts.json \
  --target http://localhost:18090/mcp \
  --out reports/cobol-$(date +%Y%m%d-%H%M%S).jsonl
```

## Status

| | |
|---|---|
| Engine | `ic-engine` v4.1.17 (commit `0fa8ed1`) |
| Runtime image | `ghcr.io/perlowja/ic-engine:4.1.17-cpu` |
| Cobol pass rate | 245-249/250 (98-99%) on baked images |
| ClawHub publish | `clawhub skill publish` from `mnemos-ic-runtime` |

## License

- Distribution shell (this repo, README, harness): Apache 2.0 — `LICENSE`
- Distribution-edge artifacts intended for downstream skill registries
  (SKILL.md): MIT-0 — `LICENSE-MIT-0`

InvestorClaw is educational only. Not financial advice. Not a brokerage.
Always discuss with a licensed financial advisor before making investment
decisions.

## v2.6.x → v4.x migration

If you were using the v2.6.x in-process plugin install path (npm package,
TypeScript shim, per-runtime SKILL.md), that path is gone from `main`. Two
options:

1. **Recommended**: switch to the v4.x dockerized-skill convention above.
2. **Last resort**: `git checkout v2.6.3` to recover the legacy code. v2.6.3
   tag is preserved in this repo's history.

The v4.x architecture is significantly thinner end-to-end (one container, one
MCP endpoint, no per-runtime install paths), more secure (the engine never
loads agent code; the agent never loads engine code), and easier to update
(`docker compose pull` instead of per-runtime npm publishes).
