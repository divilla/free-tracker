#!/usr/bin/env python3
"""Separate process/system tests. Skips/expected failures never satisfy a case."""
import json
from pathlib import Path
import sys
import unittest

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'end_to_end'))

class RecordedResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.successes = []

    def addSuccess(self, test):
        super().addSuccess(test)
        module, _, name = test.id().rsplit('.', 2)
        self.successes.append({'file': 'end_to_end/' + module.replace('.', '/') + '.py', 'name': name})


suite = unittest.defaultTestLoader.discover(str(root / 'end_to_end'))
result = unittest.TextTestRunner(verbosity=2, resultclass=RecordedResult).run(suite)
passed = (result.wasSuccessful() and result.testsRun > 0 and not result.skipped
          and not result.expectedFailures and result.testsRun == len(result.successes))
report = root / 'build/test-results/change-e2e/host.json'
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({'status': 'passed' if passed else 'failed',
    'count': result.testsRun, 'executed': result.successes}, indent=2) + '\n')
sys.exit(0 if passed else 1)
