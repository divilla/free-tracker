#!/usr/bin/env python3
"""Read-only audit of executable change-case mappings (not a test execution)."""
import json
from pathlib import Path
import sys
import case_contract

try:
    root = Path(__file__).resolve().parents[1]
    cases = case_contract.load_cases(root, active_only=False)
    print(json.dumps({'case_count': len(cases), 'cases': cases}, indent=2))
except (ValueError, OSError, KeyError) as error:
    print('case contract: ' + str(error), file=sys.stderr)
    sys.exit(1)
