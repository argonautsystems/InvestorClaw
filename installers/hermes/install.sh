#!/usr/bin/env bash
# InvestorClaw — hermes installer (bundle-based, v2.6.3+)
#
# Hermes treats skills as documentation hints injected into LLM system
# prompt + invokable via meta-tools (skill_view, skill_manage, terminal).
# Different architecture from zeroclaw 0.7.3 (which surfaces skill tools
# directly) — see KNOWN_ISSUES.md HER-1.
#
# This installer:
#   1) Extracts the audit-compliant bundle to hermes' skill directory
#   2) Symlinks the investorclaw CLI to user PATH so terminal-tool can
#      invoke it directly
#
# Env overrides:
#   IC_BUNDLE_TGZ      — path to local bundle (default: auto-detect)
#   IC_BUNDLE_VERSION  — version (default: 2.6.3)
#   IC_VENV_DIR        — venv location (default: ~/.cache/investorclaw/.venv)
#   HERMES_HOME        — hermes data dir (default: ~/.hermes)
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
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILL_DIR="$HERMES_HOME/skills/investorclaw"
VENV_DIR="${IC_VENV_DIR:-$HOME/.cache/investorclaw/.venv}"
BIN_LINK="$HOME/.local/bin/investorclaw"

log "InvestorClaw v${VERSION} — hermes installer (bundle-based)"

if command -v hermes >/dev/null 2>&1; then
    ok "hermes: $(hermes --version 2>&1 | head -1)"
elif [ -x /opt/hermes/.venv/bin/hermes ]; then
    ok "hermes (containerized): $(/opt/hermes/.venv/bin/hermes --version 2>&1 | head -1)"
else
    warn "hermes CLI not found — proceeding with bundle install only"
fi

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
mkdir -p "$HERMES_HOME/skills"
rm -rf "$SKILL_DIR" "$HERMES_HOME/skills/${BUNDLE_NAME}"
tar -xzf "$BUNDLE_TGZ" -C "$HERMES_HOME/skills"
mv "$HERMES_HOME/skills/${BUNDLE_NAME}" "$SKILL_DIR"
ok "extracted ($(find "$SKILL_DIR" -type f | wc -l | tr -d ' ') files)"

log "creating ic-engine venv at $VENV_DIR..."
mkdir -p "$(dirname "$VENV_DIR")"
(cd "$SKILL_DIR" && UV_PROJECT_ENVIRONMENT="$VENV_DIR" uv sync --python 3.12 >/dev/null 2>&1) \
    || die "uv sync failed in $SKILL_DIR"
ok "venv ready"

mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$VENV_DIR/bin/investorclaw" "$BIN_LINK"
ok "symlinked $BIN_LINK"

if "$BIN_LINK" --version >/dev/null 2>&1; then
    ok "investorclaw CLI: $("$BIN_LINK" --version 2>&1 | head -1)"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  InvestorClaw v${VERSION} — installed for hermes                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Skill dir:    $SKILL_DIR"
echo "  Venv:         $VENV_DIR"
echo "  CLI:          $BIN_LINK"
echo ""
echo "  Note: hermes treats skills as documentation hints (per KNOWN_ISSUES HER-1)."
echo "  The LLM may need to be explicitly told to invoke 'investorclaw <command>'"
echo "  via the terminal tool. Empirical reliability ~8% baseline (Linux 2026-04-29)."
echo ""
echo "  Try it:"
echo "    hermes chat -q \"What is in my portfolio?\" --provider gemini -m gemini-2.5-flash --yolo"
