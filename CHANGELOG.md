# Changelog

## v2.6.3 — 2026-04-30 (final 2.x ship)

The 2.x branch is frozen for development. Only security backports going
forward. Future development continues on v4.x (containerized application
service architecture). The v3.x track continues independently as the
enterprise/compliance tier on the v2.x architecture.

**openclaw 4.29-beta.4 schema fixes** (commits `08b7376`, `eb2c901`) —
openclaw 4.29-beta.4 ships an active config-health daemon that detects
raw JSON writes lacking required schema fields (per-provider `models[]`)
as `reload-invalid-config`, clobbers them, and restores from
`.last-good`. The v2.6.3 installer now drives every config write through
the validated `openclaw config patch --file` CLI; ships the plugin
manifest in the new JSON-Schema `configSchema` format with `activation`
field; seeds the workspace `BOOTSTRAP.md` / `IDENTITY.md` / `USER.md`
files with `Status: COMPLETE` to bypass the new onboarding loop in
headless deployments. End-to-end verified on TYPHON Windows-WSL Debian
Docker: real `MiniMax M2.7` response over Together via gateway path with
no `--model` override, all 15 InvestorClaw tools registered.

**`investorclaw.py` shim added to skill bundle** — the single-file CLI
shim declared in `pyproject.toml`'s `py-modules` was missing from the
bundle whitelist; without it, `uv sync` produced an editable install
that failed import with `ModuleNotFoundError: No module named 'investorclaw'`.

**Audit-compliant skill bundle pipeline** — `make skill-bundle` produces
a whitelist-filtered tarball at `build/investorclaw-skill-2.6.3.tar.gz`
that passes zeroclaw's skill audit (no scripts, no symlinks, no
curl-pipe-shell patterns, no remote markdown links). Installer scripts
moved to `installers/<runtime>/install.sh` (zeroclaw, openclaw, hermes)
and ship outside the bundle.

**ic-engine cold-cache cascade fix** (ic-engine v2.6.3, pinned via
`uv.lock`) — `HoldingsLoader.load` was JSON-parsing CSV files on cold
cache; cascade now correctly auto-bootstraps holdings via
`auto_bootstrap_holdings(...)` in `commands/ask.py`. 7 regression tests
added.

**`KNOWN_ISSUES.md` introduced** with operator-facing caveats:
ZER-1 (zeroclaw default autonomy gates block skill execution; auto-patched
by installer), OC-1 (openclaw provider auth requires
`models.providers.openai.{baseUrl,models[]}` and validated config-patch
write path; never via env vars), HER-1 (hermes skill-as-tool indirection;
empirical reliability gap), IC-1 (cosmetic `--version` reports `2.5.1`).

**Other portability fixes** — `INVESTOR_CLAW_REPORTS_DIR` defaults to
`tempfile.gettempdir()` instead of hard-coded `/tmp/`; openclaw installer
no longer assumes `/opt/openclaw`.

## v2.6.2 — 2026-04-29

- ic-engine pin update to v2.6.2 — `uv` (not `pip`) is the canonical
  install path on PEP 668 systems. Both projects' Python toolchain is
  the uv-managed Python; `pip install` against system Python fails by
  design on Debian/Ubuntu 23.04+.

## v2.6.1 — 2026-04-29

- ic-engine pin update to v2.6.1 — adds `auto_bootstrap_holdings` public
  API with `portfolio_path` parameter; subprocess failures during
  bootstrap log at WARNING (not silently swallowed at DEBUG).

## v2.6.0 — 2026-04-28

- Security: removed internal infrastructure identifiers from commit
  history via git filter-repo. v2.5.1 retroactively superseded —
  please update local clones via fresh clone or
  `git fetch && git reset --hard origin/main`.

## v2.5.1

- Superseded by v2.6.0.
