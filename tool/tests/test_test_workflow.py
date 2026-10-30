"""S001 runner policy tests: subprocess doubles prove failure policy, not app success."""
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_coverage
import run_tests

REPO = Path(__file__).resolve().parents[2]


def machine(paths):
    events = []
    for i, path in enumerate(paths):
        events.append({'type': 'suite', 'suite': {'id': i, 'path': path}})
        names = [f'S001_E{n:02}_case' for n in range(1, 11)] if path == run_tests.E2E_PATHS[0] else ['S001_P01_case'] if path == run_tests.E2E_PATHS[1] else ['unit behavior']
        for j, name in enumerate(names):
            test_id = i * 100 + j
            events += [{'type': 'testStart', 'test': {'id': test_id, 'suiteID': i, 'name': name}},
                       {'type': 'testDone', 'testID': test_id, 'hidden': False, 'skipped': False, 'result': 'success'}]
    return '\n'.join(json.dumps(e) for e in events + [{'type': 'done', 'success': True}])


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path in run_tests.UNIT_PATHS:
            target = self.root / path / 'behavior_test.dart'
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('test')
        for path in run_tests.E2E_PATHS + ['tool/tests/test_policy.py', 'lib/core.dart']:
            target = self.root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text('source')
        self.coverage = self.root / 'coverage/lcov.info'
        self.coverage.parent.mkdir()
        self.calls = []
        self.transform = lambda args, result: result
        for path in check_coverage.GENERATED:
            target = self.root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text('generated')

    def lcov(self):
        return 'SF:lib/core.dart\nDA:1,1\nDA:2,1\nend_of_record\n'

    def invoke(self, args, **kwargs):
        self.calls.append(args)
        if 'gen-l10n' in args:
            output = ''
        elif '-m' in args:
            output = '\nRan 12 tests in 0.01s\n\nOK\n'
        elif args[:2] == ['dart', 'test']:
            output = machine(run_tests.CORE_PATHS)
        elif args[:2] == ['flutter', 'devices']:
            output = json.dumps([{'id': 'chosen', 'targetPlatform': 'android-x64'}])
        elif '--coverage' in args:
            self.coverage.write_text(self.lcov()); output = machine(run_tests.UNIT_PATHS)
        else:
            output = machine([args[-1]])
        return self.transform(args, subprocess.CompletedProcess(args, 0, output, ''))

    def run_workflow(self, mode='unit', which=lambda _: '/tool', env=None):
        runner = run_tests.Runner(self.root, self.invoke, which, {'ANDROID_DEVICE_ID': 'chosen'} if env is None else env)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), patch.object(run_tests.check_scaffold, 'check'):
            return runner.run(mode)

    def test_S001_T20_unit_runner_executes_all_required_suites(self):
        result = self.run_workflow()
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(set(result['flutter']['counts']), set(run_tests.UNIT_PATHS))
        self.assertEqual(result['coverage']['line_percent'], 100)
        self.assertTrue(any(c[:2] == ['dart', 'test'] for c in self.calls))
        self.assertTrue(any('--coverage' in c and '--machine' in c for c in self.calls))
        self.assertTrue(any('-m' in c and 'unittest' in c for c in self.calls))

    def test_S001_T21_missing_unit_tool_or_failed_test_fails_missing(self):
        for missing in ['python3', 'dart', 'flutter', 'make']:
            with self.subTest(missing=missing), self.assertRaisesRegex(ValueError, missing):
                self.run_workflow(which=lambda name: None if name == missing else '/tool')

    def test_S001_T21_missing_unit_tool_or_failed_test_fails_subprocess(self):
        for failing in ['unittest', 'dart', 'flutter']:
            self.transform = lambda args, result: subprocess.CompletedProcess(args, 7, '', 'failure') if failing in args else result
            with self.subTest(failing=failing), self.assertRaisesRegex(ValueError, 'command failed'):
                self.run_workflow()

    def test_S001_T22_empty_required_suite_or_stale_report_fails_discovery(self):
        for file in (self.root / run_tests.UNIT_PATHS[0]).glob('*'):
            file.unlink()
        with self.assertRaisesRegex(ValueError, 'discovery'):
            self.run_workflow()

    def test_S001_T22_empty_required_suite_or_stale_report_fails_tooling(self):
        self.transform = lambda args, result: subprocess.CompletedProcess(args, 0, '\nRan 0 tests\nOK\n', '') if '-m' in args else result
        with self.assertRaisesRegex(ValueError, 'tooling suite'):
            self.run_workflow()

    def test_S001_T22_empty_required_suite_or_stale_report_fails_each_layer(self):
        for omitted in run_tests.UNIT_PATHS:
            self.transform = lambda args, result: subprocess.CompletedProcess(args, 0, machine([p for p in run_tests.UNIT_PATHS if p != omitted]), '') if '--coverage' in args else result
            with self.subTest(layer=omitted), self.assertRaisesRegex(ValueError, 'nonempty'):
                self.run_workflow()

    def test_S001_T22_empty_required_suite_or_stale_report_fails_stale(self):
        report = self.root / 'build/test-results/unit/flutter.jsonl'; report.parent.mkdir(parents=True)
        report.write_text(machine(run_tests.UNIT_PATHS))
        self.coverage.write_text(self.lcov())
        self.transform = lambda args, result: subprocess.CompletedProcess(args, 0, '', '') if '--coverage' in args else result
        with self.assertRaises(ValueError): self.run_workflow()
        self.assertEqual(report.read_text(), '')
        summary = json.loads((report.parent / 'summary.json').read_text()); self.assertEqual(summary['status'], 'failed')

    def test_S001_T23_incomplete_or_insufficient_line_coverage_fails_missing(self):
        with self.assertRaises(OSError): check_coverage.check(self.root, self.coverage)

    def test_S001_T24_only_genuinely_generated_sources_are_excluded(self):
        for path in check_coverage.GENERATED:
            target = self.root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text('generated')
        self.coverage.write_text(self.lcov())
        self.assertEqual(check_coverage.check(self.root, self.coverage)['line_total'], 2)
        for name in ['lib/handwritten.dart', 'lib/generated/maintained.dart']:
            (self.root / name).parent.mkdir(parents=True, exist_ok=True); (self.root / name).write_text('handwritten')
            with self.assertRaisesRegex(ValueError, 'missing handwritten'):
                check_coverage.check(self.root, self.coverage)
            (self.root / name).unlink()

    def test_S001_T24_only_genuinely_generated_sources_are_excluded_drift(self):
        original = self.invoke
        def drift(args, **kwargs):
            result = original(args, **kwargs)
            if 'gen-l10n' in args:
                (self.root / sorted(check_coverage.GENERATED)[0]).write_text('changed')
            return result
        self.invoke = drift
        with self.assertRaisesRegex(ValueError, 'localization drift'):
            self.run_workflow()

    def test_S001_T22_empty_required_suite_or_stale_report_fails_coverage(self):
        self.coverage.write_text(self.lcov())
        original = self.invoke
        def no_new_coverage(args, **kwargs):
            result = original(args, **kwargs)
            if '--coverage' in args: self.coverage.unlink()
            return result
        self.invoke = no_new_coverage
        with self.assertRaises(OSError): self.run_workflow()

    def test_S001_T28_empty_or_failed_android_suite_fails_skipped(self):
        output = machine(run_tests.E2E_PATHS).replace('"skipped": false', '"skipped": true')
        with self.assertRaisesRegex(ValueError, 'skipped'):
            run_tests.machine_results(output, run_tests.E2E_PATHS)

    def test_S001_T20_unit_runner_executes_all_required_suites_machine_diagnostics(self):
        result = run_tests.machine_results('[]\nnot-json\n' + machine(run_tests.UNIT_PATHS), run_tests.UNIT_PATHS)
        self.assertEqual(sum(result['counts'].values()), len(run_tests.UNIT_PATHS))

    def test_S001_T25_branch_reporting_is_separate_from_line_coverage(self):
        self.coverage.write_text(self.lcov()); self.assertIn('unavailable', check_coverage.check(self.root, self.coverage)['branches'])
        self.coverage.write_text(self.lcov().replace('end_of_record', 'BRDA:1,0,0,2\nBRDA:1,0,1,-\nend_of_record'))
        self.assertEqual(check_coverage.check(self.root, self.coverage)['branches'], '1/2')

    def test_S001_T26_android_runner_executes_controlled_and_real_suites(self):
        result = self.run_workflow('e2e')
        self.assertEqual(result['status'], 'passed'); self.assertEqual(len(result['suites']), 3)
        self.assertEqual({path for suite in result['suites'] for path in suite['counts']}, set(run_tests.E2E_PATHS))
        self.assertTrue(all('-d' in args and 'chosen' in args for args in self.calls if 'test' in args))

    def test_S001_T27_missing_or_wrong_android_environment_fails_unset(self):
        with self.assertRaisesRegex(ValueError, 'ANDROID_DEVICE_ID'): self.run_workflow('e2e', env={})

    def test_S001_T27_missing_or_wrong_android_environment_fails_tools(self):
        with self.assertRaisesRegex(ValueError, 'adb'): self.run_workflow('e2e', which=lambda n: None if n == 'adb' else '/tool')

    def test_S001_T27_missing_or_wrong_android_environment_fails_absent_or_nonandroid(self):
        for devices in [[], [{'id': 'chosen', 'targetPlatform': 'linux-x64'}]]:
            self.transform = lambda args, result: subprocess.CompletedProcess(args, 0, json.dumps(devices), '') if 'devices' in args else result
            with self.subTest(devices=devices), self.assertRaisesRegex(ValueError, 'absent or non-Android'): self.run_workflow('e2e')

    def test_S001_T28_empty_or_failed_android_suite_fails_discovery(self):
        (self.root / run_tests.E2E_PATHS[0]).unlink()
        with self.assertRaisesRegex(ValueError, 'discovery'): self.run_workflow('e2e')

    def test_S001_T28_empty_or_failed_android_suite_fails_each_suite(self):
        for path in run_tests.E2E_PATHS:
            for status in [0, 1]:
                self.transform = lambda args, result: subprocess.CompletedProcess(args, status, '', '') if path in args else result
                with self.subTest(path=path, status=status), self.assertRaises(ValueError): self.run_workflow('e2e')

    def test_S001_T28_empty_or_failed_android_suite_fails_stale(self):
        report = self.root / 'build/test-results/e2e/android-0.jsonl'; report.parent.mkdir(parents=True)
        report.write_text(machine([run_tests.E2E_PATHS[0]]))
        self.transform = lambda args, result: subprocess.CompletedProcess(args, 0, '', '') if 'test' in args else result
        with self.assertRaises(ValueError): self.run_workflow('e2e')
        self.assertEqual(report.read_text(), '')

    def test_S001_T31_make_targets_are_phony_and_propagate_failure(self):
        shutil.copy(REPO / 'Makefile', self.root / 'Makefile')
        binary = self.root / 'bin'; binary.mkdir()
        fake = binary / 'python3'; fake.write_text('#!/bin/sh\necho invoked >> marker\nexit 7\n'); fake.chmod(0o755)
        for target in ['unit-test', 'end-to-end-test']:
            (self.root / target).touch()
            result = subprocess.run(['make', target], cwd=self.root, env={**os.environ, 'PATH': str(binary) + ':' + os.environ['PATH']}, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / 'marker').read_text().splitlines(), ['invoked', 'invoked'])


def invalid_coverage(report):
    def test(self):
        self.coverage.write_text(report)
        with self.assertRaises((ValueError, IndexError)):
            check_coverage.check(self.root, self.coverage)
    return test

for name, content in {
    'empty': '', 'malformed': 'garbage', 'omitted_source': 'SF:lib/other.dart\nDA:1,1\nend_of_record',
    'uncovered': 'SF:lib/core.dart\nDA:1,0\nend_of_record',
    'below100': 'SF:lib/core.dart\n' + ''.join(f'DA:{i},{int(i != 999)}\n' for i in range(1,1001)) + 'end_of_record',
    'unterminated': 'SF:lib/core.dart\nDA:1,1', 'bad_line': 'SF:lib/core.dart\nDA:no,one\nend_of_record',
    'negative_hits': 'SF:lib/core.dart\nDA:1,-1\nend_of_record',
    'empty_source': 'SF:lib/core.dart\nend_of_record',
    'malformed_summary': 'SF:lib/core.dart\nDA:1,1\nLF:many\nend_of_record',
    'incorrect_summary': 'SF:lib/core.dart\nDA:1,1\nLF:2\nend_of_record',
    'garbage_in_record': 'SF:lib/core.dart\nDA:1,1\ngarbage\nend_of_record',
}.items():
    setattr(WorkflowTests, 'test_S001_T23_incomplete_or_insufficient_line_coverage_fails_' + name, invalid_coverage(content))
