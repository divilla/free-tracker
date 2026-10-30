import contextlib
import io
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_scaffold

REPO = Path(__file__).resolve().parents[2]


class ScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path in ['android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml', 'pubspec.yaml', 'agent/reference-scaffold.md']:
            dest = self.root / path; dest.parent.mkdir(parents=True, exist_ok=True); shutil.copy(REPO / path, dest)
        # Preserve guide destinations without copying tool caches/build outputs.
        import re
        for link in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', (self.root/'agent/reference-scaffold.md').read_text()):
            if '://' in link: continue
            target = (self.root / 'agent' / link).resolve()
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                if (REPO / 'agent' / link).is_dir(): target.mkdir(exist_ok=True)
                else: target.touch()
        shutil.copytree(REPO / 'lib', self.root / 'lib', dirs_exist_ok=True)

    def test_S001_T01_valid_android_identity_and_scope(self):
        check_scaffold.check(REPO); check_scaffold.check(self.root)
        for path, old, new in [('android/app/build.gradle.kts', 'com.bindefined.freetracker', 'com.example.app'),
                               ('android/app/src/main/AndroidManifest.xml', 'free-tracker', 'Sample'),
                               ('pubspec.yaml', 'package_info_plus: 10.2.2', 'google_mobile_ads: 1.0.0')]:
            file = self.root / path; original = file.read_text(); file.write_text(original.replace(old, new))
            with self.subTest(path=path), self.assertRaises(ValueError): check_scaffold.check(self.root)
            file.write_text(original)

    def test_S001_T02_missing_or_inconsistent_identity_stops_generation(self):
        for value in [None, '', 'com.example.app', 'com.bindefined.free_tracker']:
            with self.subTest(value=value), self.assertRaises(ValueError): check_scaffold.identity(value)
        check_scaffold.identity(check_scaffold.APPLICATION_ID)
        with patch.object(sys, 'argv', ['check_scaffold.py', '--pre-generation']), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(check_scaffold.main(), 1)
        self.assertFalse((self.root / 'generated-output').exists())

    def test_S001_T04_dependency_boundary_graph_valid(self):
        check_scaffold.boundaries(REPO)

    def test_S001_T29_reference_guide_links_and_handover(self):
        guide = self.root / 'agent/reference-scaffold.md'; original = guide.read_text()
        guide.write_text(original + '\n[missing](../absent-file.dart)\n')
        with self.assertRaisesRegex(ValueError, 'broken reference'): check_scaffold.check(self.root)
        guide.write_text(original.replace('S005', 'future'))
        with self.assertRaisesRegex(ValueError, 'handover'): check_scaffold.check(self.root)


def boundary_case(files):
    def test(self):
        pure = self.root/'lib/settings/domain/probe.dart'
        for name, text in files.items():
            path = self.root/'lib'/name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)
        with self.assertRaises(ValueError): check_scaffold.boundaries(self.root)
    return test

for name, files in {
    'direct': {'settings/domain/probe.dart': "import 'package:flutter/widgets.dart';"},
    'transitive': {'settings/domain/probe.dart': "export '../../bridge.dart';", 'bridge.dart': "export 'package:package_info_plus/package_info_plus.dart';"},
    'conditional': {'settings/domain/probe.dart': "import '../../bridge.dart' if (dart.library.ui) 'package:flutter/widgets.dart';", 'bridge.dart': ''},
    'outer': {'settings/domain/probe.dart': "import '../data/platform_app_info_repository.dart';"},
    'cycle': {'one/a.dart': "import '../two/b.dart';", 'two/b.dart': "import '../one/a.dart';"},
}.items():
    setattr(ScaffoldTests, 'test_S001_T04_dependency_boundary_graph_' + name, boundary_case(files))
