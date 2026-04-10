# InvestorClaw

Portfolio analysis skill for OpenClaw agents. **v1.0.0** | FINOS CDM 5.x | MIT License

Provides holdings snapshots, performance metrics, bond analytics, analyst ratings, portfolio news, and CSV/Excel exports, with built-in financial advice guardrails that enforce educational-only output.

> **Naming note**: the package id is `investorclaw` (used by ClawHub and `openclaw.plugin.json`). The OpenClaw invocation command is `/portfolio`. Both names are intentional.

---

## Requirements

- Python 3.9+
- OpenClaw >= 2026.0.0
- **LLM with 128K+ context window** — 200K+ recommended; see [Choosing Your LLM](#choosing-your-operational-llm) below
- API keys (all optional, all have free tiers):
  - [Finnhub](https://finnhub.io/register) for real-time quotes and analyst ratings
  - [NewsAPI](https://newsapi.org/register) for portfolio news correlation
  - [Polygon.io](https://polygon.io/dashboard/signup) for supplemental market data
  - [Alpha Vantage](https://www.alphavantage.co/support/#api-key) for supplemental price data
  - [FRED](https://fred.stlouisfed.org/docs/api/api_key.html) for Treasury benchmark yields

## Installation

**Via OpenClaw** (recommended): install from ClawHub or add directly from GitHub.

**Manual install**:
```bash
git clone https://github.com/perlowja/InvestorClaw.git
cd InvestorClaw
pip install -r requirements.txt
python3 tests_smoke.py
python3 investorclaw.py setup
```

For a full contributor install:
```bash
pip install -r requirements.txt -r requirements-dev.txt
pytest tests/ -v
```

Configure API keys in `.env` (copy from `.env.example`). Guided setup and first-run helpers live under `setup/` and are invoked through the entry point.

## Repository Layout

| Path | Purpose |
|------|---------|
| `investorclaw.py` | Entry point, bootstrap, routing, guardrail priming |
| `commands/` | One command script per feature |
| `config/` | Config loading, arg synthesis, path resolution, help text |
| `models/` | Portfolio, holdings, routing, and context models |
| `providers/` | Market and symbol data providers |
| `rendering/` | Compact serializers, consultation cards, disclaimers, progress |
| `runtime/` | Router, environment bootstrap, subprocess execution |
| `services/` | Consultation policy, portfolio consolidation, PDF extraction, utilities |
| `setup/` | First-run, installer, setup wizard, identity updater |
| `internal/` | Tier-3 enrichment internals |
| `data/` | Guardrails and symbol/reference data |
| `tests/` | Unit and contract tests |
| `pipeline.py` | Full pipeline entry for multi-step analysis |

**Not committed:**
- `.env` containing your secrets
- `portfolios/*.csv` with personal holdings
- generated files under `$INVESTOR_CLAW_REPORTS_DIR`

## Quick Start

```bash
# First-time setup
python3 investorclaw.py setup

# Holdings snapshot with live prices
python3 investorclaw.py holdings

# Performance analysis
python3 investorclaw.py performance

# Bond analytics
python3 investorclaw.py bonds

# Show all commands
python3 investorclaw.py help
```

Always invoke through `investorclaw.py`. The entry point loads `.env`, bootstraps configuration, primes model guardrails when needed, synthesizes default arguments, and routes to the correct command module.

## Commands

| Command | Aliases | Primary artifact |
|---------|---------|------------------|
| `holdings` | `snapshot`, `prices` | `holdings.json` |
| `performance` | `analyze`, `returns` | `performance.json` |
| `bonds` | `bond-analysis`, `analyze-bonds` | `bond_analysis.json` |
| `analyst` | `analysts`, `ratings` | `analyst_data.json` |
| `news` | `sentiment` | `portfolio_news.json` |
| `analysis` | `portfolio-analysis` | `portfolio_analysis.json` |
| `synthesize` | `multi-factor`, `recommend`, `recommendations` | `portfolio_analysis.json` |
| `fixed-income` | `fixed-income-analysis`, `bond-strategy` | `fixed_income_analysis.json` |
| `report` | `export`, `csv`, `excel` | `portfolio_report.{csv,xlsx}` |
| `session` | `session-init`, `risk-profile`, `calibrate` | `session_profile.json` |
| `lookup` | `query`, `detail` | targeted stdout lookup |
| `guardrails` | `guardrail`, `guardrails-prime`, `guardrails-status` | stdout |
| `update-identity` | `update_identity`, `identity` | — |
| `run` | `pipeline` | pipeline stdout + artifacts |
| `ollama-setup` | `model-setup`, `consult-setup` | stdout |
| `setup` | `auto-setup`, `init`, `initialize` | setup output |

Output files are written to `$INVESTOR_CLAW_REPORTS_DIR` (default: `~/portfolio_reports/`).

## Output Model

InvestorClaw follows a dual-output pattern:

| Output | What it contains | Audience |
|--------|------------------|----------|
| `stdout` | Compact, token-aware JSON or human-readable command output | OpenClaw agent context |
| Disk artifact | Full JSON, CSV, or Excel output | Human review and downstream tools |

The core artifact names are `holdings.json`, `performance.json`, `bond_analysis.json`, `analyst_data.json`, `portfolio_news.json`, `portfolio_analysis.json`, `fixed_income_analysis.json`, and `session_profile.json`.

## Choosing Your Operational LLM

InvestorClaw uses a single-model architecture: one LLM handles routing, analysis, and guardrail enforcement via OpenClaw.

### Context window requirements

| Portfolio size | Typical token load | Minimum context |
|---------------|-------------------|----------------|
| Small (< 20 positions) | 10K–30K tokens | 64K |
| Medium (20–100 positions) | 30K–80K tokens | 128K |
| Large (100+ positions) | 80K–200K+ tokens | **200K** |
| Multi-account with enrichment | 150K–400K+ tokens | **1M+** |

> **Hard minimum: 128K.** Models below this will truncate mid-analysis. 200K+ is strongly recommended for any realistic portfolio. Multi-account or fully-enriched runs regularly exceed 300K tokens.

### Recommended: xAI Grok 4.1 Fast

Model ID: `xai/grok-4-1-fast`

- **~2M token context window** — handles the largest portfolios, long sessions, and full enrichment without truncation
- Strong financial reasoning; fastest response time among frontier models tested
- Sign up at [console.x.ai](https://console.x.ai)

> **Compliance note**: `xai/grok-4-1-fast` requires running `/portfolio update-identity` at the start of each session. Without this step, guardrail disclaimer compliance drops to near zero — the model ignores its financial advice restrictions. This is an xAI quirk, not an InvestorClaw bug. The `update-identity` command patches the agent's `IDENTITY.md` with the active ruleset.
>
> Config aliases: `xai/grok-4-1-fast-reasoning` and `grok-reasoning` both resolve to the same model. `xai/grok-4` (250K context) is a separate, smaller model — do not confuse them.

### High-context alternative: Google Gemini 3 Flash

Model ID: `google/gemini-3-flash-preview`

- **~1M token context window** — excellent for very large multi-account portfolios or fully-enriched analyst runs
- Fast inference; good quantitative reasoning for bond math and multi-factor correlation
- Sign up at [aistudio.google.com](https://aistudio.google.com)

Lighter variant: `google/gemini-3.1-flash-lite-preview` — same context window, lower cost, reduced synthesis depth.

### High-context alternative: Together AI / Llama 4 Maverick

Model ID: `together/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8`

- **~1M token context window** — handles large multi-account portfolios at competitive cost
- Good general reasoning via Together AI hosted inference
- Sign up at [together.ai](https://together.ai)

### Alternative: OpenAI GPT-4.1

Model ID: `openai/gpt-4.1`

- **~1M token context window** — adequate for most individual and multi-account portfolios
- Multimodal (text + image); solid instruction-following and disclaimer compliance
- Sign up at [platform.openai.com](https://platform.openai.com)

Newer OpenAI variants `openai/gpt-5.3-chat-latest` (391K context) and `openai/gpt-5.4` (266K context) are available but have smaller context windows — verify your full enriched session fits before using.

> ⚠️ **Do not use GPT-4.1-nano** (`openai/gpt-4.1-nano`). Its Tier 1 rate limit is **30K TPM shared across all OpenClaw session activity**. Any concurrent agentic work exhausts the budget before a full portfolio analysis completes. Do not use it for InvestorClaw regardless of cost appeal.

### Fast inference: Groq (Llama)

For applications where latency matters more than context depth — dashboards, quick status checks, polling loops — Groq provides exceptionally fast Llama inference:

| Model | Context | Use case |
|-------|---------|---------|
| `groq/llama-3.3-70b-versatile` | 128K | Best Groq quality; small–medium portfolios |
| `groq/llama-3.1-8b-instant` | 128K | Fastest response; limited reasoning depth |
| `groq/openai/gpt-oss-120b` | 128K | OpenAI OSS 120B via Groq |
| `groq/openai/gpt-oss-20b` | 128K | OpenAI OSS 20B via Groq |

> 128K context caps these to small-to-medium portfolios. Not suitable for multi-account or fully-enriched sessions.

### On-Premise: NVIDIA NIM

Model ID: `nvidia/nemotron-3-super-120b-a12b`

- **256K token context window** — suitable for medium-to-large individual portfolios
- Runs via NVIDIA NIM inference infrastructure; ideal for air-gapped or on-premise deployments where portfolio data cannot leave the network
- Also available through NemoClaw (NVIDIA's OpenClaw integration): see the [NemoClaw documentation](https://github.com/NVIDIA/NemoClaw)

### Provider comparison

| Model | Context | Provider | Notes |
|-------|---------|---------|-------|
| `xai/grok-4-1-fast` ⭐ | ~2M | xAI | **Primary recommendation**; needs `update-identity` each session |
| `google/gemini-3-flash-preview` | ~1M | Google | Best high-context alternative |
| `together/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8` | ~1M | Together AI | Good cost/context ratio |
| `openai/gpt-4.1` | ~1M | OpenAI | Solid; multimodal |
| `openai/gpt-5.3-chat-latest` | 391K | OpenAI | Newer; verify context fits |
| `openai/gpt-5.4` | 266K | OpenAI | Newer; verify context fits |
| `nvidia/nemotron-3-super-120b-a12b` | 256K | NVIDIA NIM | On-premise / air-gapped |
| `groq/llama-3.3-70b-versatile` | 128K | Groq | Fast inference; small portfolios only |
| `openai/gpt-4.1-nano` | ~1M | OpenAI | ❌ **Not recommended** — 30K TPM Tier 1 limit |

## Local Consultation Model (Optional)

InvestorClaw supports a two-layer architecture:

1. **Operational LLM** for routing, conversation, and guardrail handling via OpenClaw
2. **Consultation model** (local Ollama) for structured portfolio synthesis before the operational model sees the result

Enable via `.env`:
```bash
INVESTORCLAW_CONSULTATION_ENABLED=true
INVESTORCLAW_CONSULTATION_ENDPOINT=http://localhost:11434
INVESTORCLAW_CONSULTATION_MODEL=gemma4-consult
```

`gemma4-consult` is the recommended default — a tuned Ollama derivative of `gemma4:e4b` (num_ctx=2048, num_predict=600, ~65 tok/s on RTX Ada Lovelace). Other tested models: `gemma4:e4b`, `nemotron-3-nano`, `qwen2.5:14b`. Run `/portfolio ollama-setup` to auto-detect available models and build the `gemma4-consult` Modelfile on your endpoint.

**Hardware requirements for consultation**: 12+ GB VRAM, CUDA compute capability ≥ 8.0 (RTX 30xx / A-series / Ada Lovelace or newer), Ollama ≥ 0.20.x.

The consultation policy lives in `services/consultation_policy.py`. Consultation is injected for analyst commands (tier-3 enrichment) when enabled; results are HMAC-signed to prevent fabrication.

## Portfolio File Format

Place CSV or Excel (`.xls`, `.xlsx`) files in `portfolios/` or set `$INVESTOR_CLAW_PORTFOLIO_DIR`.

Run `python3 investorclaw.py setup` for guided column mapping and portfolio discovery if your broker uses non-standard column names.

## Security

InvestorClaw includes several safety measures:

- PII scrubbing for sensitive identifiers found in imported portfolio data
- Prompt-injection scanning on untrusted text fields
- Deterministic Python calculations for portfolio math
- Optional local consultation to keep raw portfolio data on-premise
- Educational-only financial guardrails via `data/guardrails.yaml`

## Development

```bash
pip install -r requirements.txt -r requirements-dev.txt
pytest tests/ -v
```

## Compliance

**NOT INVESTMENT ADVICE.** InvestorClaw provides educational portfolio analysis only. It is not a substitute for professional financial advice and does not assess personal risk tolerance, goals, or investment suitability.

## License

MIT, see [LICENSE](LICENSE).
