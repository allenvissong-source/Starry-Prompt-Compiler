# prompt-block-schema Specification

## Purpose
Defines the block contract the prompt compiler consumes: how a block declares its schema
version, how legacy blocks are converted without loss, and the output-stability guarantee that
makes the conversion safe to adopt.

## Requirements

### Requirement: The Compiler Consumes Exactly One Block Shape

The compiler MUST accept blocks in a single declared shape and MUST NOT branch its planning
behavior on a block's version. A version stamp that no code reads is metadata, not a
compatibility mechanism; two live shapes inside the compiler would double every routing rule
and let the two drift apart silently.

#### Scenario: A block in the declared shape is planned

- **GIVEN** a profile whose blocks are in the shape the compiler declares
- **WHEN** a plan is built from that profile
- **THEN** the plan MUST be produced without any conversion step inside the compiler

#### Scenario: A block in a superseded shape reaches the compiler boundary

- **GIVEN** a profile serialized in a shape the compiler no longer accepts
- **WHEN** it is supplied to the compiler
- **THEN** it MUST be converted to the accepted shape before planning begins
- **AND** the conversion MUST happen outside the planning logic, so that planning has exactly
  one input shape to reason about

#### Scenario: A version stamp is written on serialized output

- **GIVEN** a block or profile is serialized
- **WHEN** the version stamp is written
- **THEN** it MUST name the shape actually serialized
- **AND** a stamp that names a shape the payload does not use MUST NOT be emitted

### Requirement: Conversion From The Legacy Block Shape Is Lossless

Conversion from the legacy block shape MUST preserve every field that affects planning, and
MUST preserve unrecognized fields rather than dropping them. A conversion that quietly discards
a field converts a visible failure into a silent behavioral change, which is the failure mode
this contract exists to prevent.

#### Scenario: Every recognized field survives conversion

- **GIVEN** a legacy block with identity, kind, name, enabled flag, content, role, profile
  reference, placement, activation triggers, priority, protection and provenance all set away
  from their defaults
- **WHEN** it is converted
- **THEN** each of those values MUST be present in the converted block with the same meaning

#### Scenario: An unrecognized field survives conversion

- **GIVEN** a legacy block carrying a key the current contract does not define
- **WHEN** it is converted
- **THEN** the key and its value MUST be retained in the block's extension area
- **AND** the compiler MUST NOT read, reorder or mutate anything in that area

#### Scenario: A legacy kind outside the known set is converted

- **GIVEN** a legacy block whose kind is not one of the known built-in kinds
- **WHEN** it is converted
- **THEN** it MUST be routed as the default custom kind
- **AND** the original kind string MUST be preserved so the reclassification is traceable

#### Scenario: Placement expressed across several legacy fields is collapsed

- **GIVEN** a legacy block whose placement is spread across an anchor, an injection position and
  a depth
- **WHEN** it is converted
- **THEN** the result MUST be a single placement value whose variant is determined solely by
  those legacy fields
- **AND** the variant MUST carry exactly the attributes that variant defines and no others

#### Scenario: A profile carrying only the legacy editor section list is converted

- **GIVEN** a profile that carries no block list and only the legacy editor section list
- **WHEN** it is converted
- **THEN** each section MUST yield one block
- **AND** the resulting plan MUST be the same as the plan the legacy path produced for that
  profile

### Requirement: Migration Preserves Byte-Identical Compiler Output

The compiled output for every fixture in the behavior corpus MUST be byte-identical before and
after the migration, and that identity MUST be established by comparing against the committed
expectations. Re-recording an expectation to obtain agreement destroys the only evidence that
the conversion is correct, so the expectations are read-only for this contract.

#### Scenario: The behavior corpus is compiled after migration

- **GIVEN** every fixture in the committed behavior corpus
- **WHEN** each is compiled through the migrated pipeline
- **THEN** each output MUST equal its committed expectation byte for byte

#### Scenario: A fixture's output differs after migration

- **GIVEN** at least one fixture whose output differs from its committed expectation
- **WHEN** the difference is observed
- **THEN** the migration MUST be reported as incomplete
- **AND** the committed expectation MUST NOT be rewritten to match the new output
- **AND** the removal of the superseded path MUST NOT proceed

#### Scenario: The corpus size is asserted before comparison

- **GIVEN** the comparison is about to run
- **WHEN** the fixture set is enumerated
- **THEN** the number compared MUST be the number of fixtures actually present
- **AND** a fixture that is present but not compared MUST cause the run to fail rather than be
  silently omitted

### Requirement: The Superseded Path Is Removed Once Identity Is Proven

Once byte-identity is established, the superseded block path MUST be removed rather than kept
alongside the new one. Leaving both in the tree creates two definitions of the same concept,
and the dormant one accumulates drift that no test exercises.

#### Scenario: Identity is proven and the old path is removed

- **GIVEN** every fixture in the corpus is byte-identical
- **WHEN** the migration is completed
- **THEN** the superseded consumption path MUST NOT remain in the compiler
- **AND** exactly one block shape MUST remain reachable from the public surface

#### Scenario: Identity is not proven

- **GIVEN** one or more fixtures are not byte-identical
- **WHEN** removal is considered
- **THEN** the superseded path MUST be retained
- **AND** the unresolved difference MUST be recorded rather than worked around

#### Scenario: Naming after removal

- **GIVEN** exactly one block shape remains
- **WHEN** its public names are settled
- **THEN** they MUST NOT carry a version suffix that distinguishes them from a shape that no
  longer exists
