# InvestorClaw Release Notes

**Current: v2.6.0** (Apache 2.0, `gitlab.com/argonautsystems/InvestorClaw`)

InvestorClaw is the adapter package for Claws-family and standalone portfolio-analysis runtimes. It owns install scripts, manifests, routing contracts, and the compatibility CLI shim. The deterministic Python engine lives in [`ic-engine`](https://gitlab.com/argonautsystems/ic-engine); foundation primitives live in [`clio`](https://gitlab.com/argonautsystems/clio).

## v2.6.0

Public-hygiene cleanse and Claude Code marketplace separation.

- **History rewrite (filter-repo).** Removed internal infrastructure identifiers (private LAN IPs, fleet hostnames, internal NAS paths, a sudo password used in test docs) from all of git history. Replaced internal codenames with role-name placeholders (`linux-x86-host`, `gpu-host`, `mac-arm-host`, etc.); replaced private LAN IPs with RFC5737 documentation IPs (`192.0.2.x`); deleted internal-only artifacts (test result dumps, Claude session handoffs, harness backups). Force-pushed to all three remotes. **Action for downstream clones:** delete and re-clone, or `git fetch && git reset --hard origin/main`.
- **Claude Code marketplace removed from this repo.** The forwarding `.claude-plugin/marketplace.json` is gone; Claude Code installs now redirect users straight to the [InvestorClaude](https://gitlab.com/argonautsystems/InvestorClaude) repo. The forwarding pattern relied on a non-canonical `source.url` that Anthropic's plugin loader expects to be `source: "./"` per documented contract. InvestorClaude is the canonical Claude Code marketplace target.
- **Ship-readiness baseline added.** `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `DISCLAIMER.md` (financial software disclaimer + Provider Data Flows), `CHANGELOG.md` (this file's machine-readable companion), SPDX-License-Identifier headers across `bin/`, top-level entry points, and harness Python.
- **License field SPDX-aligned.** `pyproject.toml` license set to `Apache-2.0` (was `Apache 2.0 Dual License`). LICENSE itself is plain Apache 2.0; the dual-license model returns when the unreleased commercial tier ships, in its own LICENSE for that product.
- **Engine pin** `ic-engine` aligned to `v2.6.0`.

## v2.5.0

Adapter consolidation for `ic-engine` v2.5.0.

- Collapsed the agent-facing surface from 9 `portfolio_*` tools to 2 tools: `portfolio_ask` and `portfolio_refresh`.
- Pinned `ic-engine` to `v2.5.0` and aligned InvestorClaw adapter metadata to `2.5.0`.
- Updated OpenClaw, Hermes, ZeroClaw, and standalone user-facing command text to route users through `investorclaw ask "<question>"`.
- Preserved deterministic-first guardrails: finance prompts route through the signed `ic_result` path, not model memory or web search.

Migration table:

| v2.3.x tool | v2.5.0 replacement |
|-------------|--------------------|
| `portfolio_view` | `portfolio_ask` |
| `portfolio_compute` | `portfolio_ask` |
| `portfolio_target` | `portfolio_ask` |
| `portfolio_scenario` | `portfolio_ask` |
| `portfolio_market` | `portfolio_ask` |
| `portfolio_bonds` | `portfolio_ask` |
| `portfolio_config` | `portfolio_ask` |
| `portfolio_report` | `portfolio_ask` |
| `portfolio_lookup` | `portfolio_ask` |

Use `portfolio_refresh` only when the user explicitly asks to force a fresh
pipeline run or invalidate stale cached prices/news.

## v2.3.3

Pre-public-release announcement cleanup.

- Synchronized adapter version metadata across `pyproject.toml`, `investorclaw.py`, `SKILL.toml`, `openclaw.plugin.json`, and `package.json`.
- Synchronized the fallback `requirements.txt` engine pin with `pyproject.toml` and `uv.lock`: `ic-engine` `v2.4.6`.
- Cleaned public docs and manifests that still described the pre-Phase-2 monolith.
- Aligned command-surface descriptions to the current 22-command harness matrix and the 9-tool consolidated `SKILL.toml` surface.
- Removed broken references to the old top-level Claude Code implementation path. Claude Code plugin development is now in InvestorClaude; this repo keeps the forwarding marketplace entry.

## v2.3.2

Engine pin bump and CDM-vs-legacy field-name sweep.

- Bumped the adapter's `ic-engine` pin from `v2.4.2` to `v2.4.6`.
- Picked up the engine-side CDM and legacy field-name compatibility fixes for holdings, presentation, and downstream report consumers.
- Kept `clio` pinned at `v0.1.0`.

## v2.3.1

Minor post-decomposition fixes.

- Tightened adapter metadata after the Phase 2 split.
- Preserved the installed `investorclaw` shim as the adapter entry point so `.env` loading and `INVESTORCLAW_SKILL_DIR` resolution happen before delegating to `ic-engine`.
- Updated routing and marketplace scaffolding for the Claude Code plugin split.

## v2.3.0

Phase 2 of `IC_DECOMPOSITION`.

- Moved the Python portfolio engine out of this repo into `ic-engine`.
- Converted InvestorClaw into a slim adapter package: install scripts, manifests, routing contracts, harness metadata, and the compatibility CLI shim.
- Added `ic-engine` and `clio` as pinned runtime dependencies.
- Preserved the public `investorclaw` command while delegating command execution to `ic_engine.cli.main`.

## Current Surfaces

- Deterministic user entry point: `investorclaw ask "<question>"`.
- Freshness entry point: `investorclaw refresh`.
- Consolidated skill surface: [SKILL.toml](SKILL.toml) exposes `portfolio_ask` and `portfolio_refresh`.
- Install surfaces: `openclaw/install.sh`, `zeroclaw/install.sh`, `hermes/install.sh`, and the standalone `bin/setup-orchestrator` flow.
- Claude Code: forwarded through `.claude-plugin/marketplace.json` to InvestorClaude.

## Providers

Cross-runtime provider coverage is documented in [docs/AGENT-COMPARISON.md](docs/AGENT-COMPARISON.md). Local OpenAI-compatible backends include Ollama, llama-server, LMStudio, and vLLM. Market-data fallback remains `yfinance` when optional keys are not configured.

## Known Limitations

- The interactive PWA dashboard is still deferred. Dashboard requests return the canonical deferral envelope where supported.
- ZeroClaw deployments still depend on a Python environment in or around the runtime container.
- Hermes Agent provider support is constrained by the provider enum in the Hermes CLI; OpenRouter remains the practical proxy for providers that are not natively exposed.

## Validation

For this adapter repo, the release gate is:

```bash
python harness/contract_check.py
```

Engine behavior is validated in the `ic-engine` repo.

## License

Apache 2.0.
