.PHONY: unit-test end-to-end-test workflow-test

unit-test:
	python3 tool/run_tests.py unit
	python3 tool/run_change_tests.py unit

end-to-end-test:
	python3 tool/run_change_tests.py e2e

# Deterministic tooling checks use temporary repositories, never live Codex/remotes.
workflow-test:
	perl scripts/test-unit-codex-code-implement.pl
	perl scripts/test-unit-codex-review-loop.pl
	perl scripts/test-unit-codex-change-write.pl
	perl scripts/test-codex-session.pl
	perl scripts/test-clean-checkout.pl
	bash scripts/test-codex-change-write.sh
	bash scripts/test-change-review.sh
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
