import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
const cwd = fileURLToPath(new URL('../', import.meta.url));
const rows = [];
for (const scenario of ['service', 'device', 'protocol']) {
  for (const [name, expected] of [['valid', 0], ['invalid', 1]]) {
    const format = scenario === 'device' ? 'cbor' : 'json';
    const args = ['bin/mooncddl.mjs', 'check', `examples/${scenario}/schema.cddl`, `examples/${scenario}/${name}.${format}`, '--input', format, '--json'];
    const result = spawnSync(process.execPath, args, { cwd, encoding: 'utf8', timeout: 15000 });
    if (result.error) throw result.error;
    assert.equal(result.status, expected, result.stderr + result.stdout);
    const report = JSON.parse(result.stdout);
    assert.equal(report.code, expected);
    rows.push({scenario, input: name, code: result.status, path: report.path});
  }
}
for (const args of [[], ['check'], ['check', 'x', 'y', '--unknown'], ['check', 'x', 'y', '--input', 'yaml']]) {
  const result = spawnSync(process.execPath, ['bin/mooncddl.mjs', ...args], {cwd, encoding: 'utf8', timeout: 15000});
  assert.equal(result.status, 64, result.stderr + result.stdout);
}
const missing = spawnSync(process.execPath, ['bin/mooncddl.mjs', 'check', 'missing.cddl', 'missing.json'], {cwd, encoding: 'utf8', timeout: 15000});
assert.equal(missing.status, 3);
console.log(JSON.stringify(rows, null, 2));
