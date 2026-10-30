#!/usr/bin/env python3
"""Validate S001 identity, boundaries and source-linked handover."""
import argparse
from pathlib import Path
import re
import sys

from check_coverage import GENERATED

APPLICATION_ID = 'com.bindefined.freetracker'


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
