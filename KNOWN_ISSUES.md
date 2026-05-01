# Known Issues — InvestorClaw v2.6.3

**Released:** 2026-04-30  
**Sync:** ic-engine v2.6.3, InvestorClaw v2.6.3, InvestorClaude v2.6.3

This release ships the architectural fix for InvestorClaw skill execution
in agent runtimes (zeroclaw, openclaw, hermes) — the audit-compliant skill
bundle (`build/investorclaw-skill-2.6.3.tar.gz`), build pipeline
(`make skill-bundle`), runtime installers (`installers/<runtime>/install.sh`),
and ic-engine cold-cache fix (`auto_bootstrap_holdings`).

These known issues do not block the architecture but operators should be
aware of them.

---

## ZER-1 — zeroclaw 0.7.3 default config blocks skill tool execution

**Symptom:** After installing the skill, the LLM sees `investorclaw.portfolio_ask`
and chooses to invoke it, but execution is denied with "blocked by security
policy."

**Cause:** Three default-zeroclaw autonomy gates:
1. `autonomy.forbidden_paths` includes `/home`, which contains the skill
   directory (`/home/$USER/.zeroclaw/workspace/skills/investorclaw/`).
2. `autonomy.auto_approve` does NOT include `investorclaw.*`, so the
   LLM's tool invocation requires interactive approval (which fails
   non-interactively).
3. `autonomy.allowed_commands` does NOT include `investorclaw`, blocking
   any shell-tool fallback the LLM might attempt.

**Fix:** Run `installers/zeroclaw/install.sh`. The installer auto-patches
all three gates idempotently. Manual fix: edit `~/.zeroclaw/config.toml`:
- `autonomy.forbidden_paths` — remove `/home` and `/opt`
- `autonomy.auto_approve` — append `"investorclaw.portfolio_ask"`, `"investorclaw.portfolio_refresh"`
- `autonomy.allowed_commands` — append `"investorclaw"`, `"uv"`, `"sh"`
- `skills.allow_scripts = true`

**Upstream resolution:** zeroclaw HEAD has in-flight PRs (per repo owner
2026-04-30) that may relax these gates for skill-registered tools.

---

## OC-1 — openclaw provider config requires `models.providers.openai.{baseUrl,models[]}` (not env vars), validated via `openclaw config patch`

**Symptom:** `docker run -e OPENAI_API_KEY=tgp_v1_... -e OPENAI_API_BASE=https://api.together.xyz/v1 openclaw/openclaw:<any-version>`
then `openclaw agent ...` fails with `401 Incorrect API key provided` from
`api.openai.com` — the gateway routes the Together token to OpenAI's
upstream because it never reads `OPENAI_API_BASE`/`OPENAI_BASE_URL`.

**RCA finding (2026-04-30):** This is **NOT a regression** — `git log --all -S OPENAI_API_BASE`
on openclaw upstream finds **zero historical handlers** for that env var. The
codebase always reads provider baseUrl from `models.providers.<name>.baseUrl`
(in `~/.openclaw/openclaw.json`). The "Linux baseline that worked" was
because the `perlowja/openclaw-demo` private image pre-configured
`models.providers.openai.baseUrl = https://api.together.xyz/v1` in its
shipped openclaw.json. We assumed env-var routing existed because we never
actually tested env-var-only on a clean openclaw install.

**Schema-validation finding (2026-04-30, openclaw v2026.4.29-beta.4):** Even
the canonical `models.providers.openai.{baseUrl,apiKey}` write does **not**
survive on 4.29-beta.4 if attempted as a raw JSON file write. openclaw ships a
config-health daemon that, on every gateway-reload of `openclaw.json`,
re-validates against the JSON schema. If the file is missing schema-required
fields it flags it `"suspicious":["reload-invalid-config"]`, moves the file
aside as `openclaw.json.clobbered.<ts>`, and restores from
`openclaw.json.last-good`. Required fields per `openclaw config schema`:
- `models.providers.<name>.baseUrl` (URL string)
- `models.providers.<name>.models` (array of `{id, name}` entries — at least one)

Optional but commonly required for OpenAI-compatible providers:
- `auth: "api-key"` (enum: api-key, token, oauth, aws-sdk)
- `api: "openai-completions"` (enum incl. openai-responses, anthropic-messages,
  google-generative-ai, ollama, etc.)

**Resolution (in `installers/openclaw/install.sh`):** All config writes go
through `openclaw config patch --file <patch.json5>` (the validated CLI path),
never `cat > openclaw.json`. The installer:
1. Reads existing config via `openclaw config get` (preflight)
2. Builds an incremental JSON5 patch with only fields that need setting
3. `openclaw config patch --dry-run` to validate before write
4. `openclaw config patch` to apply (rejected by validator if invalid)
5. `openclaw config set agents.defaults.model openai/<MODEL_ID>` so the gateway
   has a default and callers don't need `--model`
6. `openclaw config set models.mode replace` so embedded fallback uses our
   provider catalog (otherwise it merges in built-in `gpt-5.5` as default)

Default routing target: Together AI (`https://api.together.xyz/v1`) with model
`MiniMaxAI/MiniMax-M2.7`. Override at install time via `IC_PROVIDER_BASE_URL`,
`IC_PROVIDER_API_KEY`, `IC_PROVIDER_MODEL_ID`, `IC_PROVIDER_MODEL_NAME`,
`IC_PROVIDER_API_ADAPTER`.

**Preflight UX (2026-04-30):** The installer detects existing config state and
preserves user customizations — only patches missing fields. `IC_FORCE_PROVIDER_CONFIG=1`
to override.

**Plugin manifest finding (2026-04-30, openclaw v2026.4.29-beta.4):** In addition
to the provider config schema, openclaw 4.29-beta.4 also requires the plugin
manifest itself to follow the new `openclaw.plugin.json` format with proper
JSON-Schema-style `configSchema` (`{type: "object", additionalProperties: false,
properties: {...}}`). The legacy InvestorClaw manifest stored field metadata
(`label`, `description`, `secret`, `default`) inline next to each property,
which 4.29-beta.4 rejects as "plugin manifest requires configSchema". Required
fields in the manifest:
- `id`, `name`, `description`, `version`
- `activation: {onStartup: bool}`
- `configSchema: {type: "object", properties: {...}}`

UI metadata moves to a separate top-level `uiHints: {<KEY>: {label, help, sensitive,
placeholder}}` block. The installer/bundle ships `openclaw.plugin.json` at the
skill root; the bundle build pipeline includes it via WHITELIST_TOP_LEVEL.

**Workspace bootstrap loop finding (2026-04-30, openclaw v2026.4.29-beta.4):**
openclaw 4.29-beta.4 ships a workspace-bootstrap workflow at
`~/.openclaw/workspace/{BOOTSTRAP,IDENTITY,USER}.md`. On first contact, the
gateway agent's system prompt directs the LLM to ask the operator for name /
timezone / persona / emoji and refuse to do anything else (including calling
configured tools) until the bootstrap is "complete." `agents.defaults.skipBootstrap=true`
does NOT bypass it — the bootstrap content is injected via workspace files,
not the config flag. For non-interactive automation (cron, barrage harness,
etc.) the bootstrap loops indefinitely on "Who am I? Who are you?" prompts.

**Resolution:** The installer now seeds those three workspace files with
COMPLETED content (`Status: COMPLETE`, identity = `InvestorClaw`, user =
`Operator`). The LLM picks up the seeded files on next gateway reload and
proceeds to tool calls instead of onboarding chat.

**Verified working on:** v2026.4.29-beta.4 (TYPHON Windows-WSL Debian Docker,
2026-04-30): real `MiniMax M2.7` response over Together via gateway path with
no `--model` override; investorclaw plugin loaded with all 15 tools registered
(`investorclaw_setup`, `_holdings`, `_performance`, `_analysis`, `_bonds`,
`_fixed_income`, `_news`, `_analyst`, `_report`, `_session`, `_lookup`,
`_ollama_setup`, `_guardrails`, `_update_identity`, `_stonkmode`); after
seeding bootstrap, agent ran `investorclaw_setup` and reported "ready_for_analysis: Yes"
when a portfolio xls was present in `portfolios/`.

**Confirmed broken with raw JSON write on:** v2026.3.25, v2026.4.26, v2026.4.27,
v2026.4.29-beta.3, v2026.4.29-beta.4 (only beta.4 has the active config-health
auto-revert daemon — earlier versions silently kept the invalid config but
the gateway didn't pick it up).

**Upstream feature request opportunity (low priority):** A follow-up issue could
propose `OPENAI_API_BASE` env var as a fallback when `models.providers.openai.baseUrl`
is unset — would match OpenAI SDK / litellm / Together CLI conventions. Not
on v2.6.3's critical path since the config-based approach works now.

---

## HER-1 — hermes skill-as-tool indirection

**Symptom:** Hermes lists InvestorClaw under "Available Skills" but its
LLM tool list (28 tools: browser_*, terminal, skill_view, skill_manage,
skills_list, etc.) does NOT directly expose `investorclaw.portfolio_ask`.

**Cause:** Hermes treats skills as documentation hints injected into
system prompt rather than as directly-callable tools (different
architecture from zeroclaw 0.7.3's tool registration). The LLM has to
opt into using the skill via meta-tools (`skill_view`, `terminal`).

**Implication:** Bundle installs cleanly into hermes but invocation
reliability depends on the LLM's compliance with meta-tool indirection.
Empirically (Linux baseline 2026-04-29) hermes scored 8% (2.3/30) vs
zeroclaw's 77% (23/30) on the same prompt set.

**Path forward:** Architectural — hermes maintainers would need to
expose skill-registered tools as first-class function-calling targets.
This is the InvestorClaude (Claude Code) pattern: hardcoded slash
commands bypass LLM tool-discovery entirely.

---

## IC-1 — `investorclaw --version` reports "2.5.1" inside the bundle

**Symptom:** `investorclaw --version` prints `investorclaw 2.5.1` even
though the installed ic-engine is 2.6.3 (the cold-cache fix).

**Cause:** Cosmetic — `version.py` reads from a hardcoded constant
that wasn't bumped during the v2.6.3 sync. Does NOT affect functionality.

**Fix scope:** Trivial (single-line bump). Will land in the next
patch. ic-engine actual version is correct: `python -c 'from importlib.metadata import version; print(version("ic-engine"))'` returns `2.6.3`.

---

## Sync-release policy

Per `feedback_sync_releases_3pkg.md`: ic-engine v2.6.3, InvestorClaw v2.6.3,
InvestorClaude v2.6.3 ship together. Each tag is backed by ≥1 substantive
PR per the sync-release policy:
- ic-engine: cold-cache cascade fix in ask.py + auto_bootstrap_holdings public API + 7 regression tests + portability fixes
- InvestorClaw: audit-compliant skill bundle build pipeline + zeroclaw installer with auto-config + content sanitization for zeroclaw audit
- InvestorClaude: pin update to ic-engine v2.6.3 (delivers cold-cache fix to Claude Code users)
