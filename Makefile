# InvestorClaw — local CI mirror.
#
# Mirrors .gitlab-ci.yml so contributors can run the same gate the pipeline
# runs, without depending on shared-runner minutes (this project's shared
# runners are intentionally off — codex review + local validation is the
# canonical path).
#
# IC_DECOMPOSITION moved the Python engine to ic-engine (pulled as a container)
# and removed the TypeScript build, so there is nothing to uv-sync or npm-build
# at the repo root; the gate validates the plugin manifests + skill structure.
#
# Usage:
#   make ci          # validate plugin manifests + skill structure (use before push)
#   make validate    # same gate, explicit name

.PHONY: ci validate clean

ci: validate
	@echo "ci: all gates passed"

validate:
	python3 scripts/validate-plugin.py

clean:
	rm -rf .pytest_cache .ruff_cache __pycache__ node_modules
