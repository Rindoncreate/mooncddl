# Verification record

Actual local environment: Windows, moon/moonrun 0.1.20261012, moonc v0.10.15+943464bfa, Node 24.19.0, Python 3.12.14. The installed MoonBit skills are pinned to 0.10.14; actual checks under 0.10.15 are used as evidence.

## Completed locally

- `moon fmt --check`.
- JS, Wasm and Wasm GC `check`, `build`, `test` with `--deny-warn`.
- 23 test blocks per backend. One block is a table of 134 semantic partitions; this is not 157 tests or a coverage percentage.
- 134 profile assertions passed in the Node bridge comparison; independent Rust reference agrees on 123, with eleven frozen, documented differences. Raw record: `_build/differential-report.json`.
- Six complete file-based CLI cases: valid/invalid JSON service message, valid/invalid CBOR device frame, valid/invalid protocol tuple. Valid cases return 0; invalid cases return 1 and paths `/readings/0/value`, `/1`, `/1` respectively.
- Missing files return 3; invalid CLI syntax/options return 64.
- Adversarial checks include source/data depth, work budget, duplicate escaped JSON keys, duplicate CBOR keys, huge CBOR lengths, signed integer limits, lossy JSON integer rounding, schema alias cycles and unused unsupported rules.
- `moon package` produced `_build/publish/Rindoncreate-mooncddl-0.1.0.zip`.

## Confirmed remote evidence

[CI run 39776757096](https://github.com/Rindoncreate/mooncddl/actions/runs/39776757096), source `9fce8e8835a551ea531f06502f049b8a6a5f937e`, completed successfully on 2026-10-22. The actual log confirms 23 test blocks passed on each of JS, Wasm, Wasm GC and Linux native; independent reference regeneration, CLI, package creation and `moon info` all passed. The JS-only Node bridge is excluded from native, while the compiler/validator/CBOR adapter are checked and tested there.

Remote compiler: moon/moonrun 0.1.20261021, moonc v0.10.17+093cb8f9c. This verifies the source on a newer compiler than the local 0.10.15 installation; it does not mean the local compiler was upgraded.

Two initial failed runs were retained: clean registry initialization was missing, then the JS export bridge was incorrectly linked as a native executable. Both were fixed with real follow-up commits, not by deleting test targets or ignoring failures.

## Pending publication/application

Mooncakes registry upload and a separate clean registry consumer install are not yet performed. No official contest application or approval exists for this project. A public repository and a successful CI run are not substitutes for those steps.

## Reproduction

Install pinned test dependencies from `tools/requirements.txt` in Python 3.12, then `node tools/verify.mjs`. `PYTHON` and `MOON` can select executable paths. Linux CI additionally sets `MOON_NATIVE=1` and runs `moon info`.

`tools/reference.py --check` regenerates external outcomes in memory and compares fixture bytes; it also freezes the eleven deviation IDs. `tools/generate_moon_tests.py`, `moon fmt`, then `git diff --exit-code -- cbor/reference_test.mbt fixtures/reference.json` detects changes to embedded expectations. All comparisons execute independently of the MoonBit implementation.

No throughput benchmark, full RFC conformance, arbitrary-schema support, external-user adoption, or production certification is claimed.
