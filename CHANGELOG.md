# Changelog

## v4.0.0 - 2026-05-04

**Architecture rewrite — repo trimmed to v4.x distribution shell.**

The InvestorClaw repository is now a thin distribution shell. Engine source
of truth has moved to dedicated substrate repositories:

- Engine math + analyzers: `argonautsystems/ic-engine`
- AI primitives: `argonautsystems/clio`
- Runtime + ClawHub-publishable SKILL.md: `mnemos-os/mnemos-ic-runtime`

What this repo now contains: README pointing at the substrates, a slim
SKILL.md, the cobol regression harness, and project-level docs. Everything
else (Python runtime, TypeScript plugin shim, per-runtime install paths,
v2.6 architecture docs, branding assets) has been removed from `main`.

The v2.6.3 git tag preserves the legacy install path for anyone who needs
it. New users should follow the v4.x dockerized-skill convention:

```bash
docker compose -f https://raw.githubusercontent.com/mnemos-os/mnemos-ic-runtime/main/compose.yml up -d
```

Image is publicly hosted at `ghcr.io/perlowja/ic-engine:4.1.17-cpu`. Agent
connects via MCP-HTTP at `http://localhost:18090/mcp`.

Cobol regression on the baked v4.1.17 image: 245-249/250 (98-99%).

License: distribution shell stays Apache 2.0; the SKILL.md and other
distribution-edge artifacts are MIT-0 (no attribution required) for ClawHub
re-host compatibility.

## v2.6.0 - 2026-04-28

- Security: removed internal infrastructure identifiers from commit history via git filter-repo. v2.5.1 retroactively superseded — please update local clones via fresh clone or git fetch && git reset --hard origin/main.

## v2.5.1

- Superseded by v2.6.0.
