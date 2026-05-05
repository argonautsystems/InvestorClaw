<!--
Landing zone: techbroiler.net
Status: draft
Empirical baseline: v4.1.34, 2026-05-05
Target length: 2000-3000 words
Authors: Jason Perlow + agent collaborators
Tags: agentic-systems, llm, mcp, plugin-ecosystem, deterministic-computation, fintech, cobol
-->

# The deterministic agentic skill: how we stopped letting the LLM do the math

Alternate titles:

- "Markdown is not a software package: rebuilding our agent skill from a prompt into a service"
- "Your skill is a software package, not a markdown file. Here is what that looks like."
- "We tested our agent with COBOL. Then we put the engine in Docker. Here is why both mattered."
- "From prompt to container: what a real agentic skill looks like in 2026"
- "29/30: how shipping a container instead of a markdown file fixed our agent"

## Hook

Last month our tests passed and the agent still failed. This month the old skill model failed harder: 1 PASS out of 250 attempts.

Not 1/30. Not "a little noisy." One out of two hundred and fifty.

The old shape looked normal for 2026 agent work. A markdown skill. A plugin wrapper. Shell commands. Runtime-specific install scripts. A pile of instructions telling the model which command to call, which JSON not to hallucinate, and which finance facts not to invent. The code behind those commands worked. The unit tests passed. The portfolio engine could compute holdings, performance, bonds, news, analyst coverage, optimization, cash flow, peer comparison, and reports.

The agentic product was still broken because the LLM was being asked to do too much. It had to route. It had to decide which tool mattered. It had to remember the shape of the finance domain. It had to narrate. And in the worst version of the stack, it had too many chances to make up the answer before the deterministic engine ever got a turn.

That was the moment the architecture stopped being a packaging problem and became a product definition problem.

An agentic skill is not a markdown file with vibes and commands stapled to it. For real workloads, the skill is a software package. It has a typed surface. It has a deterministic core. It has a narrator, but the narrator is not allowed near the math.

InvestorClaw v4.1.34 is the version where we made that boring enough to ship.

## The markdown skill paradigm and why it breaks

Most agent skills today are instructions. Markdown instructions, usually. Some prose about what the tool does, a few examples, a shell command or two, and a lot of implied trust that the runtime LLM will read the room correctly.

That works for demos because demos are scripted. The prompt is clean. The corpus is small. The author is nearby. The model has seen the expected path three times before the camera turns on.

Production is not that polite.

Users do not ask "please invoke portfolio_view section=performance." They ask, "How bad was the drawdown this year?" They ask, "Any big mergers or acquisitions in the news today?" They ask, "What is the current price of NVDA?" They ask, "Should I rebalance?" Each one of those could mean a different tool, a different section, or a deliberate refusal. In a markdown-skill world, the LLM is the runtime author of the skill. The person who wrote the markdown is only making suggestions.

That is where the math starts to rot.

If the model routes to the wrong command, the engine can be perfect and the user still gets nonsense. If the model decides not to route at all, it may answer from training data. If the prompt asks for a number that is missing, the model may "help" by inventing one. If two runtimes interpret the same skill text differently, one passes and the other quietly ships a different product.

The worst part is how normal this looks in CI. Unit tests prove the Python function works. A manifest validator proves the plugin loads. A smoke test proves one blessed prompt returns something. None of those prove the agent chooses the right tool for the 30 natural-language questions real users actually ask.

Skills also drift because they are not treated like software packages. A markdown file gets edited, copied into a runtime, forked for Claude Code, translated into an OpenClaw skill, and patched again for Hermes. By the end, the contract is not one thing. It is four interpretations of a prose document.

That is fine for a toy. It is not fine for portfolio analysis, medical summaries, legal workflows, infrastructure operations, or anything where a fabricated number can cost someone money or time.

The lesson from the 1/250 baseline was not "write better markdown." We had already done that. The lesson was "stop making the LLM do the work that has to be correct."

## What a deterministic agentic skill actually looks like

The shape that survived is simple.

First, give the agent a typed contract surface. In InvestorClaw v4.1.34 that surface is MCP over HTTP on `localhost:18090/mcp`, with 13 tools: `portfolio_ask`, `portfolio_initialize`, `portfolio_initialize_status`, `portfolio_holdings`, `portfolio_refresh`, `portfolio_setup`, `portfolio_keys_status`, `portfolio_keys_set`, `portfolio_keys_delete`, `portfolio_response_get`, `portfolio_response_list`, `portfolio_response_delete`, and `portfolio_response_flag_bad`. The full contract is in [docs/MCP_TOOLS_REFERENCE.md](../MCP_TOOLS_REFERENCE.md).

Second, put the work that must be correct in a deterministic engine. Holdings parsing, normalization, market data refresh, bond math, performance metrics, optimization, cash flow, peer comparison, report generation, and HMAC envelope signing belong in software. They do not belong in the model's short-term memory.

Third, let the LLM do the thing it is good at: explain the result in language a person will read. But constrain it. InvestorClaw's narrator sits on top of an HMAC-signed envelope. The answer has to be grounded in that envelope. Numbers come from the engine. Missing facts stay missing. A pretty lie is still a lie, and the validator treats it that way.

That is the deterministic agentic skill pattern: typed surface, deterministic core, constrained narration.

The install artifact is not a prompt. It is an image:

```text
ghcr.io/argonautsystems/ic-engine:4.1.34-cpu
sha256:7f07d516f107260b4518b6ceb7b074761843f0d7abab99d55298215e1d4cc9a9
```

It is 1.14 GB, CPU-only, with CUDA stripped. It runs as a non-root container. It is localhost-first. It is read-only with respect to brokerage activity. It asks for no brokerage credentials and has no outbound trade path.

The same package serves two audiences. Agents call MCP at `:18090`. Humans open the dashboard portal at `:18092`. Both surfaces read and write the same `/data` volume. Both point at the same engine. Neither asks the model to compute portfolio math.

Provider keys are optional, but the named surface is explicit: `TOGETHER`, `OPENAI`, `FINNHUB`, `FRED`, `NEWSAPI`, `ALPHA_VANTAGE`, `MASSIVE`, and `MARKETAUX`. The default narrative provider is Together AI with `MiniMaxAI/MiniMax-M2.7`. The model can write the wrap-up. It cannot become the portfolio engine.

That matters because the same contract now works across runtimes. OpenClaw, ZeroClaw, Hermes, and Claude Code via InvestorClaude can all point at the same service shape. The skill format changes. The package does not.

## From markdown to container, the v4.0 rewrite

InvestorClaw v2.x was a familiar agent stack: a Python adapter package, a Claude Code marketplace plugin, per-runtime install scripts, and an engine called in-process from whichever host happened to be running the skill.

It was clever in the way many agent projects are clever. It worked until it did not.

The v4.0 rewrite was the "nuke from orbit" moment. The five-day arc from v4.1.0 to v4.1.34 happened after that. The runtime moved into Docker. The engine stopped being a library each runtime interpreted differently and became a service with two listeners:

```bash
docker compose up -d
```

MCP-HTTP listens on host port `18090`. The dashboard portal listens on host port `18092`. A shared `/data` volume carries portfolios, reports, key status, response history, and Stonkmode state.

Yes, a container sounds heavy compared to a markdown file. It is also honest. A finance engine with parsers, providers, report templates, HMAC signing, API-key handling, and a browser portal is software. Pretending it is a markdown file does not make it lighter. It only moves the weight into user confusion and runtime variance.

The current runtime source lives at [mnemos-os/mnemos-ic-runtime](https://github.com/mnemos-os/mnemos-ic-runtime). The Python engine lives at [argonautsystems/ic-engine](https://github.com/argonautsystems/ic-engine). Foundation primitives live at [argonautsystems/clio](https://github.com/argonautsystems/clio). The umbrella package is [argonautsystems/InvestorClaw](https://github.com/argonautsystems/InvestorClaw), and Claude Code support lives in [argonautsystems/InvestorClaude](https://github.com/argonautsystems/InvestorClaude).

Install paths reflect the split. Claw-family runtimes use:

```bash
clawhub install perlowja/investorclaw
```

Claude Code uses the marketplace plugin path:

```text
/plugin marketplace add https://gitlab.com/argonautsystems/InvestorClaude.git
```

Underneath both, the serious part is the same containerized engine contract. That is the point.

## Then the agent has to actually choose the right tool

The container did not delete the agent problem. It made the failure mode measurable.

This is where COBOL comes back into the story, as a test method, not nostalgia bait. The previous post, ["All our tests passed. The agent was still broken."](https://techbroiler.net/all-our-tests-passed-the-agent-was-still-broken/), laid out the Agentic COBOL idea: write the natural-language prompts users actually say, write the expected route or answer criterion, run the full LLM-plus-tools system, and score the result.

InvestorClaw's corpus has 30 prompts in [harness/cobol/nlq-prompts.json](../../harness/cobol/nlq-prompts.json). They cover holdings, performance, analyst ratings, news, risk synthesis, optimization, target allocation, rebalance, bonds, market data, EOD reports, cash flow, peer comparison, lookup, setup, and guardrails. The methodology is documented in [harness/cobol/AGENTIC_COBOL_SPEC.md](../../harness/cobol/AGENTIC_COBOL_SPEC.md).

For v4.1.34, the release harness moved from the old 1/250 PASS baseline to 29/30 PASS. That was N=3 across four runtimes: ZeroClaw, OpenClaw, Hermes, and Claude Code via InvestorClaude. The important part is not just the count. It is what counts as a pass.

`ic_result_present=true` is not enough.

The narrator answer has to actually answer the prompt. A response that returns the engine envelope but ends in a catalog blurb does not pass. A response with refusal markers in the answer tail does not pass. A response that says the section did not run does not pass. This is where the v2.x harness taught us to distrust our own green lights. The scorer is part of the product now. If it cannot distinguish "the engine returned JSON" from "the user got an answer," it is just another place to hide failure.

COBOL is the right joke because it is barely a joke. A payroll clerk in 1959 could read a COBOL program aloud and decide whether it matched the business process. A portfolio user in 2026 should be able to read the 30 NLQs and decide whether the agent is being tested against reality.

The old markdown skill let every runtime improvise. The container gave them one backend. The COBOL barrage proved whether they were actually using it.

## The dashboard surface, because humans are not agents

Agents are pull-based. Humans browse.

That is why v4.1.34 also ships the 17-tab dashboard documented in [docs/DASHBOARD.md](../DASHBOARD.md). Open `http://localhost:18092` and you get Overview, Holdings, Performance, WhatChanged, Scenarios, Bonds, Optimize, Cashflow, Peer, Analyst, News, Markets, Lookup, Synthesis, Reports, Settings, and About.

It is not a second product. It is the same engine, same `/data` volume, and same generated artifacts shown through server-rendered HTML. The Overview tab's Regenerate button posts to `POST /dashboard/regenerate`, then fires the same sweep that `portfolio_initialize` triggers: setup, refresh, performance, bonds, analyst, news, whatchanged, scenario, optimize, rebalance, cashflow, peer, markets, and synthesize. The rough sweep time is three to five minutes for a large portfolio.

The upload form on Settings is `POST /dashboard/upload`. It stores a local file under `/data/portfolios/`. It does not log in to a brokerage. It does not move money. It queues analysis.

The EOD email report ships from the same engine. A static sample exists at [assets/eod-report-sample.html](../../assets/eod-report-sample.html), and live reports show up under `/reports/` once generated. This is what a real agentic package starts to look like: not a chat trick, but a service a person can inspect without asking a model to be the UI.

## Stonkmode, or: why the entertainment layer is the deliberate honesty signal

Stonkmode is the part that looks least serious and does some of the most serious positioning work.

InvestorClaw ships 30 fictional cable-finance personas plus Dr. Stonk, the educator role. The mode is documented in [docs/STONKMODE.md](../STONKMODE.md). It is satire and education on top of the deterministic engine. It is not advice. It is not a fiduciary. It is not a brokerage terminal with a wig on.

The attribution has to be explicit: Matt Madson.

The whole point is boundary clarity. A tool that ships with 30 satirical cable TV personalities cannot credibly be mistaken for institutional financial software. King Donny and Glorb can argue about concentration risk, bond ladders, and the "Sacred Ledger" because the data underneath already exists. The character layer is not allowed to alter holdings, prices, metrics, allocations, or risk calculations.

The example in [docs/STONKMODE_EXAMPLE_OUTPUT.md](../STONKMODE_EXAMPLE_OUTPUT.md) has King Donny turning MSFT, AAPL, and GOOG into a victory-lap negotiation while Glorb interrupts with ledger anxiety about concentration risk. That is funny only because the premise is controlled: synthetic sample, satirical hosts, educational framing, deterministic portfolio concepts underneath.

Stonkmode is not a loophole around rigor. It is the proof that the architecture knows which layer is allowed to be weird. The math stays boring. The narration can wear the loud suit.

## What this means for the agentic ecosystem

Most agentic skills are still markdown. That is understandable. Markdown is cheap, portable, readable, and friendly to the current generation of runtimes. It is also not enough for workloads where correctness matters.

The next year of serious agentic systems will not be won by whoever has the longest skill file. It will be won by packages that behave identically across runtimes. The shape is already visible:

1. A typed contract surface, usually MCP.
2. A deterministic core for work that must be correct.
3. A constrained narration layer for language.
4. A dual presentation model, agent surface plus human surface.
5. Versioned artifacts that can be tagged, installed, audited, and reproduced.

ClawHub is one publisher path. Anthropic's Claude Code marketplace is another. Docker Compose is the boring escape hatch. The reason all three can exist is that the contract is MCP and the engine is a package, not a prose suggestion.

This is especially obvious in finance, but it is not limited to finance. Any regulated, high-cost, high-trust, or long-session workflow has the same pressure. A user browsing a portfolio dashboard for two hours needs different guarantees than a user asking a toy agent to summarize a README. A doctor reviewing lab values, a lawyer reviewing citations, or an operator checking production state does not need the model to "do the math." They need it to explain data produced by systems whose behavior can be inspected.

InvestorClaw v4.1.34 is not the final form of that idea. It is an empirical baseline: 13 MCP tools, 17 dashboard tabs, 8 provider keys, 30 COBOL prompts, 30 personas plus Dr. Stonk, a 1.14 GB CPU-only image, and a measured move from 1/250 to 29/30 across four runtimes. Production has been running on TYPHON since 2026-05-05.

That is what a skill looks like when it stops being a prompt and starts being software.

## Closing line

The LLM can talk after the engine proves the facts.

## Publish checklist

- Final read pass for tone, word count, and banned-word scan.
- Screenshots needed: dashboard Overview, EOD sample, and a King Donny x Glorb exchange.
- Verify cross-links to [docs/DASHBOARD.md](../DASHBOARD.md), [docs/STONKMODE.md](../STONKMODE.md), [docs/MCP_TOOLS_REFERENCE.md](../MCP_TOOLS_REFERENCE.md), [harness/cobol/AGENTIC_COBOL_SPEC.md](../../harness/cobol/AGENTIC_COBOL_SPEC.md), [harness/cobol/nlq-prompts.json](../../harness/cobol/nlq-prompts.json), and [mnemos-os/mnemos-ic-runtime](https://github.com/mnemos-os/mnemos-ic-runtime).
- CTA should point at `clawhub install perlowja/investorclaw` and `/plugin marketplace add https://gitlab.com/argonautsystems/InvestorClaude.git`.
- Confirm image digest and size against the v4.1.34 release notes before publication.

## Notes / cuts

- Could include a blow-by-blow of the v4.1.0 to v4.1.34 five-day march, but that belongs in a release post, not this architecture piece.
- Could include the full 13-tool table, but the MCP reference already does that better.
- Could quote more of King Donny and Glorb, but screenshots will land harder than another blockquote.
- The scorer-correctness war story from v2.5.x is still useful, but here it is background radiation. This piece is about the package shape.
- The "container is heavy" objection probably deserves its own follow-up once more agent runtimes treat MCP service dependencies as first-class installs.
