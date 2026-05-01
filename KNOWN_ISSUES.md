# Known Issues — InvestorClaw v2.6.3

**Status:** v2.6.3 claws-stack install paths pulled 2026-05-01. See below.

---

## v2.6.3 status (effective 2026-05-01)

The skill-bundle install paths for **zeroclaw, openclaw, and hermes** have
been **withdrawn** from this repository. They are *not* shipped as part
of v2.6.3.

**Why:** empirical N=1 testing on TYPHON Windows-WSL Docker (2026-04-30)
showed all three install paths fail to deliver working portfolio analysis:

| Runtime | v2.6.3 result | v2.5.0 Linux baseline | Status |
|---|---|---|---|
| openclaw 4.29-beta.4 | 21/30 (70%) | 26/30 (86%) | regression — pulled |
| zeroclaw 0.7.x | 6/30 (20%) | not run | broken — pulled |
| hermes 0.12 | 6/30 (20%) | 23/30 (76%) | regression — pulled |

The failures are install-time friction, not analytical bugs in
`ic-engine`. Each agent runtime ships frequent breaking changes
(openclaw config-health daemon, zeroclaw `[mcp]` config schema, hermes
container PATH conventions, etc.) that the skill-bundle install model
can't keep up with at fleet scale.

**Resolution:** v4.x application-service architecture (containerized
service every agent connects to via MCP-HTTP). Replaces the install
pattern entirely. See the v4.0 RFC at
`mnemos-os/mnemos-ic-runtime/RFC-v0.1.md`.

## What still works in v2.6.3

| Path | Status |
|---|---|
| **InvestorClaude (Claude Code marketplace plugin)** | Works. In Anthropic marketplace review as of 2026-04-30. Continues independent development — v2.6.4, v2.7, etc. via marketplace updates. |
| **Claude Desktop config-snippet path** | Works (manual edit of `claude_desktop_config.json`). |
| **Standalone Python CLI** (`installers/standalone/install.sh`) | Works. No agent runtime, just a Python CLI install. |
| **`ic-engine` analytical core** | Works. Pinned to `ic-engine` v2.6.3 (cold-cache cascade fix, `auto_bootstrap_holdings`, 7 regression tests). |

## Migration path for current claws users

If you have a working v2.5.x or v2.6.0 InvestorClaw + claws install:

- **Stay there.** v2.6.3 doesn't deliver a working upgrade for claws
  paths. v4.x is in active development.
- **Don't update agent runtimes.** Each new openclaw / zeroclaw / hermes
  release tends to break v2.x install paths in a new way; staying on
  the runtime version that worked at install time keeps you running.
- **Migrate to v4.x when it ships.** The `mnemos-os/mnemos-ic-runtime`
  service lets you switch agent runtimes (or run multiple) without
  re-installing InvestorClaw.

If you're new and looking to install:

- **Use Claude Code (marketplace plugin) or Claude Desktop** for the
  Claude path — works today.
- **Use `installers/standalone/install.sh`** for the no-agent CLI path
  — works today.
- **Wait for v4.x** if you want claws-stack integration.

## Historical RCA (for context — install paths now pulled)

The following issues motivated the v4.0 pivot. The install paths
themselves are no longer shipped, so these are reference for v4.x
design, not workaround docs.

- **OC-1** — openclaw 4.29-beta.4 ships an active config-health daemon
  that detects raw JSON writes lacking required schema fields
  (per-provider `models[]`) as `reload-invalid-config`, clobbers them,
  and restores from `.last-good`. Plus a new `openclaw.plugin.json`
  manifest schema (JSON-Schema `configSchema` with `activation`).
  v4.0 sidesteps both — no plugin manifest, no provider config writes;
  the agent just registers an MCP server URL.

- **ZER-1** — zeroclaw 0.7.3 default `autonomy.forbidden_paths`,
  `autonomy.auto_approve`, `autonomy.allowed_commands`, and
  `skills.allow_scripts` all blocked the v2.x skill bundle from
  executing. v2.x installer auto-patched these gates; v4.0 doesn't
  need any of them since the agent-side artifact is a documentation
  file plus an MCP server URL.

- **HER-1** — hermes treats skill files as documentation hints injected
  into the LLM system prompt, not as first-class callable tools. v2.x
  hermes integration scored ~8% on Linux baseline due to this
  meta-tool indirection. v4.0 eliminates the issue entirely — hermes
  registers an MCP server, and `mcp_servers.investorclaw.*` tools
  become first-class function-callable, identical to the other
  runtimes.

- **IC-1** — cosmetic — `investorclaw --version` reports `2.5.1`
  instead of the actual `2.6.3`. Trivial single-line bump; lives in
  the standalone CLI path which still ships.

## Cross-references

- `RFC-v0.1.md` in `mnemos-os/mnemos-ic-runtime` — v4.0 architecture document
- `CHANGELOG.md` — v2.6.3 release notes including the pull
- `installers/standalone/install.sh` — the still-working CLI install
