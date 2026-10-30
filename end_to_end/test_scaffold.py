"""S001 infrastructure cases exercise complete CLI/Make process boundaries."""
import json
import os
import shutil
import sys
from support import REPO, ScaffoldSystemCase, SystemCase


class InitialE2E(SystemCase):
    def test_S000_T01_e2e(self):
        result=self.command(['git','ls-tree','--name-only','HEAD','agent','scripts'],cwd=REPO)
        self.assertEqual(set(result.stdout.splitlines()),{'agent','scripts'})


class ScaffoldE2E(ScaffoldSystemCase):
    def test_S001_T01_e2e(self):
        self.valid()
        self.mutate('android/app/build.gradle.kts',lambda t:t.replace('com.bindefined.freetracker','com.example.app'))

    def test_S001_T02_e2e(self):
        for value in ('','com.example.app','com.other.app'):
            self.checker(False,'--pre-generation','--application-id',value)
        self.checker(False,'--pre-generation')
        self.checker(True,'--pre-generation','--application-id','com.bindefined.freetracker')

    def test_S001_T04_e2e(self):
        self.valid()
        for edge in ("import 'package:flutter/widgets.dart';\n", "export '../../data/platform_app_info_repository.dart';\n"):
            self.mutate('lib/settings/domain/app_info.dart',lambda t:edge+t)

    def test_S001_T20_e2e(self):
        self.runner_tools()
        self.runner()
        result=json.loads((self.root/'build/test-results/unit/summary.json').read_text())
        self.assertEqual(result['coverage']['line_percent'],100)
        self.assertEqual(len(result['flutter']['counts']),5)
        self.assertGreater(result['tooling_count'],0)

    def test_S001_T21_e2e(self):
        binary=self.runner_tools()
        for name in ('python3','dart','flutter','make'):
            tool=binary/name
            target=tool.readlink()
            tool.unlink()
            try: self.runner(ok=False)
            finally: tool.symlink_to(target)
        self.runner(fault='fail',ok=False)

    def test_S001_T22_e2e(self):
        self.runner_tools()
        self.runner()
        self.runner(fault='empty',ok=False)
        self.assertEqual((self.root/'build/test-results/unit/core.jsonl').read_text(),'')
        shutil.rmtree(self.root/'test/settings/domain')
        self.runner(ok=False)

    def test_S001_T23_e2e(self):
        self.runner_tools()
        for fault in ('bad-coverage','uncovered'):
            self.runner(fault=fault,ok=False)
            self.assertEqual(json.loads((self.root/'build/test-results/unit/summary.json').read_text())['status'],'failed')

    def test_S001_T24_e2e(self):
        self.runner_tools()
        self.write('lib/handwritten_generated.dart','// Hand-maintained generated-looking source.\nint answer() => 42;\n')
        self.runner()
        summary=json.loads((self.root/'build/test-results/unit/summary.json').read_text())
        self.assertIn('lib/handwritten_generated.dart',summary['coverage']['sources'])
        self.assertNotIn('lib/handwritten_generated.dart',summary['coverage']['generated'])

    def test_S001_T25_e2e(self):
        self.runner_tools()
        self.runner(fault='branches')
        summary=json.loads((self.root/'build/test-results/unit/summary.json').read_text())
        self.assertNotIn('unavailable',summary['coverage']['branches'])
        self.assertNotEqual(summary['coverage']['branches'].split('/')[0],summary['coverage']['branches'].split('/')[1])
        self.runner()
        self.assertIn('unavailable',json.loads((self.root/'build/test-results/unit/summary.json').read_text())['coverage']['branches'])

    def test_S001_T26_e2e(self):
        self.runner_tools()
        self.runner('e2e')
        report=json.loads((self.root/'build/test-results/e2e/summary.json').read_text())
        self.assertEqual(report['device'],'controlled-android')
        self.assertEqual(len(report['suites']),3)
        self.assertTrue(all(sum(s['counts'].values())>0 for s in report['suites']))

    def test_S001_T27_e2e(self):
        self.runner_tools()
        for fault in ('absent-device','wrong-device'):
            self.runner('e2e',fault=fault,ok=False)
        self.env.pop('ANDROID_DEVICE_ID')
        self.runner('e2e',ok=False)

    def test_S001_T28_e2e(self):
        self.runner_tools()
        self.runner('e2e')
        for fault in ('empty','skip','fail'):
            self.runner('e2e',fault=fault,ok=False)
        (self.root/'integration_test/app_info_test.dart').unlink()
        self.runner('e2e',ok=False)

    def test_S001_T29_e2e(self):
        self.valid()
        self.mutate('agent/reference-scaffold.md',lambda t:t+'\n[missing](../absent.dart)\n')
        self.mutate('agent/reference-scaffold.md',lambda t:t.replace('S005','future'))

    def test_S001_T30_e2e(self):
        self.mutate('pubspec.yaml',lambda t:t.replace('package_info_plus: 10.2.2','google_mobile_ads: 10.2.2'))
        self.mutate('android/app/src/main/AndroidManifest.xml',lambda t:t.replace('<application','<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/><application',1))

    def test_S001_T31_e2e(self):
        binary=self.root/'make-boundary'
        binary.mkdir()
        tool=binary/'python3'
        tool.write_text('#!/bin/sh\necho "$*" >> make-calls\nexit 7\n')
        tool.chmod(0o755)
        env={**self.env,'PATH':str(binary)+os.pathsep+os.environ['PATH']}
        for name in ('unit-test','end-to-end-test'):
            self.write(name,'cannot suppress phony recipe')
            self.command(['make',name],ok=False,env=env)
        self.assertEqual(len((self.root/'make-calls').read_text().splitlines()),2)
