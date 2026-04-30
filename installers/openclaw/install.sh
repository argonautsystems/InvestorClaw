#!/usr/bin/env bash
# InvestorClaw — openclaw installer (bundle-based, v2.6.3+)
#
# Three responsibilities openclaw needs glued together:
#   1) Install the audit-compliant skill bundle to ~/.openclaw/workspace/skills/
#   2) Configure the openai-compatible provider config so calls route to
#      the user's chosen LLM endpoint (Together / OpenAI / etc).
#      openclaw reads `models.providers.openai.baseUrl` from openclaw.json
#      and the API key from auth-profiles.json — env-var-only auth is
#      NOT supported by openclaw (verified upstream RCA 2026-04-30:
#      `git log --all -S OPENAI_API_BASE` finds zero historical handlers).
#   3) Register the InvestorClaw plugin via `openclaw plugins install --link`
#      so the agent's tool list includes investorclaw.portfolio_ask etc.
#
# Env overrides:
#   IC_BUNDLE_TGZ        — path to local bundle tarball (default: auto-detect)
#   IC_BUNDLE_VERSION    — version (default: 2.6.3)
#   IC_VENV_DIR          — venv location (default: ~/.cache/investorclaw/.venv)
#   IC_PROVIDER_BASE_URL — openai-compatible endpoint to route to
#                          (default: https://api.together.xyz/v1)
#   IC_PROVIDER_API_KEY  — auth token for that endpoint
#                          (default: $TOGETHER_API_KEY env var)
#   OPENCLAW_HOME        — openclaw config root (default: ~/.openclaw)
#   OPENCLAW_AGENT_ID    — which agent's auth store to write to (default: main)
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

log "patching $OC_CONFIG..."
mkdir -p "$OC_HOME"
if [ ! -f "$OC_CONFIG" ]; then
    echo '{}' > "$OC_CONFIG"
fi

OC_CONFIG="$OC_CONFIG" PROVIDER_BASE_URL="$PROVIDER_BASE_URL" PROVIDER_API_KEY="$PROVIDER_API_KEY" python3 <<'PYEOF'
import json, os
path = os.environ['OC_CONFIG']
base_url = os.environ['PROVIDER_BASE_URL']
api_key = os.environ['PROVIDER_API_KEY']

try:
    config = json.load(open(path))
except (json.JSONDecodeError, FileNotFoundError):
    config = {}

models = config.setdefault('models', {})
providers = models.setdefault('providers', {})
openai_provider = providers.setdefault('openai', {})
openai_provider['baseUrl'] = base_url
openai_provider['apiKey'] = api_key

json.dump(config, open(path, 'w'), indent=2)
print(f"openclaw.json: providers.openai.baseUrl = {base_url}")
PYEOF
ok "openclaw.json patched"

log "writing $AUTH_STORE..."
mkdir -p "$(dirname "$AUTH_STORE")"

AUTH_STORE="$AUTH_STORE" PROVIDER_API_KEY="$PROVIDER_API_KEY" python3 <<'PYEOF'
import json, os
path = os.environ['AUTH_STORE']
api_key = os.environ['PROVIDER_API_KEY']

try:
    store = json.load(open(path))
except (json.JSONDecodeError, FileNotFoundError):
    store = {'version': 1, 'profiles': {}}

store.setdefault('profiles', {})
store['profiles']['openai-default'] = {
    'type': 'api_key',
    'provider': 'openai',
    'key': api_key,
    'displayName': 'Together AI (openai-compatible, set by InvestorClaw installer)',
}

json.dump(store, open(path, 'w'), indent=2)
os.chmod(path, 0o600)
print(f"auth-profiles.json: openai-default api_key credential written")
PYEOF
ok "auth-profiles.json written"

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
