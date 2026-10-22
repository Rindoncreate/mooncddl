# Independent reference comparison

The pinned external reference is PyCDDL 0.6.4 (its Rust CDDL engine), with cbor2 5.6.5 producing the binary inputs. No implementation code is copied from either. The 134 cases are handwritten partitions of this profile, recorded before executing MoonBit.

Current recorded result: 123 of 134 outcomes agree with the reference. Eleven reference outcomes differ from the explicitly specified expected result. All 134 profile assertions pass the MoonBit implementation. **Do not call this 134/134 independent agreement, full RFC coverage, or a measured coverage percentage.**

| Fixture IDs | Observed external result | Profile decision and normative basis |
| --- | --- | --- |
| 20,21 | nint accepts 0 and 1 | Reject: RFC 8610 3.3 defines nint as negative integers / CBOR major type 1 |
| 23,24,25 | -2..3 rejects -2,0,3 | Accept: integer range includes both endpoints, section 3.5 |
| 50 | bstr .size 2 accepts a text string | Reject: bstr is CBOR major type 2, distinct from tstr major type 3, section 3.3 |
| 54 | uint .size 1 accepts -1 | Reject: uint base type must hold before capacity constraint, sections 3.3/3.8.1 |
| 80,84 | [* int,int] / [? int,int] accepts an empty array | Reject: the final unprefixed entry is required, section 3.2 |
| 83 | [? int,int] rejects [1,2] | Accept: the optional first item and required second item both match, section 3.2 |
| 126 | recursive int/[root] tree accepts false at a leaf | Reject: bool is not int and not an array, sections 3.3/3.4 |

These are reproducible differences of the pinned reference tool on these cases, not a claim about all versions of the Rust project. We have not sent an upstream issue or obtained maintainer confirmation. A second independent implementation has not yet been used to triangulate these eleven cases. Full source, bytes, expected profile result and actual external result remain in `fixtures/reference.json`.

The exact set of deviation IDs is asserted during regeneration. Unexpected reference changes or new disagreements fail generation and require review. Expected values are never silently overwritten to make agreement look better.

Run `python tools/reference.py --check`, `python tools/generate_moon_tests.py`, `moon fmt`, `moon test --target js`, `moon build --target js`, then `node tools/compare.mjs`. The raw comparison is `_build/differential-report.json`. One table-driven MoonBit test executes all 134 partitions across each tested backend; do not add 134 to the test-block count.
