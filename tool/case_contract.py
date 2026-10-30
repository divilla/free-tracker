"""Change rows are executable contracts, not test-directory presence checks."""
import json
from pathlib import Path
import re

CASE = re.compile(r'^S[0-9]{3,}-T[0-9]{2,}$')


def load_cases(root, active_only=True):
    scope = json.loads((root / 'tool/test_scope.json').read_text())
    if scope.get('schema') != 1 or not scope.get('implemented_changes'):
        raise ValueError('missing nonempty implemented test scope')
    active = scope['implemented_changes']
    if len(active) != len(set(active)):
        raise ValueError('duplicate implemented change in test scope')
    cases, seen, slugs = [], set(), set()
    for document in sorted((root / 'agent/changes').glob('*.md')):
        headers = None
        found = []
        for line in document.read_text().splitlines():
            if not line.startswith('|'):
                continue
            cells = [c.strip() for c in line.strip('|').split('|')]
            if cells[0] == 'Case ID':
                headers = cells
                continue
            if not CASE.fullmatch(cells[0]):
                continue
            case = cells[0]
            if not headers or len(cells) != len(headers) or 'E2E test (`file :: name`)' not in headers:
                raise ValueError(f'{document}: {case}: missing required E2E test column')
            if case in seen:
                raise ValueError('duplicate case ID: ' + case)
            seen.add(case)
            if not cells[2] or cells[2].startswith('<'):
                raise ValueError(case + ': specify fixture/action/observable assertions')
            mapping = cells[headers.index('E2E test (`file :: name`)')].strip('`')
            pieces = mapping.split(' :: ')
            if len(pieces) != 2:
                raise ValueError(case + ': E2E mapping must be file :: exact test name')
            path, name = pieces
            relative = Path(path)
            if relative.is_absolute() or '..' in relative.parts or not path.startswith(('end_to_end/', 'integration_test/')):
                raise ValueError(case + ': invalid E2E path')
            if case.replace('-', '_') not in name:
                raise ValueError(case + ': E2E test name must include case ID')
            if document.stem in active and not (root / relative).is_file():
                raise ValueError(case + ': missing E2E test file: ' + path)
            found.append({'id': case, 'slug': document.stem, 'file': path, 'name': name})
        if found:
            slugs.add(document.stem)
        if not active_only or document.stem in active:
            cases.extend(found)
    if set(active) - slugs:
        raise ValueError('implemented change has no case rows: ' + str(sorted(set(active) - slugs)))
    if not cases or len({c['name'] for c in cases}) != len(cases):
        raise ValueError('empty cases or shared E2E test names: add a distinct test per row')
    return cases


def require_executed(cases, executed, kind):
    if not executed:
        raise ValueError('empty executed ' + kind + ' suite')
    if kind == 'e2e':
        missing = [c['id'] for c in cases if not any(
            item['file'] == c['file'] and item['name'] == c['name'] for item in executed)]
    else:
        missing = [c['id'] for c in cases if not any(re.search(
            re.escape(c['id'].replace('-', '_')) + r'(?:_|\b)', name) for name in executed)]
    if missing:
        raise ValueError('missing executed ' + kind + ' tests for case rows: ' + ', '.join(missing))
    return {'case_count': len(cases), 'mapped_cases': [c['id'] for c in cases]}
