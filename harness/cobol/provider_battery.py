# SPDX-License-Identifier: Apache-2.0
"""Per-provider COBOL hallucination + routing battery.

Runs the full nlq-prompts.json (30 prompts) through the ic-engine container
ONCE PER GRAEAE PROVIDER, pinning the narrator to that provider via
INVESTORCLAW_NARRATIVE_ENDPOINT/_MODEL/_API_KEY. Scores each (provider, prompt):

  - hmac_valid        ic_result.hmac present (signed deterministic envelope)
  - routing_ok        narrative addresses the prompt's intent (expected verbs/keywords)
  - narration_source  "llm" if the pinned provider produced text, else "heuristic"
                      (empty/failed LLM falls back to the HMAC-grounded restatement)
  - hallucination     numbers/$/tickers in the narrative NOT grounded in the signed
                      envelope sections  →  ungrounded claims = hallucination
  - pass              hmac_valid AND routing_ok AND hallucination == 0

30/30 = all 30 prompts pass for that provider. The signed envelope is the
ground truth: HMAC-grounding is the anti-hallucination mechanism, so a provider
that falls back to the heuristic still scores hallucination=0 (it only restates
signed data) — narration_source distinguishes "narrated" from "fell back".

Usage (on the build host, container image already pulled):
    python3 provider_battery.py --image ghcr.io/argonautsystems/ic-engine:4.5.2-cpu \
        --data ~/ic-phase2/ic-data --keys ~/ic-phase2/provider_keys.env \
        --massive-key $MASSIVE_API_KEY --out ~/ic-phase2/results
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import time
from pathlib import Path

# provider -> OpenAI-compatible base URL, model, and the env var holding its key
# (env file is `export <NAME>_API_KEY=...`, sourced before this runs).
PROVIDERS = {
    "together":   ("https://api.together.xyz/v1",                  "meta-llama/Llama-3.3-70B-Instruct-Turbo", "TOGETHER_API_KEY"),
    "groq":       ("https://api.groq.com/openai/v1",               "llama-3.3-70b-versatile",                 "GROQ_API_KEY"),
    "openai":     ("https://api.openai.com/v1",                    "gpt-5.2-chat-latest",                     "OPENAI_API_KEY"),
    "claude":     ("https://api.anthropic.com/v1",                 "claude-sonnet-4-6",                       "ANTHROPIC_API_KEY"),
    "perplexity": ("https://api.perplexity.ai",                    "sonar-pro",                               "PERPLEXITY_API_KEY"),
    "xai":        ("https://api.x.ai/v1",                          "grok-4-1-fast",                           "XAI_API_KEY"),
    "nvidia":     ("https://integrate.api.nvidia.com/v1",          "meta/llama-3.3-70b-instruct",             "NVIDIA_API_KEY"),
    "gemini":     ("https://generativelanguage.googleapis.com/v1beta/openai", "gemini-3.1-pro-preview",       "GEMINI_API_KEY"),
}

TICKER_RE = re.compile(r"\b[A-Z]{1,5}\d?\b")           # equities + CME futures roots (ESH7)
MONEY_RE = re.compile(r"\$?\s?(\d[\d,]*\.?\d*)")        # $ amounts / bare numbers
HEURISTIC_MARKERS = ("heuristic fallback", "I have holdings summary data in the envelope")

# Common words that match TICKER_RE but are not tickers — don't flag as hallucinated.
STOPWORD_TOKENS = {
    "I", "A", "THE", "AND", "OR", "OK", "USD", "ETF", "CME", "YTM", "P", "E",
    "YTD", "EOD", "NLQ", "FY", "Q1", "Q2", "Q3", "Q4", "US", "IT", "AS", "AI",
}


def load_envelope(reports_dir: Path) -> dict:
    """Load the freshest cached signed envelope (ground truth)."""
    cache = reports_dir / ".cache"
    envs = sorted(cache.glob("envelope.*.json"), key=lambda p: p.stat().st_mtime)
    if not envs:
        raise FileNotFoundError(f"no cached envelope in {cache}")
    return json.loads(envs[-1].read_text())


def grounded_values(envelope: dict) -> tuple[set[str], set[str]]:
    """Flatten the signed envelope into the set of numeric strings and tickers
    that a narrative is allowed to mention without hallucinating."""
    nums: set[str] = set()
    tickers: set[str] = set()

    def walk(o):
        if isinstance(o, dict):
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
        elif isinstance(o, (int, float)):
            f = float(o)
            if not math.isfinite(f):
                return
            # record the integer + 1-2dp rounded forms so "1728062.22",
            # "1728062", "1,728,062" all match
            for s in (f"{f:.2f}", f"{f:.1f}", f"{f:.0f}", f"{int(f)}"):
                nums.add(s.replace(",", ""))
        elif isinstance(o, str):
            s = o.strip().upper()
            if TICKER_RE.fullmatch(s):
                tickers.add(s)

    walk(envelope)
    return nums, tickers


def score_hallucination(answer: str, nums: set[str], tickers: set[str]) -> tuple[int, list[str]]:
    """Count narrative numbers/tickers NOT present in the signed envelope."""
    ungrounded: list[str] = []
    # tickers
    for t in set(TICKER_RE.findall(answer.upper())):
        if t in STOPWORD_TOKENS or t in tickers:
            continue
        # ignore pure numbers caught by ticker regex
        if t.isdigit():
            continue
        ungrounded.append(f"ticker:{t}")
    # numbers (tolerate any that round-match a grounded value)
    for m in MONEY_RE.findall(answer):
        raw = m.replace(",", "")
        try:
            f = float(raw)
        except ValueError:
            continue
        if not math.isfinite(f) or f < 10:   # tiny ints / non-finite too noisy — skip
            continue
        forms = {f"{f:.2f}", f"{f:.1f}", f"{f:.0f}", f"{int(f)}"}
        if forms & nums:
            continue
        ungrounded.append(f"num:{raw}")
    return len(ungrounded), ungrounded[:8]


def route_ok(intent: str, expected: list[str], answer: str) -> bool:
    """Did the narrative address the prompt's intent? Heuristic: any expected
    verb/keyword (or its stem) appears, or for DEFLECT_OK the answer declines."""
    a = answer.lower()
    if any(e == "DEFLECT_OK" for e in expected):
        return any(k in a for k in ("educational", "cannot", "out of scope", "not financial advice", "don't have"))
    stems = set()
    for e in expected:
        for tok in re.split(r"[ _=:]", e.lower()):
            if len(tok) >= 4:
                stems.add(tok)
    stems.update(intent.lower().split("-"))
    return any(s[:5] in a for s in stems if len(s) >= 4)


def run_prompt(image: str, data: Path, massive_key: str, prov: str, prompt: str, timeout: int) -> tuple[str, str]:
    """Return (stdout, stderr) of one engine `ask` with the narrator pinned."""
    endpoint, model, key_env = PROVIDERS[prov]
    env = os.environ.get(key_env, "")
    cmd = [
        "docker", "run", "--rm",
        "-e", "INVESTORCLAW_PRICE_PROVIDER=massive",
        "-e", f"MASSIVE_API_KEY={massive_key}",
        "-e", "INVESTORCLAW_NARRATIVE_ENABLED=true",
        "-e", f"INVESTORCLAW_NARRATIVE_ENDPOINT={endpoint}",
        "-e", f"INVESTORCLAW_NARRATIVE_MODEL={model}",
        "-e", f"INVESTORCLAW_NARRATIVE_API_KEY={env}",
        "-e", "INVESTORCLAW_PORTFOLIO_DIR=/data/portfolios",
        "-e", "IC_PORTFOLIO_DIR=/data/portfolios",
        "-v", f"{data}:/data",
        "--entrypoint", "/opt/ic-engine/.venv/bin/investorclaw",
        image, "ask", prompt,
    ]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return "", "TIMEOUT"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--data", required=True, type=Path)
    ap.add_argument("--massive-key", required=True)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--prompts", type=Path, default=Path(__file__).with_name("nlq-prompts.json"))
    ap.add_argument("--providers", default=",".join(PROVIDERS))
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    prompts = json.loads(args.prompts.read_text())["prompts"]
    reports = args.data / "reports"

    # ground truth from the signed envelope (warm it first with one run if absent)
    if not list((reports / ".cache").glob("envelope.*.json")):
        print("warming envelope (cold ~150s) ...", flush=True)
        run_prompt(args.image, args.data, args.massive_key, "groq",
                   "What is in my portfolio right now?", args.timeout)
    envelope = load_envelope(reports)
    nums, tickers = grounded_values(envelope)
    futures_section = envelope.get("sections", {}).get("futures") or envelope.get("sections", {}).get("holdings", {})
    print(f"ground truth: {len(nums)} numeric values, {len(tickers)} tickers, "
          f"futures_present={bool(envelope.get('sections', {}).get('futures'))}", flush=True)

    summary = {}
    for prov in args.providers.split(","):
        prov = prov.strip()
        if prov not in PROVIDERS:
            continue
        rows = []
        t0 = time.time()
        for p in prompts:
            out, err = run_prompt(args.image, args.data, args.massive_key, prov, p["prompt"], args.timeout)
            blob = out + "\n" + err
            hmac_valid = bool(re.search(r'"hmac":\s*"[0-9a-f]{32,}"', blob) or re.search(r"ic_result\.hmac:\s*[0-9a-f]{32,}", blob))
            source = "heuristic" if any(m in blob for m in HEURISTIC_MARKERS) else "llm"
            # narrative = stdout minus the json/footer lines
            answer = "\n".join(l for l in out.splitlines()
                               if not l.strip().startswith("{") and "IMPORTANT:" not in l and "====" not in l)
            halluc, examples = score_hallucination(answer, nums, tickers)
            r_ok = route_ok(p["intent"], p["expected_routes"].get("investorclaw", []), answer)
            passed = hmac_valid and r_ok and halluc == 0
            rows.append({
                "id": p["id"], "intent": p["intent"], "pass": passed,
                "hmac_valid": hmac_valid, "routing_ok": r_ok,
                "narration_source": source, "hallucination": halluc,
                "ungrounded": examples,
            })
            print(f"  [{prov}] {p['id']:<22} pass={passed} hmac={hmac_valid} route={r_ok} "
                  f"src={source} halluc={halluc}", flush=True)
        npass = sum(r["pass"] for r in rows)
        nllm = sum(r["narration_source"] == "llm" for r in rows)
        summary[prov] = {
            "score": f"{npass}/{len(rows)}",
            "narrated_by_llm": f"{nllm}/{len(rows)}",
            "hallucinations": sum(r["hallucination"] for r in rows),
            "elapsed_s": int(time.time() - t0),
        }
        (args.out / f"{prov}.json").write_text(json.dumps({"provider": prov, "rows": rows, **summary[prov]}, indent=2))
        print(f"== {prov}: {summary[prov]} ==\n", flush=True)

    (args.out / "summary.json").write_text(json.dumps(summary, indent=2))
    print("=== BATTERY SUMMARY ===")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
