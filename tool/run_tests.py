#!/usr/bin/env python3
"""App-only test workflow. Never accept stale, empty, skipped or failed suites."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import check_coverage
import check_scaffold

UNIT_PATHS = ['test/settings/domain', 'test/settings/application', 'test/settings/data',
              'test/settings/presentation', 'test/app']
CORE_PATHS = UNIT_PATHS[:2]
E2E_PATHS = ['integration_test/app_info_test.dart', 'integration_test/app_info_platform_test.dart',
            'integration_test/change_cases_test.dart']


def machine_results(output, paths, root=None):
    suites, tests, completed = {}, {}, {}
    success = False
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue  # Flutter also prints build/device diagnostics.
        if not isinstance(event, dict):
            continue  # Flutter's machine envelope may contain diagnostic arrays.
        kind = event.get('type')
        if kind == 'suite':
            suites[event['suite']['id']] = event['suite']['path'].replace('\\', '/')
        elif kind == 'testStart':
            tests[event['test']['id']] = event['test']
        elif kind == 'testDone':
            completed[event['testID']] = event
        elif kind == 'done':
            success = event.get('success') is True
        elif kind == 'error':
            raise ValueError('test reported error: ' + event.get('error', 'unknown'))
    counts = {p: 0 for p in paths}
    names, executed = [], []
    if set(tests) != set(completed):
        raise ValueError('test execution did not complete every started case')
    for test_id, event in completed.items():
        if event.get('hidden'):
            continue
        if event.get('skipped') or event.get('result') != 'success':
            raise ValueError('failed or skipped test')
        test = tests[test_id]
        path = suites[test['suiteID']]
        names.append(test['name'])
        relative = Path(path)
        if relative.is_absolute() and root is not None:
            relative = relative.relative_to(root)
        executed.append({'file': relative.as_posix(), 'name': test['name']})
        for required in paths:
            if required in path:
                counts[required] += 1
    if not success or any(n == 0 for n in counts.values()):
        raise ValueError('missing successful nonempty executed suite: ' + str(counts))
    return {'counts': counts, 'tests': names, 'executed': executed}


class Runner:
    def __init__(self, root, invoke=subprocess.run, which=shutil.which, env=None):
        self.root = root.resolve()
        self.invoke = invoke
        self.which = which
        self.env = os.environ if env is None else env
        self.commands = []

    def tools(self, names):
        for name in names:
            if not self.which(name):
                raise ValueError('required executable missing: ' + name)

    def command(self, args, report):
        print('+ ' + ' '.join(args), flush=True)
        result = self.invoke(args, cwd=self.root, capture_output=True, text=True)
        output = result.stdout + result.stderr
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(output)
        self.commands.append({'command': args, 'exit': result.returncode, 'report': str(report.relative_to(self.root))})
        if result.returncode:
            print(output[-12000:], file=sys.stderr)
            raise ValueError('command failed: ' + ' '.join(args))
        return output

    def discover(self, paths):
        for name in paths:
            path = self.root / name
            if not (path.is_file() and path.name.endswith('_test.dart')) and not list(path.rglob('*_test.dart')):
                raise ValueError('empty required test discovery: ' + name)

    def run(self, mode):
        reports = self.root / 'build/test-results' / mode
        if reports.exists():
            shutil.rmtree(reports)
        reports.mkdir(parents=True)
        result = {'mode': mode, 'commands': self.commands, 'status': 'failed'}
        result['started_utc'] = datetime.now(timezone.utc).isoformat()
        try:
            self.tools(['python3', 'dart', 'flutter', 'make'])
            generated = {p: (self.root / p).read_bytes() for p in check_coverage.GENERATED}
            self.command(['flutter', 'gen-l10n'], reports / 'generation.txt')
            if any((self.root / p).read_bytes() != content for p, content in generated.items()):
                raise ValueError('generated localization drift: review regenerated outputs and rerun')
            if mode == 'unit':
                coverage = self.root / 'coverage/lcov.info'
                coverage.unlink(missing_ok=True)
                self.discover(UNIT_PATHS)
                if not list((self.root / 'tool/tests').glob('test_*.py')):
                    raise ValueError('empty tooling discovery')
                output = self.command([sys.executable, '-m', 'unittest', 'discover', '-s', 'tool/tests', '-v'], reports / 'tooling.txt')
                count = re.search(r'Ran (\d+) tests?\b', output)
                if not count or int(count[1]) == 0 or '\nOK' not in output or 'skipped=' in output:
                    raise ValueError('tooling suite empty, skipped or incomplete')
                result['tooling_count'] = int(count[1])
                output = self.command(['dart', 'test', '--reporter=json', *CORE_PATHS], reports / 'core.jsonl')
                result['core'] = machine_results(output, CORE_PATHS, self.root)
                output = self.command(['flutter', 'test', '--coverage', '--machine', 'test'], reports / 'flutter.jsonl')
                result['flutter'] = machine_results(output, UNIT_PATHS, self.root)
                result['coverage'] = check_coverage.check(self.root, coverage)
                check_scaffold.check(self.root)
            else:
                self.tools(['adb'])
                device = self.env.get('ANDROID_DEVICE_ID', '')
                if not device:
                    raise ValueError('ANDROID_DEVICE_ID must explicitly select an Android target')
                output = self.command(['flutter', 'devices', '--machine'], reports / 'devices.json')
                devices = json.loads(output)
                if not any(d['id'] == device and d.get('targetPlatform', '').startswith('android') for d in devices):
                    raise ValueError('selected Android device absent or non-Android: ' + device)
                self.discover(E2E_PATHS)
                result['device'] = device
                result['suites'] = []
                for index, path in enumerate(E2E_PATHS):
                    output = self.command(['flutter', 'test', '--machine', '-d', device, path], reports / f'android-{index}.jsonl')
                    summary = machine_results(output, [path], self.root)
                    required = ([f'S001_E{i:02}_' for i in range(1, 11)] if index == 0
                                else ['S001_P01_'] if index == 1 else [])
                    if any(not any(n.startswith(prefix) for n in summary['tests']) for prefix in required):
                        raise ValueError('required Android scenario did not execute')
                    result['suites'].append(summary)
            result['status'] = 'passed'
        finally:
            # Fresh invocation metadata, even on a failed command.
            revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=self.root, capture_output=True, text=True)
            result['revision'] = revision.stdout.strip()
            inventory = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
                                       cwd=self.root, capture_output=True, text=True)
            digest = hashlib.sha256()
            for name in sorted(set(inventory.stdout.split('\0'))):
                if name.startswith(('lib/', 'android/', 'test/', 'integration_test/', 'tool/')) or name in (
                    'pubspec.yaml', 'pubspec.lock', 'Makefile', 'l10n.yaml', '.flutter-version', 'analysis_options.yaml'
                ):
                    source = self.root / name
                    if source.is_file():
                        digest.update(name.encode() + b'\0' + source.read_bytes() + b'\0')
            result['source_sha256'] = digest.hexdigest()
            (reports / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['unit', 'e2e'])
    args = parser.parse_args()
    try:
        Runner(Path(__file__).resolve().parents[1]).run(args.mode)
    except (ValueError, OSError, KeyError, IndexError) as error:
        print('tests: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
