# References and dependencies

- Original implementation: Rindoncreate, MIT, with AI assistance. No code or development history from the prior pet product or MoonSchedule fork is incorporated.
- `2515050242/cbor@0.1.2`: MIT, runtime dependency only of the CBOR adapter. Its existing encoding/decoding/data model is attributed to its author and is not counted as our contribution. See https://mooncakes.io/docs/2515050242/cbor@0.1.2 and its bundled LICENSE. It also includes a programmatic ValidationRule API; that API is not a CDDL compiler. Only its codec/data model is used here.
- MoonBit core: Apache-2.0, compiler-supplied JSON, strings, collections and UTF-8 utilities.
- PyCDDL 0.6.4: MIT, independent development-only Rust CDDL reference; https://pypi.org/project/pycddl/ . No Python/Rust reference code is copied into the library.
- cbor2 5.6.5: MIT, development-only fixture encoder; https://pypi.org/project/cbor2/ . Binary examples are newly authored data encoded using this tool.
- RFC 8610: specification reference, https://www.rfc-editor.org/rfc/rfc8610.html . We implement a documented subset; we do not copy the RFC grammar or source-code components. Examples and tests are newly authored rather than copied RFC code components.

No claim of full standards conformance, external adoption, production safety certification or contest acceptance is made.
