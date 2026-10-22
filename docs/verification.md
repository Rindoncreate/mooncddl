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

## Pending external evidence

Linux native and remote CI must be verified on an actual run, not inferred from workflow YAML. Mooncakes registry upload and a separate clean consumer install are not yet performed. No official contest application or approval exists for this project.

## Reproduction

Install pinned test dependencies from `tools/requirements.txt` in Python 3.12, then `node tools/verify.mjs`. `PYTHON` and `MOON` can select executable paths. Linux CI additionally sets `MOON_NATIVE=1` and runs `moon info`.

`tools/reference.py --check` regenerates external outcomes in memory and compares fixture bytes; it also freezes the eleven deviation IDs. `tools/generate_moon_tests.py`, `moon fmt`, then `git diff --exit-code -- cbor/reference_test.mbt fixtures/reference.json` detects changes to embedded expectations. All comparisons execute independently of the MoonBit implementation.

No throughput benchmark, full RFC conformance, arbitrary-schema support, external-user adoption, or production certification is claimed.
