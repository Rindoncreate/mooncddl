"""Generate a single table-driven cross-backend test from independently recorded data."""
from pathlib import Path
import json
import sys
ROOT = Path(__file__).resolve().parents[1]
fixture = json.loads((ROOT / 'fixtures/reference.json').read_text(encoding='utf8'))
lines = ['// Generated from fixtures/reference.json. Do not edit expected values here.', '///|', 'test "recorded CDDL semantic partitions across backends" {', '  let cases : Array[(String, Bytes, Bool)] = [']
for case in fixture['cases']:
    literal = ''.join('\\x' + case['hex'][i:i+2] for i in range(0, len(case['hex']), 2))
    lines.append(f'    ({json.dumps(case["schema"])}, b"{literal}", {str(case["expected"]).lower()}),')
lines += ['  ]', '  for index, (source, bytes, expected) in cases {', '    let actual = @cbor.validate(@cddl.compile(source), bytes) is None', '    assert_eq(actual, expected, msg="semantic partition \\{index}")', '  }', '}', '']
destination = ROOT / 'cbor/reference_test.mbt'
destination.write_text('\n'.join(lines), encoding='utf8', newline='\n')
print(f'Generated one test table with {len(fixture["cases"])} semantic partitions')
