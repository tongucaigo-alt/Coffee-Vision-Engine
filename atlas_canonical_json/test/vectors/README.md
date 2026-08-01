# Atlas Canonical JSON Golden Vectors

`jcs_reference/` contains the six official RFC 8785 development-portal
fixtures pinned at upstream commit
`19d51d7fe467d4706a3ff08adf8a748f29fc21e0`.

`rfc8785_random_numbers.json` contains 256 deterministic IEEE-754 binary64
samples generated with independent Python package `rfc8785 0.1.4`, seed
`0xA71A5`. Its SHA-256 is
`afbc9781a55c703ab7d74521fcbd78046ac889fca16e91afd96ef120f63402c`.

The generated set excludes NaN, infinity, and negative zero because Atlas
rejects those values before RFC 8785 serialization. Fixtures are immutable
within profile revision 1 and normal test execution is network-independent.
