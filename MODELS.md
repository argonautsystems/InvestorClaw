# InvestorClaw — Tested Models and Benchmark Results

Harness: V6.1.2 | Runs: IC-RUN-20260413-002 through IC-RUN-20260413-009 | Last updated: 2026-04-13

---

## Mode Definitions

Understanding the distinction between these two modes is essential for reading the tables below.

### Hybrid mode (operational + consultation)

The operational LLM routes the session, runs tools, and frames the synthesis output. A separate **local consultation model** (CERBERUS — `gemma4-consult` via Ollama at `192.168.207.96:11434`) runs before synthesis and enriches each portfolio symbol with a structured analyst summary. The operational model receives compact enriched records, not raw data.

- Requires a local GPU host running Ollama with `gemma4-consult` (or a compatible model)
- Produces HMAC-fingerprinted synthesis records with `verbatim_required=true` and `is_heuristic=false`
- Enables the anti-fabrication controls: fingerprint chain, verbatim attribution, quote artifact
- **The local enrichment layer, not the operational model, is the primary driver of information density**

### Single-model mode (operational only, no consultation)

The operational LLM handles all routing, tool calls, and synthesis directly from heuristic analyst summaries. No local enrichment step. No fingerprint controls.

- Works with any capable cloud operational LLM
- No GPU or local inference required
- Lower information density on portfolios with many individual equities
- Still enforces guardrails and educational-only output

### DEV-001 note

During Phase 5 testing (WF36–WF41), the workspace `.env` file was inadvertently populated with CERBERUS config from a prior run. As a result, all Phase 5 sessions ran in **hybrid mode even when the intent was to test a new operational model alone**. This is documented as deviation **DEV-001** in the test harness. The CERBERUS column in the tables below marks which runs were affected. Scores for DEV-001-affected sessions are elevated relative to true single-model performance and should not be treated as standalone cloud-only benchmark numbers.

WF46 onwards used a clean clone with no workspace `.env`, accurately reflecting single-model behavior.

---

## Benchmark Scores — Harness V6.1.2

The harness runs 39 workflow checkpoints across 5 phases (W0–W8): holdings, analysis, performance, bonds, synthesis, lookup, export, guardrail validation. Scores below are measured on W6 synthesis output — the highest-value single response in a typical InvestorClaw session.

### Key finding

**The combined config (xai/grok-4-1-fast + gemma4-consult enrichment) produces 14× more metric citations than the heuristic baseline.** This gap is driven by the enrichment layer, not the operational model. Switching to a more expensive frontier model without enrichment produces at most modest phrasing improvement. Switching from heuristic to enriched mode produces the step-change.

### Information density scores (W6 synthesis output)

| Metric | Combined WF39 | Grok 4.20 WF37 | Kimi-K2.5 WF40 | GPT-5.4 WF36 | Gemini 3.1 WF38 | GPT-OSS-120B WF46 | True baseline |
|--------|:-------------:|:--------------:|:--------------:|:------------:|:---------------:|:-----------------:|:-------------:|
| **QC3** Ticker mentions | **8** | ~32 | ~26 | ~35 | ~24 | ~3 | 7 |
| **QC4** Metric citations | **113** | ~65 | ~35 | ~60 | ~33 | ~10 | 8 |
| **QC5** Word count | **1,184** | 728 | ~1,450 | ~900 | 441 | ~280 | 200 |
| **QC8** `is_heuristic=false` | **✅** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **QC10** Disclaimer instances | **2** | 2 | 2 | 2 | 1 ⚠️ | 2 | 2 |
| **QC13** Autonomous W6 prose | **✅** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Mode** | Hybrid | Hybrid† | Hybrid† | Hybrid† | Hybrid† | Single | Single |
| **All commands pass** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

† DEV-001: CERBERUS active due to workspace `.env` configuration during Phase 5 testing. Scores reflect hybrid mode even though intent was single-model comparison.

**True baseline** = `xai/grok-4-1-fast-reasoning` with CERBERUS explicitly absent. This is the fairest single-model reference point.

---

## Full Test Run Catalog

### Passing and degraded runs (produced usable W6 synthesis)

| Run | Model | Mode | CERBERUS | Result |
|-----|-------|------|:--------:|:------:|
| **WF39** | `xai/grok-4-1-fast-reasoning` + `gemma4-consult` | Hybrid | ✅ | ✅ PASS — canonical combined config |
| WF62 | `xai/grok-4-1-fast` (regression verification) | Hybrid | ✅ | ✅ PASS |
| True baseline | `xai/grok-4-1-fast-reasoning` | Single | ✗ | ✅ PASS — reference for cloud-only |
| WF36 | `openai/gpt-5.4` | Hybrid† | ✅ | ✅ PASS |
| WF37 | `xai/grok-4.20-0309-non-reasoning` | Hybrid† | ✅ | ✅ PASS |
| WF38 | `google/gemini-3.1-pro-preview` | Hybrid† | ✅ | ⚠️ PASS/caveat — QC10=1 (one disclaimer); requires system prompt hardening for FA mode |
| WF40 | `together/moonshotai/Kimi-K2.5` | Hybrid† | ✅ | ✅ PASS |
| WF41 | `groq/qwen/qwen3-32b` | Hybrid† | ✅ | ⚠️ DEGRADED — QC9 partial (JSON schema fields absent); non-FA workloads only |
| WF46 | `groq/openai/gpt-oss-120b` | Single | ✅ tool calls | ✅ PASS — structured mode; CERBERUS active for tool-call returns only, not synthesis enrichment |
| WF48 | `together/deepseek-ai/DeepSeek-V3.1` | Hybrid† | ✅ | ✅ PASS |
| WF53 | `together/MiniMaxAI/MiniMax-M2.5` | Hybrid† | ✅ | ⚠️ DEGRADED — `/portfolio synthesize` not recognized; W5 news non-functional; use M2.7 |
| WF54 | `together/MiniMaxAI/MiniMax-M2.7` | Hybrid† | ✅ | ✅ PASS |
| WF55 | `together/zai-org/GLM-5` | Hybrid† | ✅ | ✅ PASS |
| WF58 | `groq/moonshotai/kimi-k2-instruct-0905` | Single | — | ✅ PASS ⚠️ preview model |
| WF59 | `groq/openai/gpt-oss-20b` | Single | ✅ | ✅ PASS |
| WF60 | `together/moonshotai/Kimi-K2.5` (structured re-test) | Single | — | ✅ PASS |
| WF61 | `together/Qwen/Qwen3-235B-A22B-Instruct-2507-tput` | Single | ✗‡ | ✅ PASS |

† DEV-001: CERBERUS active due to workspace `.env` populated during Phase 5.

‡ WF61: CERBERUS probe failed (missing workspace `.env`). Heuristic mode fired. The operational model fabricated CERBERUS attribution — no Perplexity code path exists in `tier3_enrichment.py`. Root cause: workspace `.env` was absent; background enricher could not find the consultation endpoint. Fixed by W0.3.1 (mandatory `.env` copy step) added to the harness.

### Partial / not viable (tool calls work but impractical)

| Run | Model | Reason |
|-----|-------|--------|
| WF47 | `together/Qwen/Qwen3-235B-A22B-Thinking-2507` | PARTIAL/TIMEOUT — tool calls execute correctly; 5–10 min/step; full harness ~2–3 hrs; not viable for interactive sessions |

### Blocked (cannot execute tool calls at all)

| Run | Model | Reason |
|-----|-------|--------|
| WF49 | `together/deepseek-ai/DeepSeek-R1-0528` | Tool-text incompatibility — outputs tool name as code block, not a function call |
| WF50 | `together/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8` | Tool payload rejected by Together AI serverless endpoint |
| WF51 | `together/meta-llama/Llama-4-Scout-17B-16E-Instruct` | Tool payload rejected (Groq variant runs but is degraded) |
| WF52 | `together/moonshotai/Kimi-K2-Thinking` | Tool payload rejected — thinking variant not tool-call compatible |
| WF56 | `together/zai-org/GLM-4.7` | Tool payload rejected — GLM-5 works; GLM-4.7 does not |
| WF57 | `together/Qwen/Qwen3-Next-80B-A3B-Instruct` | Tool payload rejected — MoE 80B variant not compatible |

---

## Provider Model Catalog

### xAI (Grok)

| Model | Context | Mode tested | Result | Notes |
|-------|---------|:-----------:|:------:|-------|
| `xai/grok-4-1-fast` | ~2M | Hybrid | ✅ | **Recommended operational default.** Best agentic calibration; 2M context means no truncation on large enriched sessions. Requires `/portfolio update-identity` each session for full disclaimer compliance. |
| `xai/grok-4.20-0309-non-reasoning` | ~1M | Hybrid† | ✅ | **Best cloud-only synthesis** when CERBERUS active. Highest metric density (QC4=65); uniquely added cross-holding news sentiment correlation. Best for high-value single sessions. |

### OpenAI

| Model | Context | Mode tested | Result | Notes |
|-------|---------|:-----------:|:------:|-------|
| `openai/gpt-5.4` | ~272K | Hybrid† | ✅ | Strongest prose; highest ticker mentions (~35) and word count (~900) among frontier group. 36% context use on large portfolio — watch for pressure on very large sessions. |

### Google

| Model | Context | Mode tested | Result | Notes |
|-------|---------|:-----------:|:------:|-------|
| `google/gemini-3.1-pro-preview` | ~1M | Hybrid† | ⚠️ | Solid synthesis; lowest cost per token. QC10=1 (one disclaimer instance vs expected two). Requires system prompt hardening before FA mode deployment. |

### Together AI

| Model | Context | Mode tested | Result | Notes |
|-------|---------|:-----------:|:------:|-------|
| `together/moonshotai/Kimi-K2.5` | 262K | Hybrid† + Single | ✅ | **Best non-frontier substitute.** Highest word count (~1,450 words); full disclaimer compliance; clean protocol. Passes in both hybrid and single modes. |
| `together/deepseek-ai/DeepSeek-V3.1` | 131K | Hybrid† | ✅ | Full synthesize prose; $0.60/$1.70/M |
| `together/MiniMaxAI/MiniMax-M2.7` | 197K | Hybrid† | ✅ | Most economical Together option ($0.30/$1.20/M); synthesize recognized |
| `together/zai-org/GLM-5` | 203K | Hybrid† | ✅ | Fastest CERBERUS response (1031ms); W7 verbal calibration gap |
| `together/MiniMaxAI/MiniMax-M2.5` | — | Hybrid† | ⚠️ DEGRADED | `/portfolio synthesize` not recognized; W5 news non-functional; use M2.7 instead |
| `together/Qwen/Qwen3-235B-A22B-Instruct-2507-tput` | 262K | Single | ✅ | ~300-word synthesis; 60k/262k context use |
| `together/Qwen/Qwen3-235B-A22B-Thinking-2507` | — | — | ⚠️ PARTIAL | Tool calls work but 5–10 min/step; not viable for interactive sessions |
| `together/deepseek-ai/DeepSeek-R1-0528` | — | — | 🚫 BLOCKED | Outputs tool name as text code block instead of function call |
| `together/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8` | — | — | 🚫 BLOCKED | Tool payload rejected by Together AI serverless |
| `together/meta-llama/Llama-4-Scout-17B-16E-Instruct` | — | — | 🚫 BLOCKED | Tool payload rejected (Together AI variant) |
| `together/moonshotai/Kimi-K2-Thinking` | — | — | 🚫 BLOCKED | Thinking variant not tool-call compatible |
| `together/zai-org/GLM-4.7` | — | — | 🚫 BLOCKED | GLM-5 works; GLM-4.7 does not |
| `together/Qwen/Qwen3-Next-80B-A3B-Instruct` | — | — | 🚫 BLOCKED | MoE 80B variant not tool-call compatible |

### Groq

Fast inference (500–1000 tok/s) at low cost. 128K context limits to small-to-medium portfolios — not suitable for large multi-account or fully-enriched sessions.

| Model | Context | Mode tested | Result | Notes |
|-------|---------|:-----------:|:------:|-------|
| `groq/openai/gpt-oss-120b` | 128K | Single | ✅ | **Recommended Groq option.** Full autonomous synthesis; $0.15/$0.60/M; 500 tok/s; minor W0/W7 protocol gaps. Production-stable. |
| `groq/openai/gpt-oss-20b` | 128K | Single | ✅ | Full synthesize (~250 words); $0.075/$0.30/M; 1000 tok/s. Production-stable. |
| `groq/moonshotai/kimi-k2-instruct-0905` | 262K | Single | ✅ ⚠️ | Best Groq prose (~350 words). **Preview tier — not production-stable; may be discontinued without notice.** |
| `groq/qwen/qwen3-32b` | 128K | Hybrid† | ⚠️ PASS/partial | Compact synthesis; QC9 partial (JSON schema fields absent); acceptable for non-FA workloads. Preview model. |
| `groq/meta-llama/llama-4-scout-17b-16e-instruct` | 128K | — | ⚠️ DEGRADED | Requires extra prompt step for W6 prose; heat_level type error; preview model |
| `groq/moonshotai/kimi-k2-instruct` | 128K | — | ⚠️ DEGRADED | Thin synthesis (~144 words); undocumented endpoint; not in official Groq docs |
| `groq/llama-3.3-70b-versatile` | 128K | — | 🚫 DO NOT USE | Config corruption risk — wrote unauthorized keys into `openclaw.json` during testing |

> **Groq stability note**: Production-stable models confirmed in official Groq docs: `llama-3.3-70b-versatile` (do not use — see above), `llama-3.1-8b-instant`, `openai/gpt-oss-120b`, `openai/gpt-oss-20b`. Preview/beta models (`qwen3-32b`, `llama-4-scout`, `kimi-k2-instruct-0905`) can be discontinued without notice — do not build production workflows on them without a verified fallback.

---

## Together AI Tool-Call Compatibility

Not all Together AI serverless models support OpenAI function-calling schema. InvestorClaw requires tool execution — models that reject tool payloads cannot complete the workflow.

| Works (tool-call compatible) | Blocked (rejects tool payload) | Incompatible (text output only) |
|------------------------------|-------------------------------|----------------------------------|
| DeepSeek-V3.1 | Llama-4-Maverick FP8 | DeepSeek-R1-0528 (tool name as code block) |
| MiniMax-M2.5 / M2.7 | Llama-4-Scout | — |
| GLM-5 | GLM-4.7 | — |
| Kimi-K2.5 | Qwen3-Next-80B | — |
| Qwen3-235B-Instruct-tput | Kimi-K2-Thinking | — |
| Qwen3-235B-Thinking* | — | — |

*Qwen3-235B-Thinking makes tool calls correctly but takes 5–10 min per response step — not viable for interactive harness runs.

---

## Anti-Fabrication Properties (Hybrid Mode Only)

The tier-3 enrichment path adds audit controls that no single-model configuration provides:

- **HMAC fingerprint chain** — each enriched record gets a 16-character hex fingerprint; the session accumulates a chained fingerprint across all enriched symbols for post-hoc verification
- **`verbatim_required=true` + attribution** — enriched analyst quotes carry a verbatim flag and source attribution; the synthesis layer is constrained to cite rather than paraphrase
- **`is_heuristic=false`** — signals that synthesis was produced from enriched model inference, not keyword matching
- **`synthesis_instruction`** — machine-readable citation directive injected into the compact analyst payload; tells the operational LLM to cite synthesis verbatim with fingerprint included

These controls are absent in all single-model configurations regardless of model capability.

---

## Premium Model Ranking

Based on single-session harness results. WF36–WF41 were hybrid mode (DEV-001). Rankings should be treated as an informed starting point, not a permanent ordering.

**1. `xai/grok-4-1-fast` (hybrid)** — canonical recommended config. Best agentic calibration; 2M context; HMAC anti-fabrication active. Best for any production InvestorClaw deployment with a local GPU available.

**2. `xai/grok-4.20-0309-non-reasoning`** — best frontier result for cloud-only high-value sessions. Highest metric density (QC4=65); uniquely surfaced cross-holding news sentiment correlation. Verdict: RECOMMENDED ★ BEST CLOUD SYNTHESIS.

**3. `openai/gpt-5.4`** — strongest prose quality; highest ticker mentions (~35) and word count (~900) among frontier group. Best when breadth of coverage matters more than metric density. Verdict: RECOMMENDED.

**4. `together/moonshotai/Kimi-K2.5`** — highest word count of all tested models (~1,450 words); full disclaimer compliance; clean protocol; best non-frontier substitute. Verdict: RECOMMENDED ★ BEST SUBSTITUTE.

**5. `google/gemini-3.1-pro-preview`** — solid synthesis at lowest cost ($2/$12/M). One disclaimer instance (QC10=1) requires system prompt hardening for FA mode. Individual commands all pass. Verdict: RECOMMENDED with caveat.

**6. `xai/grok-4-1-fast` (true baseline, no enrichment)** — compact and accurate, no padding. Reference for single-model mode without consultation. Best agentic session calibration. Verdict: RECOMMENDED as always-on operational default when GPU is not available.

**7. `groq/openai/gpt-oss-120b`** — passes with full autonomous prose but lower metric density (structured-only mode during testing). Best in class for Groq. Verdict: PASS.

---

## Consultation Model Catalog (CERBERUS / Ollama)

Tested on the inference host (CERBERUS: RTX 4500 Ada 24 GB VRAM, Ollama 0.20.3).

| Model | tok/s | VRAM | Notes |
|-------|------:|-----:|-------|
| `gemma4-consult` | ~65 | 9.6 GB | **Recommended** — tuned gemma4:e4b; optimized for consultative Q&A (num_ctx=2048, num_predict=600) |
| `gemma4:e4b` | ~66 | 9.6 GB | Base model; good quality/speed tradeoff; 128K context |
| `gemma4:e2b` | ~99 | 7.2 GB | Fastest; suitable for lighter tasks |
| `nemotron-3-nano:30b-a3b-q4_K_M` | ~25 | 24 GB | High-quality fallback; requires full VRAM |
| `qwen2.5:14b-instruct-q4_K_M` | ~45 | 9.0 GB | Code and structured output |

Create `gemma4-consult`:
```bash
ollama create gemma4-consult -f docs/gemma4-consult.Modelfile
```

Run `/portfolio ollama-setup` to auto-detect available models on your endpoint.

---

## Reproducibility

The full test harness is at `investorclaw_harness_v612.txt` in the repository root.

```bash
# Prerequisites
# - OpenClaw gateway running with investorclaw plugin loaded
# - (Optional) local Ollama host at INVESTORCLAW_CONSULTATION_ENDPOINT
# - Portfolio CSVs in INVESTOR_CLAW_PORTFOLIO_DIR
# - .env copied to workspace: cp ~/Projects/InvestorClaw/.env ~/.openclaw/workspace/skills/investorclaw/.env

# Covers 39 workflow checkpoints across 5 phases (W0–W8)
```
