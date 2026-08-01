# Atlas Canonical JSON Profile

Status: S2-B IMPLEMENTED - PENDING S2-C INDEPENDENT VERIFICATION AND FOUNDER FREEZE

Profile identity: `atlas-canonical-json`, revision `1`

## 1. Purpose

This profile defines one deterministic JSON byte representation for Atlas
records and release manifests. It uses RFC 8785 without changing its output
algorithm and narrows the accepted input domain through fail-closed Atlas
rules.

The profile is technical infrastructure. It does not define a domain schema,
record vocabulary, semantic array order, checksum self-exclusion path, URL
policy, or Symbol meaning.

## 2. Normative Basis

- RFC 8259: JSON syntax and UTF-8 interchange.
- RFC 7493: I-JSON interoperability restrictions.
- RFC 8785: JSON Canonicalization Scheme (JCS).
- Verified RFC 8785 errata 6292 and 7920.

For every accepted value, canonical output MUST be byte-for-byte compatible
with RFC 8785. Atlas restrictions change only which inputs are accepted.

## 3. Accepted Input

- Byte input MUST be well-formed UTF-8 and MUST NOT start with a BOM.
- JSON syntax MUST be complete; trailing non-whitespace data is invalid.
- Object property names MUST be unique after JSON escape decoding.
- Strings and property names MUST contain valid Unicode scalar values.
- Unicode noncharacters MUST be rejected.
- Strings MUST be preserved exactly. Trimming, normalization, case folding,
  and URL rewriting are forbidden.
- Integer JSON tokens and programmatic integer values MUST remain within
  `-9007199254740991..9007199254740991`.
- Programmatic doubles MUST be finite IEEE-754 binary64 values.
- Negative zero MUST be rejected. Numeric overflow and underflow to zero MUST
  be rejected.
- Generic canonicalization MAY accept any JSON root value. Domain adapters own
  any object-root requirement.

NFC validation is field-aware and belongs to future record/schema adapters.
This profile never normalizes strings and is not an NFC authority.

## 4. Canonical Output

- Output MUST be UTF-8 without BOM, whitespace, indentation, or trailing LF.
- Literals, strings, and numbers MUST follow RFC 8785 primitive serialization.
- Object properties MUST be recursively sorted by unsigned UTF-16 code units
  of their decoded, unescaped names.
- Array element order MUST remain unchanged. Objects inside arrays remain
  recursively canonicalized.
- Locale, map insertion order, file path, operating system, and wall-clock time
  MUST NOT affect output.

## 5. Checksum

The checksum of a prepared payload is:

`sha256:<lowercase-hex(SHA-256(canonical UTF-8 bytes))>`

The canonical package never removes properties. A domain adapter MUST prepare
the exact checksum payload before canonicalization. Only the record's own
checksum field may be omitted according to its frozen contract; nested and
dependency checksums remain present. For a release manifest, only the root
`manifestChecksum` is omitted.

## 6. Bootstrap Identity

`atlas_canonical_json_profile_r1.json` is the immutable bootstrap descriptor.
It carries neither its own checksum nor a `CanonicalJsonProfileRef`. Its
canonical SHA-256 is stored in the external freeze record and exposed by
`AtlasCanonicalJsonProfile.revision1`.

The descriptor's canonical content, this specification, the conformance
vectors, the VCS commit, and the Founder approval form the revision-1 trust
anchor. A line ending in the checked-in authoring file is not part of the
canonical descriptor payload.

## 7. Ownership Boundary

`atlas_canonical_json` owns:

- strict technical JSON parsing;
- Atlas input restrictions;
- RFC 8785 canonical bytes;
- SHA-256 checksum formatting;
- typed technical failures.

Future record/schema adapters own:

- required, optional, nullable, and unknown fields;
- human-text NFC validation;
- record IDs, timestamps, and cross-references;
- canonical semantic array ordering and duplicate rules;
- exact checksum self-exclusion payload construction.

## 8. Versioning

Any change to canonical bytes or the accepted/rejected input set requires a
new positive profile revision. A compatible implementation correction that
preserves the frozen conformance behavior changes only package SemVer. A new
canonicalization family requires a new `profileId`.

Existing releases are always verified with their exact profile identity and
MUST NOT be silently re-canonicalized under a newer revision.

## 9. Conformance

Revision 1 requires:

- RFC 8785 core, UTF-16 ordering, and Appendix B vectors;
- Atlas BOM, duplicate, Unicode, integer, negative-zero, and hash vectors;
- deterministic Windows and Linux Dart VM results;
- deterministic Flutter Android AOT results;
- comparison with an independent RFC 8785 implementation;
- frozen upstream Atlas source hashes.

All vectors are local and network-independent during normal verification.

## 10. Explicit Exclusions

This profile does not include JSON Schema, Symbol serialization, dataset
parsing, record authoring, real Symbol data, URL normalization, Interpretation,
ranking, confidence, AI, language generation, file I/O, networking, or any
Vision, Pattern, Knowledge, or Symbol behavior.
