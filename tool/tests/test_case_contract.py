import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import case_contract


class CaseContractTests(unittest.TestCase):
    def test_S000_T01_directory_contract(self):
        root=Path(__file__).resolve().parents[2]
        for name in ('agent','scripts'):
            self.assertTrue((root/name).is_dir())

    def test_S003_T41_required_per_row_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'tool').mkdir(); (root/'agent/changes').mkdir(parents=True)
            (root/'end_to_end').mkdir(); (root/'end_to_end/test_example.py').touch()
            (root/'tool/test_scope.json').write_text(json.dumps({'schema':1,'implemented_changes':['999-example']}))
            path=root/'agent/changes/999-example.md'
            header='| Case ID | Requirement | Fixture/action/assertions | Unit test | E2E test (`file :: name`) |\n| --- | --- | --- | --- | --- |\n'
            row='| S999-T01 | R01 | Invoke CLI with valid fixture; assert saved result | tests.py :: test_S999_T01_unit | `end_to_end/test_example.py :: test_S999_T01_e2e` |\n'
            path.write_text(header+row)
            cases=case_contract.load_cases(root)
            self.assertEqual(len(cases),1)
            with self.assertRaisesRegex(ValueError,'empty executed'):
                case_contract.require_executed(cases,[],'e2e')
            with self.assertRaisesRegex(ValueError,'missing executed'):
                case_contract.require_executed(cases,[{'file':'wrong.py','name':'test_S999_T01_e2e'}],'e2e')
            with self.assertRaisesRegex(ValueError,'missing executed'):
                case_contract.require_executed(cases,['test_S999_T010_unit'],'unit')
            self.assertEqual(case_contract.require_executed(cases,[{'file':cases[0]['file'],'name':cases[0]['name']}],'e2e')['case_count'],1)
            self.assertEqual(case_contract.require_executed(cases,['test_S999_T01_unit'],'unit')['case_count'],1)
            for bad in (header+row+row, (header+row).replace('E2E test (`file :: name`)','Other'),
                        (header+row).replace('end_to_end/test_example.py','../escape.py'),
                        (header+row).replace('test_S999_T01_e2e','generic_test')):
                with self.subTest(document=bad):
                    path.write_text(bad)
                    with self.assertRaises(ValueError): case_contract.load_cases(root)
            path.write_text(header+row)
            (root/'end_to_end/test_example.py').unlink()
            with self.assertRaisesRegex(ValueError,'missing E2E test file'): case_contract.load_cases(root)
