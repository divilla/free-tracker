import contextlib
import io
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
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
        # Genuine source-linked fixtures: no empty substitutes for S002 inputs.
        paths = {'android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml',
                 'pubspec.yaml', 'agent/reference-scaffold.md', 'agent/setup-decisions.md'}
        for guide in ('agent/reference-scaffold.md', 'agent/setup-decisions.md'):
            for link in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', (REPO / guide).read_text()):
                if '://' not in link:
                    paths.add((Path('agent') / link).as_posix())
        for path in paths:
            dest = self.root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            if (REPO / path).is_dir():
                shutil.copytree(REPO / path, dest, dirs_exist_ok=True,
                                ignore=shutil.ignore_patterns('__pycache__'))
            else:
                shutil.copy(REPO / path, dest)
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

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()}

    def setup_row(self, key):
        text = (self.root / 'agent/setup-decisions.md').read_text()
        rows = [line for line in text.splitlines() if line.startswith('| ' + key + ' |')]
        self.assertEqual(len(rows), 1, key)
        return rows[0]

    def change_row(self, key, column, value):
        row = self.setup_row(key)
        cells = [cell.strip() for cell in row.strip('|').split('|')]
        cells[column] = value
        return row, '| ' + ' | '.join(cells) + ' |'

    def reject(self, old, new, diagnostic, path='agent/setup-decisions.md'):
        file = self.root / path
        original = file.read_text()
        self.assertIn(old, original)
        file.write_text(original.replace(old, new, 1))
        try:
            before = self.snapshot()
            with self.assertRaisesRegex(ValueError, diagnostic):
                check_scaffold.setup(self.root)
            self.assertEqual(self.snapshot(), before, 'failed check mutated fixture')
        finally:
            file.write_text(original)

    def reject_cell(self, key, column, value, diagnostic=None):
        self.reject(*self.change_row(key, column, value), diagnostic or re.escape(key))

    def test_S002_T01_identity_and_constraints_match(self):
        before = self.snapshot()
        check_scaffold.setup(self.root)
        check_scaffold.check(self.root)
        self.assertEqual(before, self.snapshot())

    def test_S002_T02_identity_mismatch_rejected(self):
        for key, values in [('Application ID', ('', 'com.example.app', 'com.other.tracker')),
                            ('Public name', ('', 'Sample'))]:
            for value in values:
                with self.subTest(key=key, value=value):
                    self.reject_cell(key, 1, value)
        for path, old, new in (
            ('android/app/build.gradle.kts', 'com.bindefined.freetracker', 'com.example.app'),
            ('android/app/src/main/AndroidManifest.xml', 'free-tracker', 'Other'),
            ('lib/app/composition.dart', 'com.bindefined.freetracker', 'com.example.app')):
            with self.subTest(path=path):
                self.reject(old, new, re.escape(path), path)

    def test_S002_T03_settled_constraints_preserved(self):
        for key in check_scaffold.CONSTRAINTS:
            for value in ('', 'contradiction: paid maps; manual tour-distance input; duration cap 1h'):
                with self.subTest(key=key, value=value):
                    self.reject_cell(key, 1, value)

    def test_S002_T04_stack_and_architecture_handoff(self):
        check_scaffold.setup(self.root)
        self.assertIn('| Minimum API | 24 |', self.setup_row('Minimum API'))
        self.assertIn('API 37', self.setup_row('Emulator'))
        self.assertIn('21.0.12.1.1', self.setup_row('Host Java'))
        self.assertIn('| 17 |', self.setup_row('Kotlin JVM target'))

    def test_S002_T05_stack_drift_rejected(self):
        for key in check_scaffold.STACK:
            for value in ('', 'different stack/presentation'):
                with self.subTest(key=key, value=value):
                    self.reject_cell(key, 1, value)
        self.reject_cell('Minimum API', 1, '37')
        config_variants = (
            ('.flutter-version', '3.47.9', '3.48.0'),
            ('pubspec.yaml', '3.13.7', '3.14.0'),
            ('pubspec.yaml', '3.47.9', '3.48.0'),
            ('pubspec.yaml', 'package_info_plus: 10.2.2', 'package_info_plus: 10.2.3'),
            ('pubspec.lock', 'version: "10.2.2"', 'version: "10.2.3"'),
            ('android/app/build.gradle.kts', 'minSdk = 24', 'minSdk = 37'),
            ('android/app/build.gradle.kts', 'minSdk = 24', '// minSdk = 24\n        minSdk = 37'),
            ('android/app/build.gradle.kts', 'compileSdk = 36', 'compileSdk = 37'),
            ('android/app/build.gradle.kts', 'targetSdk = 36', 'targetSdk = 35'),
            ('android/app/build.gradle.kts', 'sourceCompatibility = JavaVersion.VERSION_17', 'sourceCompatibility = JavaVersion.VERSION_21'),
            ('android/app/build.gradle.kts', 'targetCompatibility = JavaVersion.VERSION_17', 'targetCompatibility = JavaVersion.VERSION_21'),
            ('android/app/build.gradle.kts', 'JvmTarget.JVM_17', 'JvmTarget.JVM_21'),
            ('android/app/build.gradle.kts', '35.0.0', '36.0.0'),
            ('android/app/build.gradle.kts', '28.2.13676358', '29.0.0'),
            ('android/settings.gradle.kts', '8.13.2', '8.14.0'),
            ('android/settings.gradle.kts', '2.2.20', '2.3.0'),
            ('android/gradle/wrapper/gradle-wrapper.properties', '8.14', '8.13'),
            ('lib/settings/application/app_info_loader.dart', 'StreamController<AppInfoState>.broadcast()', 'StreamController<AppInfoState>()'),
            ('lib/settings/presentation/app_info_screen.dart', 'StreamBuilder<AppInfoState>', 'FutureBuilder<AppInfoState>'),
        )
        for path, old, new in config_variants:
            with self.subTest(path=path, old=old):
                self.reject(old, new, re.escape(path), path)
        lock = self.root / 'pubspec.lock'
        lock.unlink()
        with self.assertRaisesRegex(OSError, 'pubspec.lock'):
            check_scaffold.setup(self.root)

    def test_S002_T05_R08_commented_baseline_is_not_active_configuration(self):
        path = 'android/app/build.gradle.kts'
        for field, baseline, changed in (
            ('minSdk', '24', '37'), ('compileSdk', '36', '37'),
            ('targetSdk', '36', '37'), ('buildToolsVersion', '"35.0.0"', '"36.0.0"'),
            ('ndkVersion', '"28.2.13676358"', '"29.0.0"'),
            ('sourceCompatibility', 'JavaVersion.VERSION_17', 'JavaVersion.VERSION_21'),
            ('targetCompatibility', 'JavaVersion.VERSION_17', 'JavaVersion.VERSION_21'),
            ('jvmTarget', 'org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17',
             'org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21'),
            ('namespace', '"com.bindefined.freetracker"', '"com.example.app"'),
            ('applicationId', '"com.bindefined.freetracker"', '"com.example.app"'),
        ):
            assignment = field + ' = ' + baseline
            indent = '    ' if field in ('compileSdk', 'buildToolsVersion', 'ndkVersion', 'namespace') else '        '
            for comment in ('/*\n' + indent + assignment + '\n*/',
                            '/* outer /* nested */\n' + indent + assignment + '\n*/',
                            '// ' + assignment):
                for active in ('', '\n' + indent + field + ' = ' + changed):
                    with self.subTest(field=field, comment=comment, active=active):
                        self.reject(assignment, comment + active, re.escape(path) + '.*' + field, path)

    def test_S002_T05_R08_conflicting_active_assignments_rejected(self):
        path = 'android/app/build.gradle.kts'
        for field, baseline, changed in (('minSdk', '24', '37'), ('compileSdk', '36', '37'),
                                         ('targetSdk', '36', '35')):
            assignment = field + ' = ' + baseline
            for other in (field + ' = ' + changed, field + '=37',
                          'android.defaultConfig.' + field + ' = 37', assignment):
                for replacement in (assignment + '\n        ' + other,
                                    other + '\n        ' + assignment,
                                    assignment + '; ' + other):
                    with self.subTest(field=field, replacement=replacement):
                        self.reject(assignment, replacement, re.escape(path) + '.*' + field, path)

    def test_S002_T05_R08_gradle_setter_overrides_rejected(self):
        path = 'android/app/build.gradle.kts'
        for field, baseline, calls in (
            ('minSdk', '24', ('minSdkVersion(37)', 'minSdkVersion("37")', 'minSdkVersion(24)', 'minSdk(37)',
                              'setMinSdkVersion(37)', 'setMinSdk(37)')),
            ('compileSdk', '36', ('compileSdkVersion(37)', 'compileSdk(37)', 'setCompileSdkVersion(37)')),
            ('targetSdk', '36', ('targetSdkVersion(37)', 'targetSdk(37)', 'setTargetSdkVersion(37)')),
            ('buildToolsVersion', '"35.0.0"', ('buildToolsVersion("36.0.0")', 'setBuildToolsVersion("36.0.0")')),
            ('ndkVersion', '"28.2.13676358"', ('ndkVersion("29.0.0")', 'setNdkVersion("29.0.0")')),
            ('sourceCompatibility', 'JavaVersion.VERSION_17', ('setSourceCompatibility(JavaVersion.VERSION_21)',)),
            ('targetCompatibility', 'JavaVersion.VERSION_17', ('setTargetCompatibility(JavaVersion.VERSION_21)',)),
            ('jvmTarget', 'org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17',
             ('jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)',)),
            ('namespace', '"com.bindefined.freetracker"', ('setNamespace("com.example.app")',)),
            ('applicationId', '"com.bindefined.freetracker"', ('setApplicationId("com.example.app")',)),
        ):
            assignment = field + ' = ' + baseline
            for call in calls:
                for replacement in (assignment + '\n        ' + call,
                                    call + '\n        ' + assignment,
                                    assignment + '; android.defaultConfig.' + call,
                                    assignment + '\n        ' + call.replace('(', ' /* setter */ (\n', 1)):
                    with self.subTest(field=field, replacement=replacement):
                        self.reject(assignment, replacement, re.escape(path) + '.*' + field + '.*setter', path)

    def test_S002_T05_R08_jvm_target_property_value_overrides_rejected(self):
        file = self.root / 'android/app/build.gradle.kts'
        original = file.read_text()
        assignment = 'jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17'
        for call in (
            'jvmTarget.value(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)',
            'compilerOptions.jvmTarget.value(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)',
            'jvmTarget /* property */ . value /* override */ (\norg.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)',
        ):
            for replacement in (assignment + '\n        ' + call,
                                call + '\n        ' + assignment, assignment + '; ' + call):
                with self.subTest(replacement=replacement):
                    file.write_text(original.replace(assignment, replacement, 1))
                    before = self.snapshot()
                    with self.assertRaisesRegex(ValueError, r'android/app/build\.gradle\.kts.*jvmTarget.*setter'):
                        check_scaffold.check(self.root)
                    self.assertEqual(self.snapshot(), before, 'failed check mutated fixture')

    def test_S002_T05_R08_setter_examples_in_comments_and_literals_ignored(self):
        file = self.root / 'android/app/build.gradle.kts'
        file.write_text(file.read_text() + '\n' + '\n'.join((
            '// minSdkVersion(37)', '/* compileSdkVersion(37) /* targetSdkVersion(37) */ */',
            'val example = "minSdkVersion(37); setMinSdk(37)"',
            'val escaped = "quoted \\" targetSdkVersion(37)"',
            'val raw = """\ncompileSdkVersion(37)\njvmTarget.set(JvmTarget.JVM_21)\n"""',
            '// jvmTarget.value(JvmTarget.JVM_21)', '/* jvmTarget.value(JvmTarget.JVM_21) */',
            'val valueExample = "jvmTarget.value(JvmTarget.JVM_21)"',
            'val rawValue = """\njvmTarget.value(JvmTarget.JVM_21)\n"""',
        )) + '\n')
        before = self.snapshot()
        check_scaffold.setup(self.root)
        self.assertEqual(self.snapshot(), before)

    def test_S002_T05_R08_comments_do_not_change_active_configuration(self):
        file = self.root / 'android/app/build.gradle.kts'
        original = file.read_text()
        file.write_text(original.replace('minSdk = 24',
            'minSdk /* old = 37; /* nested */ still comment */ = 24 // minSdk = 37') +
            '\n/*\n        minSdk = 37\n*/\n' +
            'val url = "https://example.invalid/ /* not a comment */"\n' +
            'val quote = "escaped \\" /* still a string */"\n' +
            'val raw = """// raw /* string */"""\n' +
            'val example = """\n        minSdk = 37\n"""\n' +
            "val slash = '/'\n")
        before = self.snapshot()
        check_scaffold.setup(self.root)
        self.assertEqual(self.snapshot(), before)

    def test_S002_T05_R08_string_literal_is_not_active_configuration(self):
        path = 'android/app/build.gradle.kts'
        for example in ('"minSdk = 24"', '"""\n        minSdk = 24\n"""'):
            with self.subTest(example=example):
                self.reject('minSdk = 24', 'val example = ' + example + '\n        minSdk = 37',
                            re.escape(path) + '.*minSdk', path)

    def test_S002_T05_R08_unterminated_gradle_comment_rejected(self):
        path = 'android/app/build.gradle.kts'
        self.reject('minSdk = 24', 'minSdk = 24 /* unfinished',
                    re.escape(path) + '.*comment', path)

    def test_S002_T06_build_and_execution_scope_separate(self):
        check_scaffold.setup(self.root)
        self.reject_cell('Executed ABIs', 1, 'armeabi-v7a; arm64-v8a; x86_64')
        self.reject_cell('Support', 1, 'all packaged phones supported')
        for state in ('available', 'partial'):
            with self.subTest(state=state):
                # A dated emulator observation must not become physical proof.
                file = self.root / 'agent/setup-decisions.md'
                original = file.read_text()
                row, modified = self.change_row('Physical phones', 1, state)
                modified = modified.replace('Unknown:', '2026-10-30; scope: emulator; limits: no phones;')
                self.reject(row, modified, 'Physical phones: emulator')
                self.assertEqual(file.read_text(), original)

    def test_S002_T07_partial_resources_are_honest(self):
        check_scaffold.setup(self.root)
        self.assertIn('partial', self.setup_row('Configured emulator'))
        self.assertIn('unknown', self.setup_row('Physical phones'))
        self.assertIn('S006; before', self.setup_row('Physical phones'))
        self.assertIn('S008; before', self.setup_row('Reference course/observed steps'))
        file = self.root / 'agent/setup-decisions.md'
        original = file.read_text()
        for key, state in [('Host/toolchain', 'available'), ('Reference course/observed steps', 'unavailable')]:
            row, changed = self.change_row(key, 1, state)
            file.write_text(original.replace(row, changed))
            check_scaffold.setup(self.root)
            file.write_text(original)
        # Structurally complete actual-phone observations are allowed. This is
        # explicitly a synthetic fixture, not evidence about a publisher device.
        row = self.setup_row('Physical phones')
        changed = row.replace('| unknown | Unknown:', '| partial | 2026-10-30; scope: observed physical phone: synthetic fixture; limits:')
        file.write_text(original.replace(row, changed))
        check_scaffold.setup(self.root)

    def test_S002_T08_incomplete_resource_inventory_rejected(self):
        for key in check_scaffold.RESOURCES:
            with self.subTest(key=key, variant='missing'):
                self.reject(self.setup_row(key), '', re.escape(key))
            for column in range(1, 5):
                with self.subTest(key=key, column=column):
                    self.reject_cell(key, column, '')
            for owner in ('S999; before acceptance', 'S006/S022/S008/S023/S005/S003/S020'):
                with self.subTest(key=key, owner=owner):
                    self.reject_cell(key, 3, owner)
        for key in ('Host/toolchain', 'Configured emulator'):
            for evidence in ('undated scope: host; limits: none', '2026-02-30; scope: host; limits: none',
                             '2026-10-30; ready', '2026-10-30; scope: ; limits:'):
                with self.subTest(key=key, evidence=evidence):
                    self.reject_cell(key, 2, evidence)
        self.reject_cell('Host/toolchain', 1, 'ready')
        self.reject_cell('Reference course/observed steps', 2, 'invented access')
        for token in ('model/vendor', 'Android/API', 'memory', 'ABI', 'Google services', 'step/location',
                      'older/low-memory', 'recent/multi-vendor', 'suitable/missing step', 'Google/non-Google'):
            row = self.setup_row('Physical phones')
            with self.subTest(token=token):
                self.reject(row, row.replace(token, 'omitted'), 'Physical phones inventory')

    def test_S002_T09_decision_ownership_preserved(self):
        check_scaffold.setup(self.root)
        for key, state in [('D01','resolved;'), ('D03','provisional;'), ('D05','partial;')]:
            self.assertIn(state, self.setup_row(key))
        self.assertIn('SQLite not selected', self.setup_row('D05'))

    def test_S002_T10_missing_duplicate_or_premature_decision_rejected(self):
        for i in range(1, 13):
            key = f'D{i:02}'
            row = self.setup_row(key)
            for replacement in ('', row + '\n' + row):
                with self.subTest(key=key, replacement=replacement):
                    self.reject(row, replacement, key)
            for owner in ('S999; before acceptance', 'S001/S002/S003/S004/S005/S006/S007/S008/S009/S010/S011/S012/S013/S015/S020/S021/S023/S024/S025'):
                with self.subTest(key=key, owner=owner):
                    self.reject_cell(key, 3, owner)
        self.reject_cell('D05', 1, 'resolved; SQLite selected without evidence')
        self.reject_cell('D05', 1, 'partial; presentation established, binding chosen')
        for key in ('D04', 'D06', 'D07', 'D08', 'D09', 'D10', 'D11', 'D12'):
            with self.subTest(key=key):
                self.reject_cell(key, 1, 'resolved; all ready')

    def test_S002_T11_map_prerequisites_can_remain_unknown(self):
        check_scaffold.setup(self.root)
        self.assertIn('unknown', self.setup_row('Account/project suitability'))
        self.assertIn('zero-cost-only', self.setup_row('Alternatives'))

    def test_S002_T12_map_budget_and_evidence_constraints_required(self):
        # Includes no-map-ID, actual usage, authorization and degradation distinctions.
        for key in check_scaffold.MAP_POLICIES:
            row = self.setup_row(key) if key != 'Authorization' else None
            if row is None:
                document = (self.root / 'agent/setup-decisions.md').read_text()
                row = next(line for line in document.splitlines() if line.startswith('| Authorization |'))
            for new in ('', row.replace(row.split('|')[2], ' incomplete ')):
                with self.subTest(key=key, new=new):
                    self.reject(row, new, 'Maps.*' + re.escape(key))
        for key in ('Account/project suitability', 'Usage/configuration access', 'Signing-restriction evidence'):
            for column in range(1, 5):
                with self.subTest(key=key, column=column):
                    self.reject_cell(key, column, '')

    def test_S002_T13_release_inventory_without_secrets(self):
        check_scaffold.setup(self.root)
        for key in check_scaffold.RELEASE_ITEMS:
            self.assertIn('unknown', self.setup_row(key))
        self.assertIn('not Play app-signing', self.setup_row('Certificate distinction'))
        self.assertIn('no keys, passwords, tokens', self.setup_row('Custody procedure'))

    def test_S002_T14_incomplete_release_prerequisites_rejected(self):
        for key in check_scaffold.RELEASE_ITEMS:
            row = self.setup_row(key)
            with self.subTest(key=key, variant='missing'):
                self.reject(row, '', key)
            for column in range(1, 5):
                with self.subTest(key=key, column=column):
                    self.reject_cell(key, column, '')
        for key in ('Custody procedure', 'Certificate distinction', 'Artifact distinction'):
            row = self.setup_row(key)
            with self.subTest(key=key):
                self.reject(row, '', 'Release prerequisites.*' + key)
        self.reject_cell('Public/in-app privacy policy', 3, 'S025; before distribution')

    def test_S002_T15_source_verification_contract(self):
        check_scaffold.setup(self.root)
        # A scoped, observed primary-source record is structurally valid too;
        # this is synthetic fixture evidence, not an actual source verification.
        file = self.root / 'agent/setup-decisions.md'
        original = file.read_text()
        row = self.setup_row('Stack/support')
        observed = row.replace('| unverified |', '| verified |')
        cells = observed.split('|')
        cells[5] = ' Observed: fixture checked exact Flutter support scope; not live evidence '
        file.write_text(original.replace(row, '|'.join(cells)))
        check_scaffold.setup(self.root)
        file.write_text(original.replace('| unverified |', '| partial |'))
        check_scaffold.setup(self.root)

    def test_S002_T16_unsupported_verified_claim_rejected(self):
        file = self.root / 'agent/setup-decisions.md'
        original = file.read_text()
        for key in check_scaffold.SOURCE_TOPICS:
            row = self.setup_row(key)
            with self.subTest(key=key, variant='missing'):
                self.reject(row, '', re.escape(key))
            verified = row.replace('| unverified |', '| verified |')
            cells = verified.split('|')
            cells[5] = ' Observed: synthetic scoped primary-page observation '
            valid = '|'.join(cells)
            file.write_text(original.replace(row, valid))
            try:
                for column, value, diagnostic in (
                    (1, 'ready', 'State'), (2, '2026-02-30; scope: test', 'date'),
                    (2, '2026-10-30; scope:', 'scope'), (2, '2026-10-30; no scoped assertion', 'scope'),
                    (3, '[source](http://example.org)', 'HTTPS'), (3, 'not a URL', 'HTTPS'),
                    (4, 'Unverified: never checked; next: inspect', 'observation'), (4, 'Observed:', 'observation'),
                    (5, 'S999; before gate', 'owner'), (5, 'S005/S006/S015/S020/S024/S025', 'gate')):
                    with self.subTest(key=key, column=column, value=value):
                        self.reject_cell(key, column, value, re.escape(key) + '.*' + diagnostic)
            finally:
                file.write_text(original)

    def test_S002_T17_unavailable_source_stays_unverified(self):
        check_scaffold.setup(self.root)
        for key in check_scaffold.SOURCE_TOPICS:
            with self.subTest(key=key):
                self.reject_cell(key, 1, 'verified', re.escape(key) + '.*observation')
                self.reject_cell(key, 4, 'Claim ready without reading page', re.escape(key) + '.*unanswered')

    def test_S002_T18_record_structure_and_links_fail_closed(self):
        file = self.root / 'agent/setup-decisions.md'
        original = file.read_text()
        # Section order is editorial, not part of the change's contract.
        sections = re.split(r'(?=^## )', original, flags=re.M)
        file.write_text(sections[0] + ''.join(reversed(sections[1:])))
        check_scaffold.setup(self.root)
        file.write_text(original)
        self.reject('| --- | --- |', '| malformed | --- |', 'separator')
        self.reject('| Public name | free-tracker |', '| Public name | free-tracker | unexpected |', 'required fields')
        self.reject('[SDK pin](../.flutter-version)', 'SDK pin without required link', 'required local source links')
        for section in check_scaffold.SETUP_SECTIONS:
            heading = '## ' + section
            for new in ('', heading + '\n' + heading):
                with self.subTest(section=section, new=new):
                    self.reject(heading, new, 'sections')
        # Independently remove every required cell, across all eight sections.
        for line in original.splitlines():
            if not line.startswith('| ') or line.startswith('| ---'):
                continue
            with self.subTest(row=line, variant='duplicate'):
                self.reject(line, line + '\n' + line, 'agent/setup-decisions.md')
            cells = line.split('|')
            for column in range(1, len(cells) - 1):
                changed = cells.copy(); changed[column] = ' '
                with self.subTest(row=cells[1], column=column):
                    self.reject(line, '|'.join(changed), 'agent/setup-decisions.md')
        for link in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', original):
            if '://' not in link:
                with self.subTest(link=link):
                    self.reject('](' + link + ')', '](absent-required-file)', 'broken required local link')
        file.unlink()
        with self.assertRaisesRegex(OSError, 'setup-decisions.md'):
            check_scaffold.setup(self.root)
        file.write_text(original)
        read = Path.read_text
        def unreadable(path, *args, **kwargs):
            if path == file:
                raise PermissionError('agent/setup-decisions.md unreadable')
            return read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', unreadable), self.assertRaisesRegex(OSError, 'unreadable'):
            check_scaffold.setup(self.root)
        # Optional raw logs are neither prerequisites nor manufactured fresh results.
        self.assertFalse((self.root / 'build').exists())
        check_scaffold.setup(self.root)

    def test_S002_T19_historical_and_current_evidence_separate(self):
        self.reject_cell('S001 baseline', 1, 'executed in S002', 'S001 baseline')
        self.reject_cell('Review/merge', 1, 'executed in S002', 'Review/merge')
        for key in check_scaffold.CHECK_ITEMS:
            with self.subTest(key=key):
                self.reject_cell(key, 5, 'unknown revision, no scope', re.escape(key) + '.*revision/scope')
        for key in ('Android E2E', 'Real SQLite', 'Review/merge'):
            with self.subTest(key=key):
                self.reject_cell(key, 3, 'passed', re.escape(key) + '.*unjustified pass')
        # A pending check cannot carry an old pass, nor can execution lack an exit.
        file = self.root / 'agent/setup-decisions.md'
        row = self.setup_row('Setup contract')
        cells = row.split('|'); cells[2] = ' not run '; cells[4] = ' passed '
        self.reject(row, '|'.join(cells), 'Setup contract.*unjustified pass')

    def test_S002_T20_setup_check_integrated_and_read_only(self):
        before = self.snapshot()
        command = [sys.executable, '-B', str(self.root / 'tool/check_scaffold.py')]
        result = subprocess.run(command, cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('scaffold contract valid', result.stdout)
        self.assertEqual(before, self.snapshot())
        file = self.root / 'agent/setup-decisions.md'
        file.write_text(file.read_text().replace('## Maps', '## Missing maps'))
        before = self.snapshot()
        result = subprocess.run(command, cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('agent/setup-decisions.md: sections', result.stderr)
        self.assertEqual(before, self.snapshot())
        # The existing unit runner must actually call setup through check().
        import run_tests
        from test_test_workflow import machine
        def invoke(args, **kwargs):
            output = ('\nRan 29 tests\n\nOK\n' if 'unittest' in args else
                      machine(run_tests.CORE_PATHS if args[0] == 'dart' else run_tests.UNIT_PATHS))
            return subprocess.CompletedProcess(args, 0, output, '')
        runner = run_tests.Runner(self.root, invoke, lambda _: '/tool')
        with patch.object(run_tests.check_coverage, 'check', return_value={}), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, 'setup-decisions.md: sections'):
                runner.run('unit')
        # Stable Make entry point remains wired to that runner. Existing S001
        # failure-injection cases additionally prove Make propagates failures.
        result = subprocess.run(['make', '--no-print-directory', '-n', 'unit-test'],
                                cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('python3 tool/run_tests.py unit', result.stdout)


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
