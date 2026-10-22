# Supported profile: rfc8610-structural-v1

This is a deliberately bounded **subset**, not a new language and not full RFC 8610 conformance. A schema either compiles in this profile or raises a schema/unsupported/limit error. Unsupported constructs must never become permissive `any`.

| RFC 8610 area | Profile behavior | Evidence |
| --- | --- | --- |
| 3.1 basic syntax | Decimal signed 64-bit integers, JSON-style text literals, semicolon comments, rule definitions, references, parenthesized types | core/adversarial tests; reference partitions |
| 3.2 occurrence | `?`, `*`, `+`, `n*m`, exact no-prefix; array matching backtracks to retain required suffix | required/optional tail, bounded repeat partitions |
| 3.3 predefined types | uint/nint/int/float/bool/tstr/text/bstr/bytes/any/nil/null | primitive and wire-type partitions |
| 3.4 choices | Type choice `/`; group choice `//` is unsupported | literal/reference choices, negative syntax tests |
| 3.5 ranges | Integer `..` inclusive and `...` exclusive; endpoints exact Int64 | signed endpoints and range partitions |
| 3.8.1 size | UTF-8 byte lengths for tstr/bstr; `uint .size N` maximum value capacity | Chinese/emoji, byte and uint partitions |
| 3.6 tags | `#6.n(type)` with a nonnegative Int64 tag | tagged-byte partitions and CBOR example |
| Recursive definitions | Consuming structural recursion allowed; non-consuming alias/choice cycles rejected | nested tree and schema-cycle tests |
| Maps | Unordered, closed by default; typed keys and occurrences; every pair matched once | closed/open/typed-key/dictionary partitions |

Unsupported: standalone/group definitions and group splicing, labelled array members, group choice, cut (`^`), generic parameters, sockets, `=/` or `//=`, unwrap `~`, enum-from-group `&`, base16/base64/byte/float literals, hexadecimal/binary integer notation, float16/32/64 and other prelude tags, `.regexp`, `.cbor`, `.bits`, `.within`, `.and` and later RFC extensions. Only primitive/resolved-primitive `.size` targets are accepted. This limits reuse of arbitrary published CDDL documents; no arbitrary-IETF-schema claim is made.

## Data mapping

- `Value` is independent of JSON/CBOR I/O. Int64 integers, Double floats, text, bytes, booleans, null, lists, maps and tags are explicit variants.
- CBOR wire types remain distinct: integer `1` does not satisfy `float`, and text does not satisfy bstr. Only text/Int64 map keys are in this profile.
- JSON integral numeric values map to Integer even with spellings like `1.0` or `1e0`. Fractional values map to Real. This is a documented adapter mapping, not preservation of an integer-vs-float wire type that JSON lacks. Integers outside +/- (2^53-1) and fractional tokens rounded into integers/underflow are rejected. Ordinary nonintegral JSON values use Double precision; this is not an exact-decimal validator.
- Duplicate JSON keys (including equivalent escaped keys) and duplicate decoded CBOR keys are input errors. String matching performs no Unicode normalization.
- CBOR maps preserve integer and text keys; diagnostic `/1` can refer to an integer key or a string key. This ambiguity affects presentation, not matching. Diagnostics report one deterministic witness path, not every error or a minimal explanation.

## Resource contract

Schema: 65,536 UTF-16 code units, 8,192 tokens, 256 rules, 256 collection entries, nesting/alias chain 64. ASCII rule identifiers in this version; unknown prelude names fail resolution.

JSON: 1,048,576 UTF-16 units at the library boundary; CLI uses a stricter 1 MiB byte limit. Numeric tokens limited to 1,024 units. Nesting is checked at 64 before standard parsing.

CBOR: 1 MiB encoded bytes, 10,000 encoded items, nesting 64 before dependency decoding. Values/keys/tags outside the Int64 profile are rejected. Maps limited to 128 members. Simple values other than false/true/null are unsupported. This is structural schema validation, not a canonical-CBOR or cryptographic verifier.

Validation: default 100,000 work steps, caller range 1..1,000,000; data/schema traversal nesting 64 and matching call stack 256. Ambiguous array/map schemas can exhaust the budget. Exhaustion raises Limit and CLI code 4; it is never silently reported as valid or as a definitive data mismatch. Inputs are read-only during validation; callers must not mutate shared arrays concurrently.

## CLI exit codes

0: valid; 1: mismatch; 2: schema/unsupported; 3: input/host; 4: budget; 64: invocation/build error. Human output and `--json` output are available. Files are local; schemas cannot load code, network resources or external includes.
