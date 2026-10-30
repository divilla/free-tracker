#!/usr/bin/env python3
"""Fail closed on missing sources, invalid LCOV or any uncovered lib line."""
from pathlib import Path
import re
import sys

# flutter gen-l10n owns exactly these files. No wildcard generated exclusion.
GENERATED = {'lib/l10n/generated/app_localizations.dart',
             'lib/l10n/generated/app_localizations_en.dart'}


def check(root, report):
    root = root.resolve()
    records = {}
    current = None
    branches = []
    for line in report.read_text().splitlines():
        if line.startswith('SF:'):
            if current is not None:
                raise ValueError('unterminated source record')
            path = Path(line[3:])
            path = path if path.is_absolute() else root / path
            name = path.resolve().relative_to(root).as_posix()
            if name in records:
                raise ValueError('duplicate source record: ' + name)
            current = {'lines': {}, 'ended': False, 'summaries': {}}
            records[name] = current
        elif line.startswith('DA:'):
            if current is None:
                raise ValueError('line outside source record')
            parts = line[3:].split(',')
            if len(parts) not in (2, 3):
                raise ValueError('invalid line record')
            number, hits = int(parts[0]), int(parts[1])
            if number <= 0 or hits < 0 or number in current['lines']:
                raise ValueError('invalid line record')
            current['lines'][number] = hits
        elif line.startswith('BRDA:'):
            if current is None:
                raise ValueError('branch outside source record')
            parts = line[5:].split(',')
            if len(parts) != 4:
                raise ValueError('invalid branch record')
            hits = 0 if parts[3] == '-' else int(parts[3])
            if hits < 0:
                raise ValueError('invalid branch hits')
            branches.append(hits)
        elif line.startswith(('LF:', 'LH:')):
            if current is None:
                raise ValueError('summary outside source record')
            field, value = line.split(':')
            current['summaries'][field] = int(value)
        elif line == 'end_of_record':
            if current is None:
                raise ValueError('unexpected end of record')
            expected = {'LF': len(current['lines']),
                        'LH': sum(h > 0 for h in current['lines'].values())}
            if any(expected[key] != value for key, value in current['summaries'].items()):
                raise ValueError('inconsistent line summary')
            current['ended'] = True
            current = None
        elif line and not line.startswith(('TN:', 'FN:', 'FNDA:', 'FNF:', 'FNH:', 'BRF:', 'BRH:')):
            raise ValueError('malformed coverage record: ' + line)
    if not records or any(not r['ended'] for r in records.values()):
        raise ValueError('empty or unterminated coverage')
    sources = {p.relative_to(root).as_posix() for p in (root / 'lib').rglob('*.dart')}
    declarations = set()
    port = 'lib/settings/application/app_info_repository.dart'
    if port in sources and re.fullmatch(
        r"\s*import '../domain/app_info.dart';\s*abstract interface class AppInfoRepository"
        r"\s*\{\s*Future<AppInfoResult> load\(\);\s*\}\s*",
        (root / port).read_text(),
    ):
        declarations.add(port)  # Exact pure declaration: no executable lines to measure.
    required = sources - GENERATED - declarations
    if not required or required - records.keys():
        raise ValueError('missing handwritten coverage: ' + str(sorted(required - records.keys())))
    total = hit = 0
    for name in sorted(required):
        lines = records[name]['lines']
        if not lines:
            raise ValueError('empty coverage source: ' + name)
        missed = [n for n, h in lines.items() if h == 0]
        if missed:
            raise ValueError('uncovered handwritten lines: ' + name + ':' + str(missed))
        total += len(lines)
        hit += sum(h > 0 for h in lines.values())
    if total == 0:
        raise ValueError('zero measured lines')
    branch = f'{sum(h > 0 for h in branches)}/{len(branches)}' if branches else 'unavailable (reporter supplies no branch records)'
    return {'sources': sorted(required), 'declarations': sorted(declarations), 'generated': sorted(sources & GENERATED),
            'line_hits': hit, 'line_total': total, 'line_percent': 100 * hit / total,
            'branches': branch}


if __name__ == '__main__':
    try:
        print(check(Path(__file__).resolve().parents[1], Path('coverage/lcov.info')))
    except (ValueError, OSError, IndexError) as error:
        print('coverage: ' + str(error), file=sys.stderr)
        sys.exit(1)
