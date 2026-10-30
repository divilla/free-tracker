.PHONY: unit-test end-to-end-test workflow-test

unit-test:
	python3 tool/run_tests.py unit

end-to-end-test:
	python3 tool/run_tests.py e2e

# Deterministic tooling checks use temporary repositories, never live Codex/remotes.
workflow-test:
	perl scripts/test-unit-workflow-run-state.pl
	perl scripts/test-workflow-run-state.pl
	perl scripts/test-workflow-evidence.pl
	perl scripts/test-unit-codex-code-implement.pl
	perl scripts/test-unit-codex-review-loop.pl
	bash scripts/test-codex-code-implement.sh
	bash scripts/test-codex-review-loop.sh
	bash scripts/test-codex-flow-run.sh
	perl scripts/test-merge-to-dev.pl
	perl scripts/test-promote-to-stage.pl
	perl scripts/test-promote-to-prod.pl
	perl scripts/test-release-branches.pl
	perl scripts/test-git-auth.pl
	bash scripts/test-create-change-branch.sh
	bash scripts/test-codex-plan-run.sh
