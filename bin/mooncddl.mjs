#!/usr/bin/env node
// Host adapter only: reads files and formats the MoonBit report. No schema rules.
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve, dirname } from 'node:path';
const args = process.argv.slice(2);
const usage = 'Usage: node bin/mooncddl.mjs check SCHEMA.cddl DATA [--input json|cbor] [--root RULE] [--json]';
function stop(message, code) { process.stderr.write(message + '\n'); process.exit(code); }
if (args.length === 1 && ['--help', '-h'].includes(args[0])) { console.log(usage); process.exit(0); }
if (args[0] !== 'check' || args.length < 3) stop(usage, 64);
let input = 'json', root = '', json = false;
const seen = new Set();
for (let i = 3; i < args.length; i++) {
  const flag = args[i];
  if (seen.has(flag)) stop('Duplicate option: ' + flag, 64);
  seen.add(flag);
  if (flag === '--json') json = true;
  else if (['--input', '--root'].includes(flag) && args[i + 1] && !args[i + 1].startsWith('--')) {
    const value = args[++i];
    if (flag === '--input') input = value; else root = value;
  } else stop('Unknown or incomplete option: ' + flag + '\n' + usage, 64);
}
if (!['json', 'cbor'].includes(input)) stop('--input must be json or cbor', 64);
const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
let engine;
try { engine = await import(pathToFileURL(resolve(project, '_build/js/debug/build/bridge/bridge.js')).href); }
catch { stop('Build the MoonBit engine first: moon build --target js', 64); }
try {
  for (const [file, limit] of [[args[1], 262144], [args[2], 1048576]]) {
    if ((await stat(file)).size > limit) stop('Input file exceeds byte limit: ' + file, 4);
  }
  const decode = new TextDecoder('utf-8', { fatal: true });
  const schema = decode.decode(await readFile(args[1]));
  const bytes = await readFile(args[2]);
  const data = input === 'cbor' ? bytes.toString('hex') : decode.decode(bytes);
  const report = JSON.parse(engine.check(schema, data, input, root));
  console.log(json ? JSON.stringify(report) : `${report.status}: ${report.path || '/'}: ${report.message}`);
  process.exitCode = report.code;
} catch (error) { stop('Input/host error: ' + error.message, 3); }
