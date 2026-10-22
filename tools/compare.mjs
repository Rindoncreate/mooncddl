import { readFile, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { check } from '../_build/js/debug/build/bridge/bridge.js';
const fixture = JSON.parse(await readFile(new URL('../fixtures/reference.json', import.meta.url), 'utf8'));
const rows = fixture.cases.map(test => {
  const report = JSON.parse(check(test.schema, test.hex, 'cbor', ''));
  return { id: test.id, label: test.label, expected: test.expected, actualCode: report.code, agreement: report.code === (test.expected ? 0 : 1), report };
});
const mismatches = rows.filter(row => !row.agreement);
const summary = { oracle: fixture.oracle, total: rows.length, profileAssertionsPassed: rows.length - mismatches.length, independentOracleAgreements: fixture.cases.filter(row => row.expected === row.referenceActual).length, documentedOracleDeviations: fixture.referenceDeviations, mismatches };
await writeFile(new URL('../_build/differential-report.json', import.meta.url), JSON.stringify(summary, null, 2) + '\n');
console.log(JSON.stringify(summary, null, 2));
assert.equal(mismatches.length, 0, 'independent CDDL mismatches; inspect _build/differential-report.json');
