#!/usr/bin/env bash
# InvestorClaw — openclaw installer (bundle-based, v2.6.3+)
#
# Three responsibilities openclaw needs glued together:
#   1) Install the audit-compliant skill bundle to ~/.openclaw/workspace/skills/
#   2) Configure the openai-compatible provider config so calls route to
#      the user's chosen LLM endpoint (Together / OpenAI / etc).
#      openclaw 4.29-beta.4+ ships a config-health daemon that detects raw
#      JSON writes lacking required schema fields (per-provider models[]) as
#      "reload-invalid-config", clobbers the file, and restores from
#      .last-good. We therefore drive every provider config write through the
#      validated `openclaw config patch` CLI. Env-var-only auth is still NOT
#      supported by openclaw (verified upstream RCA 2026-04-30:
#      `git log --all -S OPENAI_API_BASE` finds zero historical handlers).
#   3) Register the InvestorClaw plugin via `openclaw plugins install --link`
#      so the agent's tool list includes investorclaw.portfolio_ask etc.
#
# Env overrides:
#   IC_BUNDLE_TGZ            — path to local bundle tarball (default: auto-detect)
#   IC_BUNDLE_VERSION        — version (default: 2.6.3)
#   IC_VENV_DIR              — venv location (default: ~/.cache/investorclaw/.venv)
#   IC_PROVIDER_BASE_URL     — openai-compatible endpoint to route to
#                              (default: https://api.together.xyz/v1)
#   IC_PROVIDER_API_KEY      — auth token for that endpoint
#                              (default: $TOGETHER_API_KEY env var)
#   IC_PROVIDER_MODEL_ID     — model id at provider (default: MiniMaxAI/MiniMax-M2.7)
#   IC_PROVIDER_MODEL_NAME   — display name for that model (default: MiniMax M2.7)
#   IC_PROVIDER_API_ADAPTER  — openclaw API adapter (default: openai-completions —
#                              other valid: openai-responses, anthropic-messages,
#                              google-generative-ai, ollama, etc.)
#   IC_FORCE_PROVIDER_CONFIG=1 — overwrite existing provider config on this run
#   OPENCLAW_HOME            — openclaw config root (default: ~/.openclaw)
#   OPENCLAW_AGENT_ID        — which agent's auth store to write to (default: main)
#
# Copyright 2026 InvestorClaw Contributors. Apache-2.0.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}→${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
die()  { err "$*"; exit 1; }

VERSION="${IC_BUNDLE_VERSION:-2.6.3}"
BUNDLE_NAME="investorclaw-skill-${VERSION}"
OC_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
AGENT_ID="${OPENCLAW_AGENT_ID:-main}"
SKILL_DIR="$OC_HOME/workspace/skills/investorclaw"
VENV_DIR="${IC_VENV_DIR:-$HOME/.cache/investorclaw/.venv}"
BIN_LINK="$HOME/.local/bin/investorclaw"
OC_CONFIG="$OC_HOME/openclaw.json"
AUTH_STORE="$OC_HOME/agents/$AGENT_ID/agent/auth-profiles.json"

PROVIDER_BASE_URL="${IC_PROVIDER_BASE_URL:-https://api.together.xyz/v1}"
PROVIDER_API_KEY="${IC_PROVIDER_API_KEY:-${TOGETHER_API_KEY:-}}"
PROVIDER_MODEL_ID="${IC_PROVIDER_MODEL_ID:-MiniMaxAI/MiniMax-M2.7}"
PROVIDER_MODEL_NAME="${IC_PROVIDER_MODEL_NAME:-MiniMax M2.7}"
PROVIDER_API_ADAPTER="${IC_PROVIDER_API_ADAPTER:-openai-completions}"

[ -n "$PROVIDER_API_KEY" ] || die "IC_PROVIDER_API_KEY (or \$TOGETHER_API_KEY) must be set"

log "InvestorClaw v${VERSION} — openclaw installer (bundle-based)"

command -v openclaw >/dev/null 2>&1 || die "openclaw CLI not found in PATH. Install openclaw first."
ok "openclaw: $(openclaw --version 2>&1 | head -1)"

command -v uv >/dev/null 2>&1 || die "uv not found in PATH. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
ok "uv: $(uv --version 2>&1 | head -1)"

BUNDLE_TGZ="${IC_BUNDLE_TGZ:-}"
if [ -z "$BUNDLE_TGZ" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [ -f "$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz" ]; then
        BUNDLE_TGZ="$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz"
    elif [ -f "$REPO_ROOT/Makefile" ] && [ -f "$REPO_ROOT/scripts/build_skill_bundle.py" ]; then
        log "no prebuilt bundle — building via 'make skill-bundle'"
        (cd "$REPO_ROOT" && make skill-bundle >/dev/null) || die "make skill-bundle failed"
        BUNDLE_TGZ="$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz"
    fi
fi
[ -f "$BUNDLE_TGZ" ] || die "bundle not found: \$IC_BUNDLE_TGZ"
ok "bundle: $BUNDLE_TGZ"

log "extracting to $SKILL_DIR..."
mkdir -p "$OC_HOME/workspace/skills"
rm -rf "$SKILL_DIR" "$OC_HOME/workspace/skills/${BUNDLE_NAME}"
tar -xzf "$BUNDLE_TGZ" -C "$OC_HOME/workspace/skills"
mv "$OC_HOME/workspace/skills/${BUNDLE_NAME}" "$SKILL_DIR"
ok "extracted ($(find "$SKILL_DIR" -type f | wc -l | tr -d ' ') files)"

# Backstop for bundles built before openclaw.plugin.json was added to the
# whitelist (pre-2.6.3). openclaw 4.29-beta.4 refuses to register a plugin
# without this manifest; we synthesize a minimal one if absent.
if [ ! -f "$SKILL_DIR/openclaw.plugin.json" ]; then
    warn "bundle missing openclaw.plugin.json — synthesizing minimal manifest (upgrade bundle to v2.6.3+ to ship one)"
    cat > "$SKILL_DIR/openclaw.plugin.json" <<MANIFEST
{
  "id": "investorclaw",
  "name": "InvestorClaw",
  "description": "Portfolio analysis tools for OpenClaw agents (FINOS CDM 5.x)",
  "version": "${VERSION}",
  "activation": { "onStartup": false },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "enabled": { "type": "boolean" }
    }
  }
}
MANIFEST
fi

log "creating ic-engine venv at $VENV_DIR..."
mkdir -p "$(dirname "$VENV_DIR")"
(cd "$SKILL_DIR" && UV_PROJECT_ENVIRONMENT="$VENV_DIR" uv sync --python 3.12 >/dev/null 2>&1) \
    || die "uv sync failed in $SKILL_DIR"
ok "venv ready"

mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$VENV_DIR/bin/investorclaw" "$BIN_LINK"
ok "symlinked $BIN_LINK"

if [ -f "$SKILL_DIR/package.json" ] && command -v npm >/dev/null 2>&1; then
    log "npm install for plugin runtime deps (typebox etc)..."
    (cd "$SKILL_DIR" && npm install --silent --no-audit --no-fund 2>&1 | tail -2) || \
        warn "npm install hit issues — plugin may fail to load"
fi

log "preflight check on existing openclaw configuration..."
mkdir -p "$OC_HOME"

# openclaw 4.29-beta.4+ has a config-health daemon that detects raw JSON writes
# missing required schema fields (per-provider models[]) as "reload-invalid-config",
# clobbers them, and restores from .last-good. We therefore drive all writes through
# the validated `openclaw config patch` CLI which guarantees schema conformance.

EXISTING_BASEURL="$(openclaw config get models.providers.openai.baseUrl 2>/dev/null || true)"
EXISTING_APIKEY="$(openclaw config get models.providers.openai.apiKey 2>/dev/null || true)"
EXISTING_MODELS_JSON="$(openclaw config get models.providers.openai.models 2>/dev/null || true)"
EXISTING_AGENT_MODEL="$(openclaw config get agents.defaults.model 2>/dev/null || true)"
EXISTING_MODE="$(openclaw config get models.mode 2>/dev/null || true)"

echo ""
echo "  ┌─ openclaw configuration preflight ─────────────────────────────"
echo "  │ openclaw config: $(openclaw config file 2>/dev/null || echo "$OC_CONFIG")"
if [ -n "$EXISTING_BASEURL" ]; then
    echo "  │   models.providers.openai.baseUrl = $EXISTING_BASEURL"
    [ "$EXISTING_BASEURL" != "$PROVIDER_BASE_URL" ] && \
        echo "  │     (installer suggests:        $PROVIDER_BASE_URL — preserved unless IC_FORCE_PROVIDER_CONFIG=1)"
else
    echo "  │   models.providers.openai.baseUrl = (unset — will set to $PROVIDER_BASE_URL)"
fi
if [ -n "$EXISTING_APIKEY" ]; then
    echo "  │   models.providers.openai.apiKey  = (set, preserved unless IC_FORCE_PROVIDER_CONFIG=1)"
else
    echo "  │   models.providers.openai.apiKey  = (unset — will set from \$TOGETHER_API_KEY)"
fi
if [ -n "$EXISTING_MODELS_JSON" ] && [ "$EXISTING_MODELS_JSON" != "[]" ]; then
    echo "  │   models.providers.openai.models  = (configured, preserved)"
else
    echo "  │   models.providers.openai.models  = (unset — will set [{$PROVIDER_MODEL_ID, $PROVIDER_MODEL_NAME}])"
fi
echo "  │   models.mode                     = ${EXISTING_MODE:-(unset — will set to replace)}"
echo "  │   agents.defaults.model           = ${EXISTING_AGENT_MODEL:-(unset — will set to openai/$PROVIDER_MODEL_ID)}"
echo "  └─────────────────────────────────────────────────────────────────"
echo ""

FORCE="${IC_FORCE_PROVIDER_CONFIG:-0}"

# Build incremental JSON5 patch — only set fields that are missing (or all if --force).
PATCH_FILE="$(mktemp -t ic-openclaw-patch.XXXXXX.json5)"
trap 'rm -f "$PATCH_FILE"' EXIT

PATCH_BODY=""
add_field() {
    [ -n "$PATCH_BODY" ] && PATCH_BODY="${PATCH_BODY},
"
    PATCH_BODY="${PATCH_BODY}        $1"
}

if [ -z "$EXISTING_BASEURL" ] || [ "$FORCE" = "1" ]; then
    add_field "\"baseUrl\": \"$PROVIDER_BASE_URL\""
fi
if [ -z "$EXISTING_APIKEY" ] || [ "$FORCE" = "1" ]; then
    add_field "\"apiKey\": \"$PROVIDER_API_KEY\""
fi
if [ -z "$EXISTING_MODELS_JSON" ] || [ "$EXISTING_MODELS_JSON" = "[]" ] || [ "$FORCE" = "1" ]; then
    add_field "\"models\": [{ \"id\": \"$PROVIDER_MODEL_ID\", \"name\": \"$PROVIDER_MODEL_NAME\" }]"
fi
# auth + api adapter are required for openai-compatible providers; safe to always set.
add_field "\"auth\": \"api-key\""
add_field "\"api\": \"$PROVIDER_API_ADAPTER\""

cat > "$PATCH_FILE" <<JSON
{
  "models": {
    "providers": {
      "openai": {
$PATCH_BODY
      }
    }
  }
}
JSON

log "validating patch (dry-run)..."
if openclaw config patch --file "$PATCH_FILE" --dry-run 2>&1 | tail -5 | grep -q "Dry run successful"; then
    ok "patch validates against openclaw schema"
else
    err "patch failed validation:"
    openclaw config patch --file "$PATCH_FILE" --dry-run 2>&1 | tail -20
    die "schema validation failed — refusing to apply"
fi

log "applying patch..."
openclaw config patch --file "$PATCH_FILE" 2>&1 | tail -3 | grep -E "(Applied|Restart)" || true
ok "config patched"

# Set agent default model + replace-mode (so embedded fallback uses our provider).
if [ -z "$EXISTING_MODE" ] || [ "$FORCE" = "1" ]; then
    openclaw config set models.mode replace 2>&1 | tail -2 | grep -v "^$" || true
fi
if [ -z "$EXISTING_AGENT_MODEL" ] || [ "$FORCE" = "1" ]; then
    openclaw config set agents.defaults.model "openai/$PROVIDER_MODEL_ID" 2>&1 | tail -2 | grep -v "^$" || true
fi

# openclaw 4.29-beta.4+ ships a workspace-bootstrap workflow (BOOTSTRAP.md +
# IDENTITY.md + USER.md templates the LLM is instructed to fill in interactively
# on first contact). For deterministic non-interactive use (cron, barrage,
# automated tooling) this loops the agent indefinitely on "who am I?" prompts.
# Seed the workspace files with COMPLETED content so the agent skips onboarding.
WORKSPACE_DIR="$OC_HOME/workspace"
if [ ! -f "$WORKSPACE_DIR/BOOTSTRAP.md" ] || ! grep -q "^Status: COMPLETE" "$WORKSPACE_DIR/BOOTSTRAP.md" 2>/dev/null; then
    log "seeding workspace bootstrap files (IDENTITY.md + USER.md + BOOTSTRAP.md)..."
    mkdir -p "$WORKSPACE_DIR"
    cat > "$WORKSPACE_DIR/IDENTITY.md" <<'IDMD'
# IDENTITY.md - Who Am I?

- **Name:** InvestorClaw
- **Creature:** AI portfolio analyst (deterministic-first via investorclaw skill)
- **Vibe:** terse, factual, financial-analysis-focused
- **Emoji:** 📊
- **Avatar:** (none)

Bootstrap COMPLETE. Do not ask the operator for identity again. Use the
investorclaw skill tools to answer all portfolio questions.
IDMD
    cat > "$WORKSPACE_DIR/USER.md" <<'USRMD'
# USER.md - Who Is My Operator?

- **Name:** Operator
- **Timezone:** UTC
- **Communication:** webchat (one-shot prompts)

Bootstrap COMPLETE. Treat all incoming prompts as one-shot questions about the
configured portfolio. Respond directly using investorclaw tools.
USRMD
    cat > "$WORKSPACE_DIR/BOOTSTRAP.md" <<'BTMD'
# Bootstrap

Status: COMPLETE
IdentityFile: IDENTITY.md (filled)
UserFile: USER.md (filled)

Do NOT ask the operator for identity, name, timezone, or vibe. Bootstrap is
finished. Answer questions directly using the investorclaw skill tools.
BTMD
    ok "bootstrap files seeded"
fi

if openclaw config validate 2>&1 | grep -q "Config valid"; then
    ok "openclaw config valid"
else
    warn "openclaw config validate reported issues — review with: openclaw config validate"
fi

# Note: auth-profiles.json is no longer required as of openclaw 4.29-beta.4 —
# provider apiKey on models.providers.openai.apiKey is the canonical auth path
# and is wired through the gateway's embedded fallback.

log "registering skill plugin with openclaw..."
if openclaw plugins install --link "$SKILL_DIR" 2>&1 | tail -3 | grep -q "Linked plugin"; then
    ok "plugin registered"
else
    warn "plugin registration may have failed — review with: openclaw plugins list"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  InvestorClaw v${VERSION} — installed for openclaw                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Skill dir:     $SKILL_DIR"
echo "  Venv:          $VENV_DIR"
echo "  CLI:           $BIN_LINK"
echo "  openclaw.json: $OC_CONFIG"
echo "  auth-profiles: $AUTH_STORE"
echo ""
echo "  Provider routing:"
echo "    openai → $PROVIDER_BASE_URL"
echo ""
echo "  Try it (will use the openai provider as configured):"
echo "    openclaw agent --to +17777777710 --message \"What is in my portfolio?\""
