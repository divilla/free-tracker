"""Enforce requirement-to-unit and case-to-E2E mappings against executed tests."""
import json
from pathlib import Path
import re

CASE = re.compile(r'^S[0-9]{3,}-T[0-9]{2,}$')
REQUIREMENT = re.compile(r'^S[0-9]{3,}-R[0-9]{2,}$')


def mapping(root, cell, identity, kind, implemented):
    match = re.fullmatch(r'`([^`]+) :: ([^`]+)`', cell)
    if not match:
        raise ValueError(f'{identity}: {kind} mapping must be file :: exact test name')
    path, name = match.groups()
    relative = Path(path)
    prefixes = ('test/', 'tool/tests/') if kind == 'unit' else ('end_to_end/', 'integration_test/')
    if relative.is_absolute() or '..' in relative.parts or not path.startswith(prefixes):
        raise ValueError(f'{identity}: invalid {kind} path')
    if not re.search(re.escape(identity.replace('-', '_')) + r'(?:_|\b)', name):
        raise ValueError(f'{identity}: {kind} test name must include case ID')
    if implemented and not (root / relative).is_file():
        raise ValueError(f'{identity}: missing {kind} test file: {path}')
    return {'file': path, 'name': name}


def load_contract(root, active_only=True):
    scope = json.loads((root / 'tool/test_scope.json').read_text())
    active = scope.get('implemented_changes')
    if scope.get('schema') != 1 or not isinstance(active, list) or not active:
        raise ValueError('missing nonempty implemented test scope')
    if any(not isinstance(slug, str) for slug in active) or len(active) != len(set(active)):
        raise ValueError('invalid or duplicate implemented change in test scope')
    cases, requirements, seen, slugs = [], [], set(), set()
    for document in sorted((root / 'agent/changes').glob('*.md')):
        prefix = 'S' + document.stem.split('-')[0]
        headers, found, required = None, [], []
        for line in document.read_text().splitlines():
            if not line.startswith('|'):
                headers = None
                continue
            cells = [c.strip() for c in line.strip('|').split('|')]
            identity = cells[0]
            if identity in ('Case ID', 'ID'):
                headers = cells
                continue
            if not (CASE.fullmatch(identity) or REQUIREMENT.fullmatch(identity)):
                continue
            if REQUIREMENT.fullmatch(identity) and (not headers or headers[0] != 'ID'):
                continue
            if identity in seen or not identity.startswith(prefix + '-'):
                raise ValueError('duplicate or mismatched ID: ' + identity)
            seen.add(identity)
            if REQUIREMENT.fullmatch(identity):
                required.append(identity)
                continue
            expected = ('Unit test (`file :: name`)', 'E2E test (`file :: name`)')
            if not headers or len(cells) != len(headers) or any(h not in headers for h in expected):
                raise ValueError(f'{document}: {identity}: missing required unit/E2E test column')
            if not cells[2] or cells[2].startswith('<'):
                raise ValueError(identity + ': specify fixture/action/observable assertions')
            refs = [r if r.startswith('S') else prefix + '-' + r
                    for r in re.findall(r'(?:S[0-9]{3,}-)?R[0-9]{2,}', cells[1])]
            if not refs:
                raise ValueError(identity + ': missing requirement mapping')
            unit = mapping(root, cells[headers.index(expected[0])], identity, 'unit', document.stem in active)
            e2e = mapping(root, cells[headers.index(expected[1])], identity, 'e2e', document.stem in active)
            found.append({'id': identity, 'slug': document.stem, 'requirements': refs, 'unit': unit, 'e2e': e2e})
        if not required or not found:
            raise ValueError(f'{document}: missing nonempty requirements/cases')
        for case in found:
            if set(case['requirements']) - set(required):
                raise ValueError(case['id'] + ': unknown requirement mapping')
        for requirement in required:
            units = [c['unit'] for c in found if requirement in c['requirements']]
            if not units:
                raise ValueError(requirement + ': missing unit-test mapping')
            if not active_only or document.stem in active:
                requirements.append({'id': requirement, 'slug': document.stem, 'unit_tests': units})
        slugs.add(document.stem)
        if not active_only or document.stem in active:
            cases.extend(found)
    if set(active) - slugs:
        raise ValueError('implemented change has no case rows: ' + str(sorted(set(active) - slugs)))
    names = [(c['e2e']['file'], c['e2e']['name']) for c in cases]
    if not cases or len(set(names)) != len(cases):
        raise ValueError('empty cases or shared E2E tests: add a distinct test per row')
    return {'requirements': requirements, 'cases': cases}


def require_executed(contract, executed, kind):
    if kind not in ('unit', 'e2e'):
        raise ValueError('unknown test kind: ' + kind)
    if not executed:
        raise ValueError('empty executed ' + kind + ' suite')
    pairs = {(item['file'], item['name']) for item in executed}
    def ran(test):
        return (test['file'], test['name']) in pairs
    if kind == 'unit':
        missing = [r['id'] for r in contract['requirements'] if not any(ran(t) for t in r['unit_tests'])]
        if missing:
            raise ValueError('missing executed unit tests for requirements: ' + ', '.join(missing))
    missing = [c['id'] for c in contract['cases'] if not ran(c[kind])]
    if missing:
        raise ValueError('missing executed ' + kind + ' tests for case rows: ' + ', '.join(missing))
    return {'requirement_count': len(contract['requirements']), 'case_count': len(contract['cases']),
            'mapped_requirements': [r['id'] for r in contract['requirements']],
            'mapped_cases': [c['id'] for c in contract['cases']]}
