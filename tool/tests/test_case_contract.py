"""Test traceability policy, including missing mappings and unexecuted tests."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import case_contract

REPO = Path(__file__).resolve().parents[2]
HEADER = '| Case ID | Requirement(s) | Fixture, action, expected assertions | Unit test (`file :: name`) | E2E test (`file :: name`) |\n| --- | --- | --- | --- | --- |\n'
ROW = '| S999-T01 | S999-R01 | Invoke CLI with valid fixture; assert saved result | `tool/tests/test_example.py :: test_S999_T01_unit` | `end_to_end/test_example.py :: test_S999_T01_e2e` |\n'
DOCUMENT = '# Example\n\n| ID | Requirement |\n| --- | --- |\n| S999-R01 | Save the result |\n\n' + HEADER + ROW


class CaseContractTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for directory in ('tool/tests', 'agent/changes', 'end_to_end'):
            (self.root / directory).mkdir(parents=True)
        self.scope = self.root / 'tool/test_scope.json'
        self.scope.write_text(json.dumps({'schema': 1, 'implemented_changes': ['999-example']}))
        self.document = self.root / 'agent/changes/999-example.md'
        self.document.write_text(DOCUMENT)
        for path in ('tool/tests/test_example.py', 'end_to_end/test_example.py'):
            (self.root / path).touch()

    def load(self):
        return case_contract.load_contract(self.root)

    def test_S000_T01_directory_contract(self):
        for name in ('agent', 'scripts'):
            self.assertTrue((REPO / name).is_dir())

    def test_S003_T01_complete_mappings(self):
        contract = self.load()
        for kind in ('unit', 'e2e'):
            result = case_contract.require_executed(contract, [contract['cases'][0][kind]], kind)
            self.assertEqual(result['mapped_requirements'], ['S999-R01'])
            self.assertEqual(result['mapped_cases'], ['S999-T01'])
        actual = case_contract.load_contract(REPO)
        self.assertGreaterEqual(len(actual['requirements']), 21)
        self.assertGreaterEqual(len(actual['cases']), 59)

    def test_S003_T02_unmapped_requirement(self):
        self.document.write_text(DOCUMENT.replace('| S999-R01 |', '| S999-R02 | Other behavior |\n| S999-R01 |', 1))
        with self.assertRaisesRegex(ValueError, 'S999-R02: missing unit-test mapping'):
            self.load()
        self.document.write_text(DOCUMENT.replace('| S999-R01 | Save', '| S999-R02 | Save'))
        with self.assertRaisesRegex(ValueError, 'unknown requirement mapping'):
            self.load()

    def test_S003_T03_unit_mapping_and_execution(self):
        for change in (lambda s: s.replace('Unit test (`file :: name`)', 'Other'),
                       lambda s: s.replace('tool/tests/test_example.py', '../escape.py'),
                       lambda s: s.replace('test_S999_T01_unit', 'generic'),
                       lambda s: s.replace('tool/tests/test_example.py', 'tool/tests/missing.py')):
            self.document.write_text(change(DOCUMENT))
            with self.assertRaises(ValueError):
                self.load()
        self.document.write_text(DOCUMENT)
        contract = self.load()
        for executed in ([], [{'file': 'wrong.py', 'name': 'test_S999_T01_unit'}],
                         [{'file': 'tool/tests/test_example.py', 'name': 'test_S999_T010_unit'}]):
            with self.assertRaises(ValueError):
                case_contract.require_executed(contract, executed, 'unit')
        # A case cannot mask a requirement whose mapped unit did not run.
        contract['requirements'].append({'id': 'S999-R02', 'unit_tests': [{'file': 'x.py', 'name': 'absent'}]})
        with self.assertRaisesRegex(ValueError, 'requirements: S999-R02'):
            case_contract.require_executed(contract, [contract['cases'][0]['unit']], 'unit')

    def test_S003_T04_e2e_mapping_and_execution(self):
        for change in (lambda s: s.replace('E2E test (`file :: name`)', 'Other'),
                       lambda s: s.replace('end_to_end/test_example.py', '../escape.py'),
                       lambda s: s.replace('test_S999_T01_e2e', 'generic'),
                       lambda s: s.replace('end_to_end/test_example.py', 'end_to_end/missing.py')):
            self.document.write_text(change(DOCUMENT))
            with self.assertRaises(ValueError):
                self.load()
        self.document.write_text(DOCUMENT)
        contract = self.load()
        for executed in ([], [{'file': 'wrong.py', 'name': 'test_S999_T01_e2e'}],
                         [{'file': 'end_to_end/test_example.py', 'name': 'test_S999_T010_e2e'}]):
            with self.assertRaises(ValueError):
                case_contract.require_executed(contract, executed, 'e2e')

    def test_S003_T05_distinct_cases(self):
        self.document.write_text(DOCUMENT + ROW)
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            self.load()
        shared = 'test_S999_T01_S999_T02_e2e'
        self.document.write_text(DOCUMENT.replace('test_S999_T01_e2e', shared) +
                                 ROW.replace('S999-T01', 'S999-T02').replace('test_S999_T01_unit', 'test_S999_T02_unit').replace('test_S999_T01_e2e', shared))
        with self.assertRaisesRegex(ValueError, 'shared E2E'):
            self.load()

    def test_S003_T06_implemented_scope(self):
        future = self.root / 'agent/changes/998-future.md'
        future.write_text(DOCUMENT.replace('S999', 'S998').replace('test_example.py', 'future.py'))
        self.assertEqual(len(self.load()['cases']), 1)
        self.assertEqual(len(case_contract.load_contract(self.root, active_only=False)['cases']), 2)
        for active in ([], ['999-example', '999-example'], ['998-future'], ['997-missing']):
            self.scope.write_text(json.dumps({'schema': 1, 'implemented_changes': active}))
            with self.assertRaises(ValueError):
                self.load()

    def test_S003_T07_exact_report_identities(self):
        contract = self.load()
        executed = [contract['cases'][0]['unit']]
        # Unit success cannot satisfy a case's separate E2E execution gate.
        with self.assertRaisesRegex(ValueError, 'missing executed e2e'):
            case_contract.require_executed(contract, executed, 'e2e')
        # An executed but unmapped case cannot bypass case-unit coverage either.
        partial = copy.deepcopy(contract)
        partial['cases'].append({'id': 'S999-T02', 'unit': {'file': 'u.py', 'name': 'absent'}})
        with self.assertRaisesRegex(ValueError, 'case rows: S999-T02'):
            case_contract.require_executed(partial, executed, 'unit')
