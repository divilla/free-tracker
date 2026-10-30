"""System fixtures only; assertions enter production through external commands."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class SystemCase(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='free-tracker-e2e-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / 'repo with spaces'
        self.root.mkdir()
        self.env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1',
                    'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_SYSTEM': '/dev/null',
                    'GIT_TERMINAL_PROMPT': '0', 'ANDROID_DEVICE_ID': 'controlled-android'}

    def command(self, args, ok=True, cwd=None, env=None):
        result = subprocess.run([str(a) for a in args], cwd=cwd or self.root,
                                env=env or self.env, capture_output=True, text=True, timeout=90)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def copy_repository(self):
        files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=REPO).decode().split('\0')
        for name in files:
            if name and (REPO / name).is_file():
                dest = self.root / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(REPO / name, dest)

    def write(self, name, contents):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        return path

    def snapshot(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()
                and not set(p.relative_to(self.root).parts) & {'build', '__pycache__', '.git'}}

    def checker(self, ok=True, *args):
        before = self.snapshot()
        result = self.command([sys.executable, '-B', 'tool/check_scaffold.py', *args], ok)
        self.assertEqual(self.snapshot(), before, 'read-only CLI changed source')
        return result

    def mutate(self, path, transform, ok=False, diagnostic=None):
        file = self.root / path
        original = file.read_text()
        changed = transform(original)
        self.assertNotEqual(changed, original, 'fixture did not apply requested fault')
        file.write_text(changed)
        try:
            result = self.checker(ok)
            if diagnostic:
                self.assertIn(diagnostic, result.stderr)
        finally:
            file.write_text(original)

    def row(self, key, column, value, ok=False):
        def transform(text):
            lines = text.splitlines()
            matches = [i for i, line in enumerate(lines) if line.startswith('| ' + key + ' |')]
            self.assertEqual(len(matches), 1, key)
            i = matches[0]
            cells = [c.strip() for c in lines[i].strip('|').split('|')]
            cells[column] = value
            lines[i] = '| ' + ' | '.join(cells) + ' |'
            return '\n'.join(lines) + '\n'
        self.mutate('agent/setup-decisions.md', transform, ok)


class ScaffoldSystemCase(SystemCase):
    def setUp(self):
        super().setUp()
        self.copy_repository()

    def valid(self):
        self.assertIn('scaffold contract valid', self.checker().stdout)

    def runner_tools(self):
        """Controlled SDK boundary, not substituted evidence of app behavior."""
        binary = self.root / 'fake-sdk'
        binary.mkdir()
        for name in ('python3', 'make', 'adb', 'git'):
            (binary / name).symlink_to(sys.executable if name == 'python3' else shutil.which(name))
        adapter = binary / 'adapter'
        adapter.write_text('#!' + sys.executable + '\n' + r'''
import json, os
from pathlib import Path
import sys
args=sys.argv[1:]
mode=os.environ.get('SDK_FAULT','')
if mode == 'fail': sys.exit(9)
if 'devices' in args:
    print(json.dumps([] if mode=='absent-device' else [{'id':'controlled-android','targetPlatform':'linux-x64' if mode=='wrong-device' else 'android-x64'}]))
elif 'test' in args:
    paths=args[args.index('--reporter=json')+1:] if '--reporter=json' in args else [args[-1]]
    if '--coverage' in args:
        paths=['test/settings/domain','test/settings/application','test/settings/data','test/settings/presentation','test/app']
        Path('coverage').mkdir(exist_ok=True)
        sources=sorted(Path('lib').rglob('*.dart'))
        text=''.join('SF:'+str(p)+'\nDA:1,'+('0' if mode=='uncovered' else '1')+'\n'+('BRDA:1,0,0,1\nBRDA:1,0,1,0\n' if mode=='branches' else '')+'end_of_record\n' for p in sources)
        Path('coverage/lcov.info').write_text('garbage' if mode=='bad-coverage' else text)
    if mode=='empty': sys.exit(0)
    for i,path in enumerate(paths):
        print(json.dumps({'type':'suite','suite':{'id':i,'path':path}}))
        names=['S001_E%02d_case'%n for n in range(1,11)] if path.endswith('app_info_test.dart') else ['S001_P01_case'] if path.endswith('app_info_platform_test.dart') else ['controlled boundary case']
        for j,name in enumerate(names):
            ident=i*100+j
            print(json.dumps({'type':'testStart','test':{'id':ident,'suiteID':i,'name':name}}))
            print(json.dumps({'type':'testDone','testID':ident,'hidden':False,'skipped':mode=='skip','result':'success'}))
    print(json.dumps({'type':'done','success':True}))
''')
        adapter.chmod(0o755)
        for name in ('dart', 'flutter'):
            (binary / name).symlink_to(adapter)
        tests = self.root / 'tool/tests'
        filenames = [p.name for p in tests.glob('*.py')]
        shutil.rmtree(tests)
        tests.mkdir()
        for name in filenames:
            (tests / name).write_text('# Controlled runner-boundary fixture; not application evidence.\n')
        (tests / 'test_boundary.py').write_text('import unittest\nclass Boundary(unittest.TestCase):\n def test_boundary(self): self.assertEqual(2+2,4)\n')
        self.env['PATH'] = str(binary)
        return binary

    def runner(self, mode='unit', fault='', ok=True):
        return self.command([sys.executable, '-B', 'tool/run_tests.py', mode], ok,
                            env={**self.env, 'SDK_FAULT': fault})
