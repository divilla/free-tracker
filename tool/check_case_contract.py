#!/usr/bin/env python3
"""Read-only audit of requirement/unit and case/E2E mappings; does not run tests."""
import json
from pathlib import Path
import sys
import case_contract

try:
    root = Path(__file__).resolve().parents[1]
    contract = case_contract.load_contract(root, active_only=False)
    print(json.dumps({'requirement_count': len(contract['requirements']),
                      'case_count': len(contract['cases']), **contract}, indent=2))
except (ValueError, OSError, KeyError) as error:
    print('case contract: ' + str(error), file=sys.stderr)
    sys.exit(1)
