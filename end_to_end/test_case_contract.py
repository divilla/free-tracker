import json
import sys
from support import ScaffoldSystemCase


class CaseContractE2E(ScaffoldSystemCase):
    def test_S003_T41_e2e(self):
        result=self.command([sys.executable,'tool/check_case_contract.py'])
        self.assertGreaterEqual(json.loads(result.stdout)['case_count'],93)
        file=self.root/'agent/changes/003-workflow-run-state.md'
        original=file.read_text()
        file.write_text(original.replace('E2E test (`file :: name`)','No E2E mapping'))
        before=self.snapshot()
        result=self.command([sys.executable,'tool/check_case_contract.py'],ok=False)
        self.assertIn('missing required E2E',result.stderr)
        self.assertEqual(before,self.snapshot())
