# instant-serialization-basis Specification

## Purpose
Defines the single time basis this package uses whenever an instant leaves memory, and what a
serialization round-trip must preserve, so that a stored value cannot be ambiguous about which
basis produced it.

## Requirements

### Requirement: A Serialized Instant MUST Carry One Unambiguous Basis

Every instant this package writes to storage or to an exchange format MUST be serialized in a
single, explicitly marked time basis. A value whose basis is implicit cannot be read back
correctly by anyone who does not know which code path wrote it.

#### Scenario: An instant is written

- **GIVEN** an instant that is about to be serialized
- **WHEN** it is converted to its stored form
- **THEN** it MUST be normalized to the package's single declared basis before conversion
- **AND** the resulting string MUST carry the marker that identifies that basis

#### Scenario: The value came from the ambient clock

- **GIVEN** an instant obtained from the ambient clock, which yields the host's local time
- **WHEN** it is serialized
- **THEN** it MUST be normalized first
- **AND** the stored form MUST NOT vary with the host's configured time zone

#### Scenario: Two different code paths write the same logical field

- **GIVEN** the same logical field written by two different call sites
- **WHEN** both results are read back
- **THEN** they MUST be indistinguishable in basis

### Requirement: A Shared Helper MUST NOT Be Extracted Before The Basis Is Unified

Consolidation of the serialization sites into a shared helper MUST happen only after every site
already produces the same basis. Extracting first would give a single implementation that
enshrines whichever behaviour the author happened to start from, and the resulting helper would
look authoritative while being wrong.

#### Scenario: Consolidation is proposed while sites still disagree

- **GIVEN** call sites that do not yet agree on the time basis
- **WHEN** extraction of a shared helper is attempted
- **THEN** it MUST be deferred until the basis is unified

#### Scenario: Consolidation proceeds after unification

- **GIVEN** every site already producing the declared basis
- **WHEN** the shared helper is extracted
- **THEN** the extraction MUST be behaviour-preserving
- **AND** a diff of serialized output before and after MUST be empty

### Requirement: Round-Trip Coverage MUST Include An Input That Can Fail

A round-trip test MUST be fed at least one instant that is not already in the target basis. A
suite whose inputs are all pre-normalized passes whether or not the normalization exists, and so
proves nothing about it.

#### Scenario: A test asserts round-trip fidelity

- **GIVEN** a round-trip test over a serialized instant
- **WHEN** its inputs are chosen
- **THEN** at least one MUST be in a basis other than the target basis

#### Scenario: The normalization is hypothetically removed

- **GIVEN** the coverage described above
- **WHEN** the normalization step is removed from the code
- **THEN** at least one test MUST fail
