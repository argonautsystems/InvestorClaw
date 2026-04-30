#!/usr/bin/env bash
# InvestorClaw — zeroclaw installer (bundle-based, v2.6.3+)
#
# Installs the audit-compliant skill bundle into zeroclaw's workspace and
# patches the user's zeroclaw config so skill tools (portfolio_ask,
# portfolio_refresh) actually execute (defaults block them via
# autonomy.forbidden_paths and autonomy.auto_approve).
#
# Usage:
#   bash installers/zeroclaw/install.sh                    # from repo checkout
#   curl -fsSL <release-url>/install.sh | bash             # from release
#
# Env overrides:
#   IC_BUNDLE_TGZ      — path to a local bundle tarball (default: auto-detect)
#   IC_BUNDLE_VERSION  — version to fetch from releases (default: 2.6.3)
#   IC_VENV_DIR        — where to put the ic-engine venv (default: ~/.cache/investorclaw/.venv)
#   ZEROCLAW_HOME      — zeroclaw config root (default: ~/.zeroclaw)
#
# Copyright 2026 InvestorClaw Contributors. Apache-2.0.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${BLUE}→${NC} $*"; }
ok()     { echo -e "${GREEN}✓${NC} $*"; }
warn()   { echo -e "${YELLOW}⚠${NC} $*"; }
err()    { echo -e "${RED}✗${NC} $*" >&2; }
die()    { err "$*"; exit 1; }

VERSION="${IC_BUNDLE_VERSION:-2.6.3}"
BUNDLE_NAME="investorclaw-skill-${VERSION}"
ZC_HOME="${ZEROCLAW_HOME:-$HOME/.zeroclaw}"
SKILL_DIR="$ZC_HOME/workspace/skills/investorclaw"
VENV_DIR="${IC_VENV_DIR:-$HOME/.cache/investorclaw/.venv}"
BIN_LINK="$HOME/.local/bin/investorclaw"
CONFIG_FILE="$ZC_HOME/config.toml"

# ------------- preflight ---------------------------------------------
log "InvestorClaw v${VERSION} — zeroclaw installer (bundle-based)"

command -v zeroclaw >/dev/null 2>&1 || die "zeroclaw CLI not found in PATH. Install zeroclaw first."
ok "zeroclaw: $(zeroclaw --version 2>&1 | head -1)"

command -v uv >/dev/null 2>&1 || die "uv not found in PATH. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
ok "uv: $(uv --version 2>&1 | head -1)"

# ------------- locate the bundle -------------------------------------
BUNDLE_TGZ="${IC_BUNDLE_TGZ:-}"
if [ -z "$BUNDLE_TGZ" ]; then
    # Try repo-local build artifact
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [ -f "$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz" ]; then
        BUNDLE_TGZ="$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz"
    fi
fi

if [ -z "$BUNDLE_TGZ" ] || [ ! -f "$BUNDLE_TGZ" ]; then
    # Fall back to building it from the repo
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [ -f "$REPO_ROOT/Makefile" ] && [ -f "$REPO_ROOT/scripts/build_skill_bundle.py" ]; then
        log "no prebuilt bundle found — building via 'make skill-bundle'"
        (cd "$REPO_ROOT" && make skill-bundle >/dev/null) || die "make skill-bundle failed"
        BUNDLE_TGZ="$REPO_ROOT/build/${BUNDLE_NAME}.tar.gz"
    else
        die "bundle not found at \$IC_BUNDLE_TGZ or repo build/, and Makefile not present"
    fi
fi
[ -f "$BUNDLE_TGZ" ] || die "bundle still not found: $BUNDLE_TGZ"
ok "bundle: $BUNDLE_TGZ ($(du -h "$BUNDLE_TGZ" | cut -f1))"

# ------------- extract bundle ----------------------------------------
log "extracting bundle to $SKILL_DIR..."
mkdir -p "$ZC_HOME/workspace/skills"
rm -rf "$SKILL_DIR" "$SKILL_DIR-staging"
tar -xzf "$BUNDLE_TGZ" -C "$ZC_HOME/workspace/skills"
mv "$ZC_HOME/workspace/skills/${BUNDLE_NAME}" "$SKILL_DIR"
ok "extracted ($(find "$SKILL_DIR" -type f | wc -l | tr -d ' ') files)"

# ------------- create venv OUTSIDE skill dir (zeroclaw audit blocks symlinks) ---
log "creating ic-engine venv at $VENV_DIR..."
mkdir -p "$(dirname "$VENV_DIR")"
(cd "$SKILL_DIR" && UV_PROJECT_ENVIRONMENT="$VENV_DIR" uv sync --python 3.12 >/dev/null 2>&1) \
    || die "uv sync failed in $SKILL_DIR"
ok "venv ready ($(ls "$VENV_DIR/lib"/python*/site-packages | wc -l | tr -d ' ') packages)"

# ------------- symlink CLI to user PATH ------------------------------
mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$VENV_DIR/bin/investorclaw" "$BIN_LINK"
ok "symlinked $BIN_LINK"

# ------------- patch zeroclaw config ---------------------------------
log "preflight check on existing zeroclaw configuration..."
mkdir -p "$ZC_HOME"

if [ ! -f "$CONFIG_FILE" ]; then
    zeroclaw config init >/dev/null 2>&1 || true
fi
[ -f "$CONFIG_FILE" ] || die "could not create $CONFIG_FILE"

CONFIG_FILE="$CONFIG_FILE" python3 <<'PYEOF'
import os, re, sys
config_path = os.environ['CONFIG_FILE']
content = open(config_path).read()

def parse_array(text, key):
    """Find a TOML array and return its current items as a list of strings."""
    pat = re.compile(
        rf'^{re.escape(key)}\s*=\s*\[([^\]]*)\]',
        re.MULTILINE | re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return None
    return re.findall(r'"([^"]*)"', m.group(1))

def patch_array(content, key, removals=(), additions=()):
    """Idempotent: only modifies if there's actual change to make."""
    pat = re.compile(
        rf'(^{re.escape(key)}\s*=\s*\[)([^\]]*)(\])',
        re.MULTILINE | re.DOTALL,
    )
    m = pat.search(content)
    if not m:
        return content, False
    body = m.group(2)
    items = re.findall(r'"([^"]*)"', body)
    original = list(items)
    for r in removals:
        items = [x for x in items if x != r]
    for a in additions:
        if a not in items:
            items.append(a)
    if items == original:
        return content, False
    new_body = ',\n    '.join(f'"{x}"' for x in items)
    if new_body:
        new_body = '\n    ' + new_body + ',\n'
    return content[:m.start()] + f'{key} = [{new_body}]' + content[m.end():], True

# Inspect current state
existing_forbidden = parse_array(content, 'forbidden_paths') or []
existing_auto_approve = parse_array(content, 'auto_approve') or []
existing_allowed = parse_array(content, 'allowed_commands') or []
allow_scripts_match = re.search(r'^allow_scripts\s*=\s*(true|false)', content, re.MULTILINE)
allow_scripts = allow_scripts_match.group(1) if allow_scripts_match else None

print("")
print("  ┌─ zeroclaw configuration preflight ─────────────────────────────")
print(f"  │ config:                {config_path}")
print(f"  │ skills.allow_scripts:  {allow_scripts or '(unset)'}")
forbidden_blocking = [p for p in ('/home', '/opt') if p in existing_forbidden]
if forbidden_blocking:
    print(f"  │ autonomy.forbidden_paths blocks skill: {forbidden_blocking}")
    print(f"  │   (installer will REMOVE these — they block /home/$USER/.zeroclaw)")
else:
    print(f"  │ autonomy.forbidden_paths:  no blocking entries for skill dirs")
needed_approve = ['investorclaw.portfolio_ask', 'investorclaw.portfolio_refresh']
missing_approve = [a for a in needed_approve if a not in existing_auto_approve]
if missing_approve:
    print(f"  │ autonomy.auto_approve missing: {missing_approve}")
    print(f"  │   (installer will ADD — required for non-interactive skill calls)")
else:
    print(f"  │ autonomy.auto_approve:     investorclaw tools already approved")
needed_cmds = ['investorclaw', 'uv', 'sh']
missing_cmds = [c for c in needed_cmds if c not in existing_allowed]
if missing_cmds:
    print(f"  │ autonomy.allowed_commands missing: {missing_cmds}")
    print(f"  │   (installer will ADD — covers shell-tool fallback paths)")
else:
    print(f"  │ autonomy.allowed_commands: covers investorclaw / uv / sh")
print("  └─────────────────────────────────────────────────────────────────")
print("")

# Apply patches (idempotent — only writes when changed)
content, changed1 = patch_array(content, 'forbidden_paths', removals=['/home', '/opt'])
content, changed2 = patch_array(content, 'auto_approve', additions=needed_approve)
content, changed3 = patch_array(content, 'allowed_commands', additions=needed_cmds)
changed = changed1 or changed2 or changed3

if re.search(r'^\[skills\]', content, re.MULTILINE):
    if allow_scripts != 'true':
        if 'allow_scripts' not in content:
            content = re.sub(
                r'(^\[skills\]\s*\n)',
                r'\1allow_scripts = true\n',
                content, count=1, flags=re.MULTILINE,
            )
        else:
            content = re.sub(
                r'^(allow_scripts\s*=\s*)(false|true)',
                r'\1true',
                content, flags=re.MULTILINE,
            )
        changed = True
elif allow_scripts != 'true':
    content += '\n[skills]\nallow_scripts = true\n'
    changed = True

if changed:
    open(config_path, 'w').write(content)
    print("  → config patched (idempotent: only changed entries that needed it)")
else:
    print("  → config already configured correctly — no changes")
PYEOF

ok "configuration preflight complete"

# ------------- verify ------------------------------------------------
log "verifying skill registration..."
if zeroclaw skills audit investorclaw 2>&1 | grep -q "Skill audit passed"; then
    ok "zeroclaw skills audit: PASS"
else
    warn "skills audit reported issues — review with: zeroclaw skills audit investorclaw"
fi

if zeroclaw skills list 2>&1 | grep -q "investorclaw"; then
    ok "skill registered: $(zeroclaw skills list 2>&1 | grep investorclaw | head -1 | sed 's/^[[:space:]]*//')"
else
    warn "skill not listed — review with: zeroclaw skills list"
fi

if "$BIN_LINK" --version >/dev/null 2>&1; then
    ok "investorclaw CLI: $("$BIN_LINK" --version 2>&1 | head -1)"
else
    warn "investorclaw CLI not callable from $BIN_LINK"
fi

# ------------- next steps --------------------------------------------
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  InvestorClaw v${VERSION} — installed for zeroclaw                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Skill dir:    $SKILL_DIR"
echo "  Venv:         $VENV_DIR"
echo "  CLI:          $BIN_LINK"
echo "  Config:       $CONFIG_FILE"
echo ""
echo "  Try it:"
echo "    zeroclaw agent -m \"What is in my portfolio right now?\""
echo ""
echo "  If you don't have a portfolio CSV yet, drop one in:"
echo "    $SKILL_DIR/portfolios/"
echo "  then run:"
echo "    investorclaw setup"
