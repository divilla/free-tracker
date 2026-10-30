#!/usr/bin/env python3
"""Both stable Make targets enforce per-row executed unit and E2E coverage."""
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys

import case_contract


def run(mode, root):
    reports = root / 'build/test-results' / ('change-' + mode)
    reports.mkdir(parents=True, exist_ok=True)
    report = {'status': 'failed', 'mode': mode, 'started_utc': datetime.now(timezone.utc).isoformat(), 'commands': []}

    def command(args, filename):
        print('+ ' + ' '.join(args), flush=True)
        with (reports / filename).open('w') as log:
            output = subprocess.run(args, cwd=root, stdout=log, stderr=subprocess.STDOUT, text=True)
        text = (reports / filename).read_text()
        report['commands'].append({'command': args, 'exit': output.returncode, 'report': filename})
        if output.returncode:
            print(text[-16000:], file=sys.stderr)
            raise ValueError('failed required suite: ' + ' '.join(args))
        return text

    try:
        cases = case_contract.load_cases(root)
        if mode == 'unit':
            app = json.loads((root / 'build/test-results/unit/summary.json').read_text())
            if app['status'] != 'passed':
                raise ValueError('application unit suite did not pass')
            output = command(['prove', '-v', 'scripts/test-unit-workflow-run-state.pl',
                              'scripts/test-workflow-evidence.pl'], 'workflow-unit.tap')
            if re.search(r'#\s*(?:SKIP|TODO)\b', output, re.I):
                raise ValueError('required workflow unit test was skipped/TODO')
            for name in ('codex-code-implement', 'codex-review-loop', 'codex-change-write'):
                command(['perl', 'scripts/test-unit-' + name + '.pl'], name + '.txt')
            command(['perl', 'scripts/test-codex-session.pl'], 'codex-session.tap')
            names = re.findall(r'\bS[0-9]{3,}_T[0-9]{2,}_[\w]+', output)
            names += app['core']['tests'] + app['flutter']['tests']
            names += re.findall(r'^test_(\w+)', (root / 'build/test-results/unit/tooling.txt').read_text(), re.M)
            report.update(case_contract.require_executed(cases, names, 'unit'))
        elif mode == 'e2e':
            host_file = reports / 'host.json'
            host_file.unlink(missing_ok=True)
            command([sys.executable, 'tool/run_host_e2e.py'], 'host.txt')
            host = json.loads(host_file.read_text())
            if host['status'] != 'passed' or not host['count']:
                raise ValueError('empty or failed host E2E suite')
            command(['make', 'workflow-test'], 'workflow-regressions.txt')
            command([sys.executable, 'tool/run_tests.py', 'e2e'], 'android.txt')
            android = json.loads((root / 'build/test-results/e2e/summary.json').read_text())
            if android['status'] != 'passed':
                raise ValueError('Android E2E suite failed')
            executed = host['executed'][:]
            for suite in android['suites']:
                for path, count in suite['counts'].items():
                    if not count:
                        raise ValueError('empty Android suite: ' + path)
                    executed.extend({'file': path, 'name': name} for name in suite['tests'])
            report.update(case_contract.require_executed(cases, executed, 'e2e'))
            report['executed'] = executed
        else:
            raise ValueError('unknown mode: ' + mode)
        report['status'] = 'passed'
    finally:
        report['revision'] = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root,
            capture_output=True, text=True).stdout.strip()
        (reports / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('usage: run_change_tests.py unit|e2e')
        run(sys.argv[1], Path(__file__).resolve().parents[1])
    except (ValueError, OSError, KeyError) as error:
        print('change tests: ' + str(error), file=sys.stderr)
        sys.exit(1)
