"""Traceability through public checker, runner and Make command boundaries."""
import json
import os
from pathlib import Path
import shutil
import sys
from support import ScaffoldSystemCase

DOCUMENT = 'agent/changes/003-test-traceability.md'


class CaseContractE2E(ScaffoldSystemCase):
    def audit(self, ok=True):
        before = self.snapshot()
        result = self.command([sys.executable, 'tool/check_case_contract.py'], ok=ok)
        self.assertEqual(before, self.snapshot())
        return result

    def test_S003_T01_e2e(self):
        result = json.loads(self.audit().stdout)
        self.assertGreaterEqual(result['requirement_count'], 21)
        self.assertGreaterEqual(result['case_count'], 59)
        self.assertEqual(len(result['cases']), result['case_count'])

    def test_S003_T02_e2e(self):
        path = self.root / DOCUMENT
        path.write_text(path.read_text().replace('| S003-R01 |', '| S003-R99 | Unmapped behavior |\n| S003-R01 |', 1))
        self.assertIn('S003-R99: missing unit-test mapping', self.audit(False).stderr)

    def test_S003_T03_e2e(self):
        path = self.root / DOCUMENT
        original = path.read_text()
        for old, new in [('Unit test (`file :: name`)', 'No unit mapping'),
                         ('tool/tests/test_case_contract.py', 'tool/tests/missing.py')]:
            path.write_text(original.replace(old, new))
            self.assertIn('unit', self.audit(False).stderr)
        path.write_text(original)

    def test_S003_T04_e2e(self):
        path = self.root / DOCUMENT
        original = path.read_text()
        for old, new in [('E2E test (`file :: name`)', 'No E2E mapping'),
                         ('end_to_end/test_case_contract.py', 'end_to_end/missing.py')]:
            path.write_text(original.replace(old, new))
            self.assertIn('E2E' if old.startswith('E2E') else 'e2e', self.audit(False).stderr)
        path.write_text(original)

    def test_S003_T05_e2e(self):
        path = self.root / DOCUMENT
        original = path.read_text()
        rows = [line for line in original.splitlines() if line.startswith('| S003-T')]
        path.write_text(original + '\n' + rows[0] + '\n')
        self.assertIn('duplicate', self.audit(False).stderr)
        shared = 'test_S003_T01_S003_T02_e2e'
        path.write_text(original.replace('test_S003_T01_e2e', shared).replace('test_S003_T02_e2e', shared))
        self.assertIn('shared E2E', self.audit(False).stderr)

    def test_S003_T06_e2e(self):
        scope = self.root / 'tool/test_scope.json'
        original = json.loads(scope.read_text())
        original_count = json.loads(self.audit().stdout)['case_count']
        future = self.root / 'agent/changes/999-future.md'
        future.write_text("""# Future authored change

| ID | Requirement |
| --- | --- |
| S999-R01 | Future behavior |

| Case ID | Requirement(s) | Fixture/action/assertions | Unit test (`file :: name`) | E2E test (`file :: name`) |
| --- | --- | --- | --- | --- |
| S999-T01 | S999-R01 | Future fixture/action/assertions | `tool/tests/future.py :: test_S999_T01_unit` | `end_to_end/future.py :: test_S999_T01_e2e` |
""")
        # Authored mappings are auditable without implementing future suites.
        self.assertEqual(json.loads(self.audit().stdout)['case_count'], original_count + 1)
        for active, diagnostic in [([], 'nonempty'),
                                   (original['implemented_changes'] * 2, 'duplicate'),
                                   (original['implemented_changes'] + ['999-missing'], 'no case rows'),
                                   (original['implemented_changes'] + ['999-future'], 'missing unit test file')]:
            scope.write_text(json.dumps({**original, 'implemented_changes': active}))
            self.assertIn(diagnostic, self.audit(False).stderr)

    def test_S003_T07_e2e(self):
        # Controlled child reports test the real Make/runner policy, not app behavior.
        doc = self.root / 'agent/changes/999-fixture.md'
        doc.write_text('''# Fixture

| ID | Requirement |
| --- | --- |
| S999-R01 | Exercise test gates |

| Case ID | Requirement(s) | Fixture/action/assertions | Unit test (`file :: name`) | E2E test (`file :: name`) |
| --- | --- | --- | --- | --- |
| S999-T01 | S999-R01 | Invoke runner with controlled reports; assert gate result | `tool/tests/test_fixture.py :: test_S999_T01_unit` | `end_to_end/test_fixture.py :: test_S999_T01_e2e` |
''')
        self.write('tool/tests/test_fixture.py', '# controlled report fixture\n')
        self.write('end_to_end/test_fixture.py', '# controlled report fixture\n')
        self.write('tool/test_scope.json', json.dumps({'schema': 1, 'implemented_changes': ['999-fixture']}))
        self.write('tool/run_tests.py', '''import json, os, sys
from pathlib import Path
mode=sys.argv[1]
p=Path('build/test-results')/mode
p.mkdir(parents=True, exist_ok=True)
fault=os.environ.get('REPORT_FAULT','')
unit={'file':'tool/tests/test_fixture.py','name':'test_S999_T01_unit'}
e2e={'file':'end_to_end/test_fixture.py','name':'test_S999_T01_e2e'}
if fault=='child-failed': sys.exit(8)
if mode=='unit':
    (p/'tooling.txt').write_text('test_S999_T01_unit (test_fixture.Fixture.test_S999_T01_unit) ... ok\\n' if fault!='missing-unit' else '')
    report={'status':'passed','core':{'executed':[]},'flutter':{'executed':[]}}
else:
    report={'status':'passed','suites':[{'counts':{'integration_test/fixture.dart':1},'tests':[],'executed':[]}]}
(p/'summary.json').write_text(json.dumps(report))
''')
        self.write('tool/run_host_e2e.py', '''import json, os
from pathlib import Path
p=Path('build/test-results/change-e2e/host.json')
p.parent.mkdir(parents=True,exist_ok=True)
test={'file':'end_to_end/test_fixture.py','name':'test_S999_T01_e2e'}
fault=os.environ.get('REPORT_FAULT','')
if fault=='wrong-file': test['file']='end_to_end/wrong.py'
p.write_text(json.dumps({'status':'passed','count':0 if fault=='empty' else 1,'executed':[test]}))
''')
        for name in ('codex-code-implement', 'codex-review-loop', 'codex-change-write'):
            self.write('scripts/test-unit-' + name + '.pl', 'print "1..1\\nok 1 - controlled helper boundary\\n";\n')
        self.write('scripts/test-codex-session.pl', 'print "1..1\\nok 1 - controlled session boundary\\n";\n')
        binary = self.root / 'controlled-bin'
        binary.mkdir()
        (binary / 'python3').symlink_to(sys.executable)
        fake_make = binary / 'make'
        fake_make.write_text('#!/bin/sh\n[ "$1" = workflow-test ]\n')
        fake_make.chmod(0o755)
        env = {**self.env, 'PATH': str(binary) + os.pathsep + os.environ['PATH']}
        real_make = shutil.which('make')
        for target, faults in [('unit-test', ['', 'missing-unit', 'child-failed']),
                               ('end-to-end-test', ['', 'wrong-file', 'empty', 'child-failed'])]:
            for fault in faults:
                with self.subTest(target=target, fault=fault):
                    self.command([real_make, target], ok=not fault, env={**env, 'REPORT_FAULT': fault})
                    if target == 'unit-test' and fault == 'child-failed':
                        continue  # Make stops at the first failed child; no traceability report is emitted.
                    mode = 'unit' if target == 'unit-test' else 'e2e'
                    report = json.loads((self.root / f'build/test-results/change-{mode}/summary.json').read_text())
                    self.assertEqual(report['status'], 'failed' if fault else 'passed')
