#!/usr/bin/env python3
"""Validate S001 scaffold and S002 source-linked setup handover (read-only)."""
import argparse
from datetime import date
from pathlib import Path
import re
import sys

from check_coverage import GENERATED

APPLICATION_ID = 'com.bindefined.freetracker'

# Deliberately bounded S002 tables, not a general Markdown/schema framework.
SETUP_SECTIONS = ('Identity and constraints', 'Stack and architecture',
                  'Resources and support', 'Decisions', 'Maps',
                  'Release prerequisites', 'Source verification', 'Checks and handoff')
CONSTRAINTS = {
    'Public name': 'free-tracker', 'Application ID': APPLICATION_ID,
    'Platform': 'Flutter Android', 'Pricing': 'free; no ads',
    'Modes': 'Walk/Run × Outdoor/Indoor',
    'Indoor': 'calibrated steps; Route unavailable indoors; no fallback; no manual tour-distance input',
    'Automatic pause': 'initially off; optional; manual controls always available',
    'Units': 'km default; miles selectable; canonical metres',
    'Duration': 'no app-imposed duration cap',
    'Storage': 'private SQLite outside cache; local; no server or account',
    'Maps': 'zero-cost online maps; no paid fallback; no offline downloads',
    'Language': 'translation-ready English',
    'Delivery': 'APK; eventual public Play preparation; publication separate',
    'Excluded': 'accounts; cloud sync; social; route planning/navigation; wearables; calories; GPX; indoor positioning; treadmill integration',
}
STACK = {
    'Flutter': '3.47.9', 'Flutter revision': 'c197ca5199e9ee5661e865596c9c07294dfab51c',
    'Dart': '3.13.7', 'Host Java': '21.0.12.1.1', 'AGP': '8.13.2',
    'Gradle': '8.14', 'Kotlin': '2.2.20', 'Java source target': '17',
    'Java bytecode target': '17', 'Kotlin JVM target': '17',
    'Minimum API': '24', 'Compile API': '36', 'Target API': '36',
    'Build-tools': '35.0.0', 'NDK': '28.2.13676358', 'package_info_plus': '10.2.2',
    'Presentation': 'constructor injection; immutable plain-Dart state; broadcast stream; StreamBuilder; no extra state/DI framework',
    'Support': 'provisional; S005 extends; S006 validates; no final phone or Play support claim',
    'Packaged ABIs': 'armeabi-v7a; arm64-v8a; x86_64',
    'Executed ABIs': 'x86_64 only; emulator, not physical-phone proof',
    'Emulator': 'Free_Tracker_API_37; Android 17; API 37; emulator-5554 historically',
    'SQLite': 'not selected; S005 selects; S006/S009 validate',
    'Historical coverage': '103/103 handwritten Dart lines; 100% lines; branch coverage unavailable',
}
RESOURCE_HEADERS = ('Resource', 'State', 'Evidence and limits', 'Owner / blocking gate', 'Next action')
RESOURCES = ('Host/toolchain', 'Configured emulator', 'Physical phones',
             'Reference course/observed steps', 'Map-account access')
MAP_POLICIES = {
    'Budget': 'zero expenditure; no paid APIs, trial or automatic overage fallback',
    'Google recommendation': 'no-map-ID native SDK recommendation, not selected integration or verified pricing; billing-enabled account prerequisite is separate from no-charge usage',
    'Restrictions': 'attribution; restrict API key by API, package and signing certificate, including Play app-signing certificate',
    'Usage verification': 'S020 must verify actual configuration and SKU usage; alerts are not hard spending caps; disable unnecessary APIs; use applicable quotas',
    'Alternatives': 'S006/S020 evaluate zero-cost-only alternatives if unsuitable; terms, identification, bounded compliant caching, scale and non-Google behavior; no bulk prefetch; Google content SDK-managed',
    'Failure': 'disable chargeable service; preserve history/outline; outline is not the online-map release gate substitute; no compliant provider leaves gate unmet',
    'Authorization': 'separate authorization for account creation, payment setup, purchases, uploads and publication; none performed in S002',
}
RELEASE_POLICIES = {
    'Custody procedure': 'publisher chooses owner and approved secret store; secure custody, backup and upgrade identity continuity; no keys, passwords, tokens or payment details in repository',
    'Certificate distinction': 'upload certificate is not Play app-signing certificate; map restrictions must cover each installed APK and Play-delivered signing identity',
    'Artifact distinction': 'debug APK is not release evidence; separately test signed APK, AAB and Play-delivered install/upgrade/reopen',
    'Authorization': MAP_POLICIES['Authorization'],
}
RELEASE_ITEMS = ('Signing owner/custody/backup', 'Upgrade continuity', 'Upload/app-signing certificates',
                 'Play account/type/verification/cost/testing', 'Support contact', 'Public/in-app privacy policy',
                 'Data safety/health/foreground-service declarations', 'Target SDK/native ABI compatibility',
                 'APK/AAB/Play install/upgrade', 'Listing/free-no-ads/content rating/rollout/rollback')
SOURCE_TOPICS = ('Stack/support', 'Android service/permissions', 'Maps/terms/usage', 'Release/account obligations')
CHECK_ITEMS = ('S001 baseline', 'Remote baseline', 'Setup contract', 'Tooling units', 'Unit + coverage',
               'Android E2E', 'Real SQLite', 'Physical/field', 'Source/resource audit', 'Review/merge')


def _setup_require(condition, field):
    if not condition:
        raise ValueError('agent/setup-decisions.md: ' + field)


def _setup_rows(section, headers, keys, field):
    """Read exactly one named table; reject duplicate keys/blank cells/ragged rows."""
    rows = [tuple(cell.strip().strip('`') for cell in line.strip().strip('|').split('|'))
            for line in section.splitlines() if line.startswith('|')]
    _setup_require(rows and rows[0] == headers, field + ' headers')
    _setup_require(len(rows) >= 2 and all(re.fullmatch(r':?-+:?', c) for c in rows[1]), field + ' separator')
    entries = {}
    for row in rows[2:]:
        _setup_require(len(row) == len(headers) and all(row), field + ' required fields: ' + str(row))
        _setup_require(row[0] not in entries, field + ' duplicate ' + row[0])
        entries[row[0]] = row[1:]
    _setup_require(set(entries) == set(keys), field + ' entries: missing ' + str(sorted(set(keys) - set(entries))) +
                   ', unexpected ' + str(sorted(set(entries) - set(keys))))
    return entries


def _setup_values(section, expected, field):
    rows = _setup_rows(section, ('Field', 'Value'), expected, field)
    for key, value in expected.items():
        _setup_require(rows[key][0] == value, field + '/' + key + ': expected ' + value)


def _setup_date(value, field):
    match = re.match(r'(\d{4}-\d{2}-\d{2})(?:;|T| )', value)
    try:
        parsed = date.fromisoformat(match[1]) if match else None
    except ValueError:
        parsed = None
    _setup_require(parsed is not None, field + ' date (YYYY-MM-DD)')


def _setup_inventory(section, keys, field, owners):
    rows = _setup_rows(section, RESOURCE_HEADERS, keys, field)
    for key, (state, evidence, owner, action) in rows.items():
        name = field + '/' + key
        _setup_require(state in ('available', 'partial', 'unknown', 'unavailable'), name + ' State')
        _setup_require(all(token in owner for token in owners[key]), name + ' Owner / blocking gate')
        if state in ('available', 'partial'):
            _setup_date(evidence, name + ' Evidence and limits')
            _setup_require(re.search(r'scope:\s*\S.*;\s*limits:\s*\S', evidence), name + ' scoped evidence/limits')
        else:
            _setup_require(evidence.startswith('Unknown:') or evidence.startswith('Unavailable:'), name + ' absence/reason')
    return rows


_KOTLIN_LITERAL = r'"""[\s\S]*?"""|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''


def _gradle_without_comments(source, path):
    """Ignore Kotlin comments, including nested blocks, but preserve literals."""
    tokens = re.compile(r'//[^\n]*|/\*|' + _KOTLIN_LITERAL)
    parts, position = [], 0
    while match := tokens.search(source, position):
        parts.append(source[position:match.start()])
        token, end = match[0], match.end()
        if token == '/*':
            depth = 1
            for marker in re.finditer(r'/\*|\*/', source[end:]):
                depth += 1 if marker[0] == '/*' else -1
                if depth == 0:
                    end += marker.end()
                    break
            _setup_require(depth == 0, 'Stack/identity configuration ' + path + ': unterminated comment')
            token = source[match.start():end]
        if token.startswith(('//', '/*')):
            parts.append(re.sub(r'[^\n]', ' ', token))
        else:
            parts.append(token)
        position = end
    parts.append(source[position:])
    return ''.join(parts)


def setup(root):
    """S002 local consistency only: no probing, mutation or delivery-gate authority."""
    root = root.resolve()
    document = (root / 'agent/setup-decisions.md').read_text()
    headings = re.findall(r'^## (.+)$', document, re.M)
    _setup_require(len(headings) == len(SETUP_SECTIONS) and set(headings) == set(SETUP_SECTIONS),
                   'sections (each required section exactly once)')
    parts = re.split(r'^## .+$', document, flags=re.M)[1:]
    sections = dict(zip(headings, parts))
    _setup_values(sections['Identity and constraints'], CONSTRAINTS, 'Identity and constraints')
    _setup_values(sections['Stack and architecture'], STACK, 'Stack and architecture')

    # Compare carry-forward facts to real files, not just another copy of the record.
    local_patterns = {
        '.flutter-version': [r'^3\.47\.9\s*$'],
        'pubspec.yaml': [r"^  sdk: '>=3\.13\.7 <4\.0\.0'$", r"^  flutter: '>=3\.47\.9'$", r'^  package_info_plus: 10\.2\.2$'],
        'pubspec.lock': [r'  package_info_plus:\n(?:(?!  \w).*\n)*?    version: "10\.2\.2"'],
        'android/app/build.gradle.kts': {
            'compileSdk': '36', 'minSdk': '24', 'targetSdk': '36',
            'buildToolsVersion': '"35.0.0"', 'ndkVersion': '"28.2.13676358"',
            'sourceCompatibility': 'JavaVersion.VERSION_17', 'targetCompatibility': 'JavaVersion.VERSION_17',
            'jvmTarget': 'org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17',
            'namespace': '"com.bindefined.freetracker"', 'applicationId': '"com.bindefined.freetracker"'},
        'android/settings.gradle.kts': [r'^    id\("com\.android\.application"\) version "8\.13\.2" apply false$',
                                      r'^    id\("org\.jetbrains\.kotlin\.android"\) version "2\.2\.20" apply false$'],
        'android/gradle/wrapper/gradle-wrapper.properties': [r'^distributionUrl=https\\://services\.gradle\.org/distributions/gradle-8\.14-all\.zip$'],
        'android/app/src/main/AndroidManifest.xml': [r'android:label="free-tracker"'],
        'lib/app/composition.dart': [r"const applicationId = 'com.bindefined.freetracker';", r'repository \?\?'],
        'lib/settings/application/app_info_loader.dart': [r'final class AppInfoState', r'StreamController<AppInfoState>\.broadcast\(\)'],
        'lib/settings/presentation/app_info_screen.dart': [r'StreamBuilder<AppInfoState>'],
        'agent/s001-evidence.md': [re.escape(STACK['Flutter revision']), r'103 / 103', r'Branch coverage unavailable'],
    }
    for path, patterns in local_patterns.items():
        content = (root / path).read_text()
        if path.endswith('.gradle.kts'):
            content = _gradle_without_comments(content, path)
        if path == 'android/app/build.gradle.kts':
            for field, expected in patterns.items():
                # This bounded handoff requires assignments, not executable DSL
                # setters. SDK *Version aliases and Property.set/value can
                # override a correct-looking assignment; reject them regardless of order.
                names = [field]
                if field in ('compileSdk', 'minSdk', 'targetSdk'):
                    names.append(field + 'Version')
                names += ['set' + name[0].upper() + name[1:] for name in names]
                setter = r'\b(?:' + '|'.join(names) + '|' + field + r'\s*\.\s*(?:set|value))\s*\('
                calls = re.finditer(_KOTLIN_LITERAL + '|(' + setter + ')', content)
                _setup_require(not any(match[1] is not None for match in calls),
                    'Stack/identity configuration ' + path + ': ' + field +
                    ' setter calls are unsupported; use one assignment = ' + expected)
                # Literal alternatives consume strings before their contents can
                # masquerade as assignments (including multiline raw strings).
                matches = re.finditer(_KOTLIN_LITERAL + r'|\b' + field + r'\s*=(?!=)\s*([^\n;{}]+)', content)
                values = [match[1] for match in matches if match[1] is not None]
                _setup_require([value.strip() for value in values] == [expected],
                    'Stack/identity configuration ' + path + ': ' + field +
                    ' requires exactly one active assignment = ' + expected)
            continue
        for pattern in patterns:
            _setup_require(re.search(pattern, content, re.M), 'Stack/identity configuration ' + path + ': ' + pattern)

    resources = _setup_inventory(sections['Resources and support'], RESOURCES, 'Resources and support', {
        'Host/toolchain': ('S003', 'before'), 'Configured emulator': ('S005', 'before'),
        'Physical phones': ('S006', 'S022', 'before'),
        'Reference course/observed steps': ('S008', 'S023', 'before'), 'Map-account access': ('S020', 'before')})
    phones = resources['Physical phones']
    if phones[0] in ('available', 'partial'):
        _setup_require('observed physical phone:' in phones[1], 'Physical phones: emulator is not physical proof')
    for token in ('model/vendor', 'Android/API', 'memory', 'ABI', 'Google services', 'step/location',
                  'older/low-memory', 'recent/multi-vendor', 'suitable/missing step', 'Google/non-Google'):
        _setup_require(token in phones[1], 'Physical phones inventory: ' + token)

    decisions = _setup_rows(sections['Decisions'], ('ID', 'State / outcome', 'Evidence / absence',
                              'Owner / blocking point', 'Next action'), [f'D{i:02}' for i in range(1, 13)], 'Decisions')
    plan = (root / 'agent/PLAN.md').read_text()
    for key, (state, evidence, owner, action) in decisions.items():
        matches = re.findall(r'^\| ' + key + r' \| [^|]+ \| ([^|]+) \|', plan, re.M)
        _setup_require(len(matches) == 1 and owner == matches[0].strip(), 'Decisions/' + key + ' Owner / blocking point versus PLAN')
        expected = {'D01': 'resolved', 'D02': 'partial', 'D03': 'provisional', 'D05': 'partial'}.get(key, 'unresolved')
        _setup_require(state.startswith(expected + ';'), 'Decisions/' + key + ' State / outcome: ' + expected)
        if key == 'D05':
            _setup_require('SQLite not selected' in state, 'Decisions/D05 SQLite not selected')

    # The two inventory sections have a policy block followed by the resource table.
    for section, policies, keys, owners in (
        ('Maps', MAP_POLICIES, ('Account/project suitability', 'Usage/configuration access', 'Signing-restriction evidence'),
         {k: ('S020', 'before') for k in ('Account/project suitability', 'Usage/configuration access', 'Signing-restriction evidence')}),
        ('Release prerequisites', RELEASE_POLICIES, RELEASE_ITEMS,
         {k: (('S021', 'S025', 'before') if k in ('Public/in-app privacy policy', 'Data safety/health/foreground-service declarations')
              else ('S024', 'S025', 'before')) for k in RELEASE_ITEMS}),
    ):
        blocks = sections[section].split('\n### Inventory\n')
        _setup_require(len(blocks) == 2, section + ' Inventory')
        _setup_values(blocks[0], policies, section)
        _setup_inventory(blocks[1], keys, section, owners)

    sources = _setup_rows(sections['Source verification'], ('Topic', 'State', 'Checked date / scope',
                         'Primary source', 'Outcome / evidence', 'Recheck owner / gate'), SOURCE_TOPICS, 'Source verification')
    source_owners = ('S005/S006', 'S006/S015', 'S006/S020', 'S024/S025')
    for topic, expected_owner in zip(SOURCE_TOPICS, source_owners):
        state, scope, url, outcome, owner = sources[topic]
        name = 'Source verification/' + topic
        _setup_require(state in ('verified', 'partial', 'unverified'), name + ' State')
        _setup_date(scope, name)
        _setup_require('scope:' in scope and scope.split('scope:', 1)[1].strip(), name + ' scope')
        _setup_require(expected_owner in owner and 'before' in owner, name + ' Recheck owner / gate')
        if state == 'verified':
            _setup_require(re.search(r'\]\(https://[^\s)]+\)', url), name + ' Primary source HTTPS URL')
            _setup_require(outcome.startswith('Observed:') and len(outcome) > len('Observed:') + 10,
                           name + ' actual observation/outcome (not an unchecked claim)')
        else:
            _setup_require(outcome.startswith('Unverified:') and 'next:' in outcome, name + ' unanswered fact/reason and next action')

    checks = _setup_rows(sections['Checks and handoff'], ('Check', 'State', 'Command / procedure', 'Result',
                         'Observed UTC', 'Source / scope', 'Environment', 'Evidence'), CHECK_ITEMS, 'Checks and handoff')
    for key, (state, command, result, observed, scope, environment, evidence) in checks.items():
        name = 'Checks and handoff/' + key
        _setup_require(state in ('recorded historical', 'executed in S002', 'not run', 'N/A'), name + ' State')
        _setup_date(observed, name)
        _setup_require(re.search(r'revision [0-9a-f]{40}\b', scope) and 'scope:' in scope, name + ' revision/scope')
        if state == 'executed in S002':
            _setup_require(re.match(r'exit [0-9]+;', result), name + ' exit/result')
        if state in ('not run', 'N/A'):
            _setup_require(result.startswith('Not run:') if state == 'not run' else result.startswith('N/A:'), name + ' no unjustified pass')
    _setup_require(checks['S001 baseline'][0] == 'recorded historical', 'S001 baseline is historical, not a current S002 pass')
    _setup_require(checks['Review/merge'][0] == 'not run', 'Review/merge gates unverified; local checker cannot advance delivery')

    # Required portable links exclude optional S001 raw reports, which may vanish.
    links = re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', document)
    required = set(local_patterns) | {'agent/PRD.md', 'agent/ARCHITECTURE.md', 'agent/IMPLEMENT.md',
        'agent/PLAN.md', 'agent/reference-scaffold.md', 'agent/development-environment.md',
        'agent/changes/002-setup-decisions.md', 'pubspec.lock', 'Makefile', 'tool/check_scaffold.py',
        'tool/tests/test_scaffold_contract.py', 'tool/run_tests.py', 'lib/settings/domain/app_info.dart',
        'lib/settings/application/app_info_repository.dart', 'lib/settings/data/platform_app_info_repository.dart',
        'lib/l10n/app_en.arb'}
    local = set()
    for link in links:
        if '://' not in link:
            target = (root / 'agent' / link).resolve()
            _setup_require(target.is_file() and target.is_relative_to(root), 'broken required local link: ' + link)
            local.add(target.relative_to(root).as_posix())
    _setup_require(required <= local, 'required local source links: ' + str(sorted(required - local)))


def identity(value):
    if value != APPLICATION_ID:
        raise ValueError('publisher-confirmed application ID required: ' + APPLICATION_ID)


def boundaries(root):
    sources = {p.resolve(): p.read_text() for p in (root / 'lib').rglob('*.dart')}
    graph = {}
    for path, source in sources.items():
        edges = []
        directives = re.findall(r"^\s*(?:import|export|part)\s+([^;]+);", source, re.M)
        uris = [uri for directive in directives for uri in re.findall(r"['\"]([^'\"]+)['\"]", directive)]
        for uri in uris:
            target = None
            if uri.startswith('package:free_tracker/'):
                target = (root / 'lib' / uri.split('/', 1)[1]).resolve()
            elif not ':' in uri:
                target = (path.parent / uri).resolve()
            edges.append((uri, target))
            if 'presentation' in path.parts and target and 'data' in target.parts:
                raise ValueError('presentation bypasses feature port: ' + uri)
        graph[path] = edges
    def visit(path, stack, pure):
        if path in stack:
            cycle = stack[stack.index(path):]
            if not pure and all(p.relative_to(root).as_posix() in GENERATED for p in cycle):
                return  # gen-l10n's abstract catalog and locale subclass refer to each other.
            raise ValueError('dependency cycle: ' + str(path))
        for uri, target in graph.get(path, []):
            if pure and target is None and not uri.startswith('dart:'):
                raise ValueError('non-Dart dependency from pure core: ' + uri)
            if pure and target and any(x in target.parts for x in ('data', 'presentation', 'app')):
                raise ValueError('pure core imports outer layer: ' + str(target))
            if target:
                visit(target, stack + [path], pure)
    for path in sources:
        visit(path, [], any(x in path.relative_to(root.resolve()).parts for x in ('domain', 'application', 'measurement')))


def check(root):
    root = root.resolve()
    gradle = (root / 'android/app/build.gradle.kts').read_text()
    manifest = (root / 'android/app/src/main/AndroidManifest.xml').read_text()
    pub = (root / 'pubspec.yaml').read_text()
    composition = (root / 'lib/app/composition.dart').read_text()
    if f"const applicationId = '{APPLICATION_ID}';" not in composition:
        raise ValueError('composition identity differs from Android build')
    for field in ('namespace', 'applicationId'):
        if not re.search(field + r'\s*=\s*"' + re.escape(APPLICATION_ID) + '"', gradle):
            raise ValueError('inconsistent Android ' + field)
    if 'android:label="free-tracker"' not in manifest:
        raise ValueError('incorrect public app name')
    if not re.search(r'^version: 1\.0\.0\+1$', pub, re.M):
        raise ValueError('build metadata differs from pinned S001 configuration')
    # This slice requires no production permissions or service, nor ad/map/sensor SDK.
    if re.search(r'<(?:uses-permission|service)\b', manifest):
        raise ValueError('out-of-scope permission or service')
    allowed = {'flutter', 'flutter_localizations', 'intl', 'package_info_plus',
               'flutter_test', 'integration_test', 'test', 'flutter_lints'}
    blocks = re.findall(r'^(?:dependencies|dev_dependencies):\n((?:[ \t].*\n|\n)+)', pub, re.M)
    deps = re.findall(r'^  ([a-z][a-z0-9_]*):', ''.join(blocks), re.M)
    if set(deps) - allowed:
        raise ValueError('unapproved dependency: ' + str(set(deps) - allowed))
    boundaries(root)
    guide = (root / 'agent/reference-scaffold.md').read_text()
    for required in ('S002', 'S005', 'SQLite', 'D03', 'D05', 'evidence'):
        if required not in guide:
            raise ValueError('missing handover: ' + required)
    links = re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', guide)
    if not links:
        raise ValueError('empty reference guide')
    for link in links:
        if '://' not in link and not (root / 'agent' / link).exists():
            raise ValueError('broken reference: ' + link)
    for path in ('lib/main.dart', 'lib/app/composition.dart',
                 'lib/settings/domain/app_info.dart', 'lib/settings/application/app_info_loader.dart',
                 'lib/settings/application/app_info_repository.dart',
                 'lib/settings/data/platform_app_info_repository.dart',
                 'lib/settings/presentation/app_info_screen.dart', 'lib/l10n/app_en.arb',
                 'test/app/composition_test.dart', 'tool/run_tests.py', 'tool/check_coverage.py'):
        if '../' + path not in links:
            raise ValueError('missing reference link: ' + path)
    setup(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pre-generation', action='store_true')
    parser.add_argument('--application-id')
    args = parser.parse_args()
    try:
        if args.pre_generation:
            identity(args.application_id)
        else:
            check(Path(__file__).resolve().parents[1])
    except (ValueError, OSError) as error:
        print('scaffold: ' + str(error), file=sys.stderr)
        return 1
    print('scaffold contract valid')
    return 0


if __name__ == '__main__':
    sys.exit(main())
