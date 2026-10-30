---
name: mch-code-implement
description: Implement the current branch's change in an existing codebase, including contract checks, production code, acceptance tests, and verification. Use for `$mch-code-implement` requests; derive the reference change path from the branch rather than accepting a document-path argument.
---

# MCH Code Implement

Treat text after `$mch-code-implement` as additional constraints, not as a
document-path argument. Read the selected change before editing.

## Select the change

1. Inspect repository instructions and status. Get the current local branch with
   `git symbolic-ref --quiet --short HEAD`. If this fails (including detached
   HEAD or no Git repository), stop without editing and report the missing
   valid change branch.
2. Match the complete branch name against this exact regex:

   ```regex
   ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$
   ```

   Capture group 1 is the complete slug, including the numeric prefix. Preserve
   it exactly; do not pad, renumber, normalize, or derive it from another input.
   For example, `change/001-build-scaffold` gives `001-build-scaffold`, and
   `change/1000-fix_step-count` gives `1000-fix_step-count`. If the branch does
   not match, stop without editing and report the required branch format. Do
   not create, rename, or switch branches.
3. Use the repository-relative `agent/changes/<slug>.md` as the reference
   change. Do not substitute a path supplied in the request, select another
   change, or fall back to another directory. If the file is missing or cannot
   be read, stop without editing and report its exact expected path.

Do not commit or push; the caller handles commits.

## Establish the contract

1. Read `AGENTS.md`, `agent/PRD.md`, `agent/ARCHITECTURE.md`,
   `agent/PLAN.md`, `agent/IMPLEMENT.md`, and the selected change before editing.
   Require exactly one PLAN inventory row whose Slug equals the branch capture;
   verify its change ID matches the numeric prefix and its path resolves to
   `agent/changes/<slug>.md`. Check the document's ID, slug, scope and validation
   obligations against that row and its linked coverage/decisions/gates. If PLAN
   is missing/unreadable, the match is absent/duplicate, or identity/scope
   conflicts, stop without edits and report the exact mismatch. Do not select
   another row or invent an unplanned change. Read `skeleton/` only if it exists
   and is applicable; this repository does not require that directory.
2. Follow repository instructions and the PRD product requirements. Resolve
   conflicts between the selected change and architecture or existing protected
   contracts before editing; the change does not silently override them.
3. Inspect repository status plus the relevant implementation, tests,
   documentation, and build commands. Preserve unrelated user changes.
4. Treat protected references and declared contracts as binding. If the change
   conflicts with them or requires modifying them, stop before editing, report
   the exact mismatch, and request explicit direction. Never work around them.
5. Before implementation edits, verify the selected change's direct and
   transitive dependencies, applicable PLAN gates/decisions, and IMPLEMENT
   readiness against current code and recorded evidence at the exact `dev`
   baseline supplied or verified by the caller. A predecessor document, authored
   status, branch or merge alone does not prove the consumer's required code,
   tests or device evidence exists. Missing, stale or contradictory prerequisite
   evidence blocks dependent work: report the specific dependency, evidence and
   next action without editing or claiming readiness. Do not refresh/switch the
   baseline silently or advance script-owned gates.
   Distinguish prerequisites from outputs this change must produce: do not
   require its own implementation/tests/device results before starting. Apply
   PLAN §7's bootstrap/manual-equivalent workflow for S001–S004; existing scripts
   do not by themselves prove GW. Documented future obligations may remain
   pending only when they do not block this stage.

## Implement

1. Extract behavior, acceptance criteria, edge cases, public-contract effects,
   and validation into a short checklist.
2. Resolve details from repository evidence. Ask only when an unresolved choice
   would materially change the contract or result.
3. Follow the project architecture and applicable existing contracts, including
   any maintained skeleton when present. Use the narrowest existing extension points
   and match current formatting and error handling.
4. Make the smallest complete production change, including affected tests,
   documentation, and fixtures. Avoid unrelated cleanup and speculative design.
5. Do not introduce a public or shared type, function, method, schema, or other
   external contract until the repository's contract-change process is met.
6. Give every acceptance-criteria bullet a meaningful test. Avoid redundant
   tests unless they prove a distinct criterion or regression.

## Verify

Run formatting and targeted tests first, then all repository-required checks
and coverage thresholds. Inspect the final diff for accidental edits, missing
criteria, contract drift, and generated-file requirements. Fix failures caused
by the change; report the exact command and evidence for unrelated failures.

For the selected change under `agent/changes/`, record the completed implementation
in the repository-root `implementation-log.md`. The skill owns this write; do
not leave it to caller scripts. Append one block in this exact form, keeping one
blank line after it:

```text
YYYY-DD-MM HH:MM <slug>
+<added> -<removed> code - +<added> -<removed> tests --- change
```

Count the complete implementation diff, including untracked files, but exclude
`implementation-log.md` itself. Classify paths under `int-tests`, `test`,
`tests`, or `testdata`, and filenames ending in `_test`, `.test`, or `.spec`
before their extension, as tests; classify all others as code. Count binary
files as zero lines.

Declare completion only when every criterion is implemented and tested,
contracts remain aligned, and required checks pass. Summarize the behavior,
verification, and any remaining limitation with links to key files.
