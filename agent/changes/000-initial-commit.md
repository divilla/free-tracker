# S000 — Initial repository layout

Establish the `agent/` documentation and `scripts/` tooling directories. The
original wording used singular `script`; the maintained directory is `scripts/`.

| ID | Requirement |
| --- | --- |
| S000-R01 | Both maintained directories are present in the repository. |

## Test cases and traceability

| Case ID | Requirement(s) | Fixture, action, expected assertions | Unit test (`file :: name`) | E2E test (`file :: name`) |
| --- | --- | --- | --- | --- |
| S000-T01 | S000-R01 | Inspect the repository layout and invoke `git ls-tree` on HEAD; both `agent` and `scripts` must be returned | `tool/tests/test_case_contract.py :: test_S000_T01_directory_contract` | `end_to_end/test_scaffold.py :: test_S000_T01_e2e` |

Both `make unit-test` and `make end-to-end-test` execute this case. This is not
evidence that later app features or delivery gates are complete.
