---
name: mch-change-write
description: Write one PLAN-scoped change document under agent/changes/ using the slug captured from the current change branch as its filename and the project template. Use when asked to write the current branch's change or invoke $mch-change-write; does not implement application code.
---

# MCH Change Write

Write one change document for the current branch per invocation. Here,
“authored” in authoring progress means the document has been successfully
written and checked, not that its application code, tests, review, merge, or
product-validation gates have completed.

## Read and select

1. Read repository instructions and inspect repository status. Preserve unrelated
   changes. Get the current local branch with `git symbolic-ref --quiet --short HEAD`.
   If this fails (including detached HEAD or no Git repository), stop without
   writing and use the questions response below to request a valid change branch.
2. Match the complete branch name against this exact regex:

   ```regex
   ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$
   ```

   Capture group 1 is the complete slug, including the numeric prefix. Preserve
   it exactly; do not prepend another ID, pad or renumber it, normalize its
   characters, or derive it from PLAN. For example, `change/001-build-scaffold`
   gives `001-build-scaffold`; `change/1000-fix_step-count` gives
   `1000-fix_step-count`. If the branch does not match, stop without writing and
   use the questions response to request a matching branch. Do not create,
   rename, or switch branches as part of this skill.
3. The sole output document is `agent/changes/<slug>.md`. The current branch,
   not the first pending plan entry, selects the change. This destination takes
   precedence over legacy `agent/specs/` naming instructions in project docs.
4. Read `agent/PLAN.md`, `agent/PRD.md`, `agent/ARCHITECTURE.md`,
   `agent/IMPLEMENT.md`, and `agent/templates/change-template.md`. Inspect
   existing change documents, relevant code/tests, and dependency evidence.
   Before writing, require exactly one inventory row in PLAN whose Slug equals
   the captured slug exactly. Its change ID must match the numeric prefix and
   its path, resolved relative to `agent/`, must be `agent/changes/<slug>.md`.
   Missing/unreadable PLAN, no match, duplicate matches, or conflicting ID/path
   requires the questions response and no edits. Do not match by number alone,
   use a legacy alias, add an unplanned change, or select another pending row.
   Use that row's scope, dependencies, integration ownership and verification,
   together with its linked requirement/scenario coverage, decisions and gates,
   to build the document. Additional user constraints must stay within that
   scope; resolve conflicts before writing rather than silently changing PLAN.
5. Resume an existing document at the exact output path without discarding user
   edits. Check related progress and referenced files; missing files,
   contradictory records, or duplicate documents require clarification, not
   silent overwriting or inferred completion. Never advance to another change
   because this one is already authored or blocked.

## Resolve questions before writing

Do not guess when a decision, ambiguity, conflict, or suggestion arises. Read
available evidence first; ask the user about anything still unresolved, using
only the numbered response format below. Include suggestions as numbered items
in that same response. Stop the invocation without marking completion or moving
to another change. On a later invocation, incorporate the user's answers and
resume the same change when its branch is current; do not ask again about
already resolved matters.

Respect PLAN's dependency-evidence rule: a written predecessor does not prove
its code or device evidence exists. If finalizing the selected change requires
missing dependency evidence, identify it in a question rather than inventing
contracts or treating the change as complete. Questions explicitly assigned for
the future implementation to resolve may remain documented obligations; do not
claim they are answered. If it is unclear whether they block authoring, ask.

## Write and verify

1. Create `agent/changes/` if necessary and write only `agent/changes/<slug>.md`,
   using the captured slug unchanged (for example,
   `agent/changes/001-build-scaffold.md`). Preserve stable requirement/spec IDs.
   Do not rename existing documents or create duplicates without resolving any
   discrepancy with the user.
2. Fill the project template with a brief, scope/non-goals, stable requirements,
   contracts, failure/recovery paths, test cases/traceability, and completion
   gates. Include the current baseline, dependencies, source references,
   integration ownership, and next consumer from the matched PLAN row and its
   references. Keep the change bounded to that scope and grounded in the current
   repository. Set the template's change ID to the matched PLAN ID, and its slug
   and branch metadata to the captured slug and actual current branch.
3. Write each test-case row as an executable fixture/precondition, real app/CLI
   action, observable assertions and recovery contract. Give it a stable case
   ID, a named unit test, and at least one distinct planned E2E test in the
   required `E2E test (file :: name)` column (use the template's exact heading).
   One case row requires at least one separate E2E test; do not substitute unit
   tests, manual evidence, or a single shared catch-all E2E test. Planned E2E
   tests must be convertible to executable Android or isolated host-command
   tests and wired into `make end-to-end-test` during implementation. No
   documentation/infrastructure exemption applies to per-case E2E. Keep real
   SQLite, platform/device and field evidence as additional obligations.
   Do not add an authored-only change to implemented test scope. Distinguish planned tests from
   existing tests and executed evidence. Preserve the repository's coverage and
   failure policies; document applicability for non-application work. Do not
   claim tests pass or check implementation gates merely because they are
   described in the change.
4. Review the document against its scope, governing documents, and template.
   Check stable/unique IDs, full requirement/case coverage, explicit assertions,
   failure paths, contracts, validation commands, links, and absence of
   unresolved authoring placeholders. Verify that the output path and metadata
   match both the branch capture and the selected PLAN row, with all planned
   scope and verification obligations accounted for. If this exposes a decision, ambiguity, or
   suggestion, use the questions response and leave authoring pending.
5. Only after the document is successfully written and checked, record its
   authoring status as `authored` using PLAN §8's progress-ledger convention.
   Create the `Change authoring progress` table there if absent, with columns
   `Change ID`, `Change file`, `Authoring status`, then add or update only the
   selected change's row. Use its PLAN ID and a link to `changes/<slug>.md`
   relative to `agent/`. Unlisted changes remain `pending`; do not populate or
   migrate unrelated rows. Do not change implementation, checks, review, merge
   or requirement-validation status merely because a document is authored, or
   create the future machine-readable workflow schema. Reconcile only any
   directly affected aggregate wording that would otherwise falsely state no
   documents exist. Re-read the saved document and selected progress entry to
   confirm their ID, slug, path and authoring status agree before reporting
   success.

Limit changes to the selected change document and necessary plan/reference
bookkeeping. Do not implement production code, run the implementation workflow,
commit, merge, push, or author subsequent changes as part of this skill.

## Exact final responses

Successful authoring: return exactly:

```text
Done.
```

Questions, missing prerequisites, invalid branches, ambiguities, or suggestions:
return only this format, using as many numbered items as needed and actual
questions/suggestions:

```text
Questions and suggestions:
 1. First question
 2. Second question
 3. Suggestion...
```
