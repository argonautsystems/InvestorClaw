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

## OC-1 — openclaw provider config requires `models.providers.openai.baseUrl` (not env vars)

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

**Confirmed broken in:** v2026.3.25, v2026.4.26, v2026.4.27, v2026.4.29-beta.3.
All these versions have the same architectural design — env-var-only auth
isn't supported.

**Resolution (in `installers/openclaw/install.sh`):** The installer auto-writes:
1. `~/.openclaw/openclaw.json` — `models.providers.openai.baseUrl` + `apiKey`
2. `~/.openclaw/agents/<id>/agent/auth-profiles.json` — `ApiKeyCredential` for `openai` provider

Default routing target: Together AI (`https://api.together.xyz/v1`). Override via
`IC_PROVIDER_BASE_URL` and `IC_PROVIDER_API_KEY` env vars at install time.

**Preflight UX (2026-04-30):** The installer detects existing config state and
preserves user customizations — only patches missing fields. `IC_FORCE_PROVIDER_CONFIG=1`
to override.

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
