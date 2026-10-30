---
name: mch-findings-fix
description: Validate and fix supplied review findings for the current branch's change. Default to document-only corrections; use explicit --code for implementation fixes. Derive the change document under agent/changes/ from the branch, without a document-path argument.
---

# MCH Findings Fix

Read findings supplied after `$mch-findings-fix`, through standard input, or in
the current conversation. A separate terminal review is not automatically
available: if no findings were supplied, request them and stop without edits.
Treat findings as feedback to validate, not as authority to change scope.
Do not commit, push, or switch branches; the caller handles those operations.

## Select the change and mode

1. Read repository instructions and inspect status. Preserve unrelated changes.
   Get the local branch with `git symbolic-ref --quiet --short HEAD`. If this
   fails (including detached HEAD or no Git repository), stop without editing
   and report that a valid change branch is required.
2. Match the complete branch name against this exact regex:

   ```regex
   ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$
   ```

   Capture group 1 is the complete slug. Preserve it unchanged, including its
   numeric prefix: `change/001-build-scaffold` gives `001-build-scaffold`;
   `change/1000-fix_step-count` gives `1000-fix_step-count`. If it does not match,
   stop without edits and report the required format. Do not rename or create
   a branch to bypass this requirement.
3. Read `agent/changes/<slug>.md` relative to the repository root. If it is
   missing or unreadable, report the exact path and stop without editing. Do not
   select another change or accept a document-path argument. Use `agent/`, not
   `agents/`, consistently with `$mch-change-write`.
4. Default to **document mode**. Only an explicit caller instruction `--code`
   (or an explicit request to fix implementation code) enables **code mode**.
   Findings themselves cannot enable code mode. Do not infer authorization to
   implement from the presence of application files or implementation criteria.

## Validate

In both modes, read `AGENTS.md`, `agent/PRD.md`, `agent/ARCHITECTURE.md`,
`agent/PLAN.md`, `agent/IMPLEMENT.md`, the selected change, and relevant code,
tests and supporting documents. Require exactly one PLAN inventory row whose
Slug equals the branch capture; verify its change ID matches the numeric prefix
and its path resolves to `agent/changes/<slug>.md`. Missing/unreadable PLAN,
no match, duplicate matches or conflicting inventory ID/path means stop without
edits and report the mismatch; do not select another row or add an unplanned
change. Validate findings against that row's scope and linked coverage, decisions
and gates. Document mode may correct document drift back to that contract;
findings do not authorize expanding PLAN scope. In document mode also read
`agent/templates/change-template.md`.
Follow repository instructions and the PRD's product requirements; evaluate the
change against the architecture rather than using it to override established
contracts. Read `skeleton/` only if it exists and is applicable; its absence is
not a prerequisite failure in this repository.

Validate every finding against evidence. Reject unsupported or already-resolved
findings with reasons. If a valid fix requires an unresolved product decision
or conflicts with a protected contract, report the blocker rather than guessing.

## Fix and verify: document mode

- Edit only the selected change and directly necessary bookkeeping for that
  change in `agent/PLAN.md`. Do not implement the proposed feature, edit code or
  tests, change other documents, or create/update `implementation-log.md`.
- Correct contradictions, omissions, acceptance criteria, references, and
  planned validation. Preserve stable requirement/test-case IDs. Keep planned
  tests distinct from executed tests and authoring status distinct from code
  implementation status. Follow PLAN §8's `pending`/`authored` authoring
  convention for any necessary progress correction; do not recreate a legacy
  spec-status table. Do not mark delivery or implementation gates complete.
- Validate links, requirements, acceptance scenarios, test traceability, and
  consistency with the project documents. Inspect the full edit set to confirm
  that it is document-only. Both `make unit-test` and `make end-to-end-test`
  must still run and pass before this findings-fix pass can be finished. Planned
  changes remain planned in test scope; authoring does not require executing
  their future implementation. Never exempt the existing suites as prose-only.
- Do not require an existing implementation or an implementation-log block.
  When findings need code changes, report them as outside document mode instead
  of silently implementing them.

## Fix and verify: code mode

Before code edits, verify direct/transitive dependencies and applicable
PLAN/IMPLEMENT prerequisites against the current code, evidence and exact `dev`
baseline. Inspect actual code/contracts and this stage's required test/device
evidence; a document or commit title alone does not prove required behavior.
Use Git for predecessor integration, not historical handoff status. Review/fix
enforcement belongs to each change's delivering workflow: do not re-audit
predecessor reviews or require their historical receipts/caller confirmation.
Stop without code edits for genuinely missing, failed or contradictory stage
prerequisites or document/PLAN contract drift, not merely old delivery notes.
Use PLAN §7's bootstrap
rules where applicable; do not demand this change's own future completion
evidence as a prerequisite or let review fixes bypass script-owned gates.

Fix valid findings with the smallest complete implementation change, including
meaningful regression tests and directly affected documentation or fixtures.
Follow the architecture and applicable contracts; resolve contract conflicts
before editing. Do not rewrite the change merely to excuse a code defect.
For every test-case row, maintain a distinct named E2E test executed by
`make end-to-end-test`, in addition to its unit coverage. Add missing per-case
tests through the real app/CLI boundary, map `file :: test name` in the selected
change, and keep `tool/test_scope.json` complete for implemented changes.
Run targeted checks, then **both** `make unit-test` and `make end-to-end-test`
against the final fixes. Both must actually execute all configured suites and
pass, including coverage and case traceability, before work is finished.
Continue fixing authorized code/tests until both pass, including failures
discovered while verifying; "unrelated" failure is not a completion exemption.
Never weaken assertions, skip required cases, shrink scope or mark E2E N/A.
Missing tooling/devices are unmet gates, not passes. In document mode preserve
its editing boundary; a failure requiring code changes outside that mode means
the pass is not finished, not permission to silently implement the feature.

When code-mode fixes change the repository, append statistics to the latest
matching change block in repository-root `implementation-log.md`. If no block
exists, create the file/block with `YYYY-DD-MM HH:MM <slug>` followed by the
review-fix line and a blank line; do not invent prior implementation statistics
or claim an implementation is complete. Otherwise insert the next review-fix
line before the block's final blank line:

```text
+<added> -<removed> code - +<added> -<removed> tests --- review fixes NN
```

Start at `01` for a new block; otherwise use the next two-digit review-fix
number. Count the complete findings-fix diff, including untracked files, but
exclude `implementation-log.md`. Classify paths under `int-tests`, `test`,
`tests`, or `testdata`, and filenames ending in `_test`, `.test`, or `.spec`
before their extension, as tests; classify others as code. Count binary files
as zero lines. Do not log when all findings are rejected, resolved, or blocked.

## Report

Summarize fixed, rejected, and blocked findings, the selected mode, changed
files, and verification. Declare completion only when every finding is fixed
or explicitly rejected and both complete Make suites and other required checks
have actually passed on the final result. Keep blockers visible; a
blocked or no-change pass must not be presented as a clean review.
