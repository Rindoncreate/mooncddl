import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
const cwd = fileURLToPath(new URL('../', import.meta.url));
const moon = process.env.MOON ?? resolve(homedir(), '.moon/bin', process.platform === 'win32' ? 'moon.exe' : 'moon');
const python = process.env.PYTHON ?? (process.platform === 'win32' ? resolve(cwd, '.venv/Scripts/python.exe') : 'python3');
function run(command, args) {
  const result = spawnSync(command, args, {cwd, stdio: 'inherit', timeout: 60000});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed (${result.status})`);
}
run(moon, ['version', '--all']);
run(python, ['tools/reference.py', '--check']);
run(moon, ['fmt', '--check']);
const targets = ['js', 'wasm', 'wasm-gc'];
if (process.env.MOON_NATIVE === '1') targets.push('native');
for (const target of targets) {
  for (const command of ['check', 'build', 'test']) run(moon, [command, '--target', target, '--deny-warn']);
}
run(process.execPath, ['tools/compare.mjs']);
run(process.execPath, ['tools/scenarios.mjs']);
run(moon, ['package']);
console.log(`Verified targets: ${targets.join(', ')}. Runtime tests, reference partitions, CLI and package passed.`);
