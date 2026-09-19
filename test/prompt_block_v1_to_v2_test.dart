import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

/// Conversion contract for V1 -> V2 prompt blocks.
///
/// The placement assertions are the load-bearing ones. `placement` is a
/// verbatim restatement of V1's input fields, NOT a resolved insertion
/// position, so these tests assert that nothing is normalised, defaulted or
/// discriminated on the way through. An earlier draft of the compat matrix
/// specified a per-block `kind`/`position` discriminator; §4.4 of the matrix
/// records why that was unsound. If someone reintroduces it, the "verbatim"
/// group below is what should go red.
void main() {
  PromptBlock v1({
    String id = 'b1',
    PromptBlockKind kind = PromptBlockKind.custom,
    String name = 'block',
    String? promptProfileId,
    bool enabled = true,
    String content = '',
    String? role,
    PromptBlockPlacementPolicy placement = const PromptBlockPlacementPolicy(),
    PromptBlockActivationPolicy activation =
        const PromptBlockActivationPolicy(),
    PromptBlockPriorityPolicy priority = const PromptBlockPriorityPolicy(),
    PromptBlockProtectionPolicy protection =
        const PromptBlockProtectionPolicy(),
    PromptBlockProvenance provenance = const PromptBlockProvenance(),
  }) => PromptBlock(
    id: id,
    kind: kind,
    name: name,
    promptProfileId: promptProfileId,
    enabled: enabled,
    content: content,
    role: role,
    placementPolicy: placement,
    activationPolicy: activation,
    priorityPolicy: priority,
    protectionPolicy: protection,
    provenance: provenance,
  );

  group('kind mapping (compat matrix section 3)', () {
    test('all 15 V1 enum values map to a core: namespaced kind', () {
      // Exhaustive by construction: iterating the enum means a new V1 kind
      // cannot be added without this test covering it.
      expect(PromptBlockKind.values, hasLength(15));

      for (final kind in PromptBlockKind.values) {
        final converted = promptBlockV1ToV2(v1(kind: kind));
        expect(
          converted.kind,
          'core:${kind.name}',
          reason: '${kind.name} must map to core:${kind.name}',
        );
        expect(converted.isCoreKind, isTrue);
        expect(converted.kindName, kind.name);
      }
    });

    test('marker is answered from kind, not a carried boolean', () {
      expect(
        promptBlockV1ToV2(v1(kind: PromptBlockKind.marker)).isMarker,
        isTrue,
      );
      expect(
        promptBlockV1ToV2(v1(kind: PromptBlockKind.custom)).isMarker,
        isFalse,
      );
    });

    test(
      'an unrecognised V1 kind string decodes to custom, then core:custom',
      () {
        // V1's fromJson falls back to PromptBlockKind.custom for an unknown
        // string, so the V2 result is core:custom rather than an invented kind.
        final decoded = PromptBlock.fromJson(<String, dynamic>{
          'id': 'b1',
          'kind': 'somethingNobodyDefined',
          'name': 'block',
        });
        expect(decoded.kind, PromptBlockKind.custom);
        expect(promptBlockV1ToV2(decoded).kind, 'core:custom');
      },
    );

    test('a kind that already carries a namespace is not re-prefixed', () {
      expect(normalizePromptBlockKind('vendorx:thing'), 'vendorx:thing');
      expect(normalizePromptBlockKind('marker'), 'core:marker');
      expect(normalizePromptBlockKind('  '), 'core:custom');
    });
  });

  group('placement is a verbatim copy (compat matrix section 4.1)', () {
    test('a block with no placement policy yields all-null placement', () {
      // 45 of the corpus's 46 blocks are this shape. Under the removed pattern
      // table they would have been hard-coded to position "after".
      final converted = promptBlockV1ToV2(v1());
      expect(converted.placement.anchor, 'relative');
      expect(converted.placement.injectionPosition, isNull);
      expect(converted.placement.depth, isNull);
      expect(converted.placement.injectionOrder, isNull);
    });

    test('anchor is copied without trimming or lower-casing', () {
      // The planner normalises at its own read site. Doing it here too would
      // create a second, divergent notion of the same string.
      for (final raw in <String>[
        'relative',
        'absolute',
        'history',
        'authorNote',
        '  AuthorNote  ',
        'MyOutlet',
        'chat_history',
      ]) {
        final converted = promptBlockV1ToV2(
          v1(placement: PromptBlockPlacementPolicy(anchor: raw)),
        );
        expect(
          converted.placement.anchor,
          raw,
          reason: 'anchor "$raw" must survive byte-for-byte',
        );
      }
    });

    test('injectionPosition and depth are copied including negatives', () {
      final converted = promptBlockV1ToV2(
        v1(
          placement: const PromptBlockPlacementPolicy(
            anchor: 'history',
            injectionPosition: -1,
            depth: 4,
          ),
        ),
      );
      expect(converted.placement.anchor, 'history');
      expect(converted.placement.injectionPosition, -1);
      expect(converted.placement.depth, 4);
    });

    test('the one real fixture shape round-trips', () {
      // A09_absolute_depth_splice's splice block is the only block in the
      // 22-fixture corpus carrying a placementPolicy at all.
      final converted = promptBlockV1ToV2(
        v1(
          placement: const PromptBlockPlacementPolicy(
            anchor: 'absolute',
            depth: 1,
          ),
        ),
      );
      expect(converted.placement.anchor, 'absolute');
      expect(converted.placement.depth, 1);
      expect(converted.placement.injectionPosition, isNull);
    });
  });

  group('injectionOrder mirror (compat matrix section 4.2)', () {
    test('mirrored unconditionally, whatever the anchor', () {
      for (final anchor in <String>[
        'relative',
        'absolute',
        'history',
        'authorNote',
        'someOutlet',
      ]) {
        final converted = promptBlockV1ToV2(
          v1(
            placement: PromptBlockPlacementPolicy(anchor: anchor),
            priority: const PromptBlockPriorityPolicy(
              sortOrder: 7,
              injectionOrder: 42,
            ),
          ),
        );
        expect(
          converted.placement.injectionOrder,
          42,
          reason: 'anchor "$anchor" must still mirror injectionOrder',
        );
        expect(converted.priority.injectionOrder, 42);
        expect(converted.priority.sortOrder, 7);
      }
    });

    test('a null injectionOrder stays null on both sides', () {
      final converted = promptBlockV1ToV2(
        v1(priority: const PromptBlockPriorityPolicy(sortOrder: 3)),
      );
      expect(converted.priority.injectionOrder, isNull);
      expect(converted.placement.injectionOrder, isNull);
      expect(converted.priority.sortOrder, 3);
    });
  });

  group('field mapping (compat matrix section 2)', () {
    test('all five policy objects away from their defaults survive', () {
      final converted = promptBlockV1ToV2(
        v1(
          id: 'block-9',
          promptProfileId: 'profile-9',
          kind: PromptBlockKind.authorNote,
          name: 'Author note',
          enabled: false,
          content: 'body text',
          role: 'assistant',
          placement: const PromptBlockPlacementPolicy(
            anchor: 'authorNote',
            injectionPosition: 1,
            depth: 2,
          ),
          activation: const PromptBlockActivationPolicy(
            generationTriggers: <String>['chat', 'continue'],
          ),
          priority: const PromptBlockPriorityPolicy(
            sortOrder: 11,
            injectionOrder: 12,
          ),
          protection: const PromptBlockProtectionPolicy(
            locked: true,
            forbidOverride: true,
          ),
          provenance: const PromptBlockProvenance(
            source: 'import',
            identifier: 'st:authorNote',
            extension: true,
          ),
        ),
      );

      expect(converted.id, 'block-9');
      expect(converted.promptProfileId, 'profile-9');
      expect(converted.kind, 'core:authorNote');
      expect(converted.name, 'Author note');
      expect(converted.enabled, isFalse);
      expect(converted.content, 'body text');
      expect(converted.role, 'assistant');
      expect(converted.activation.generationTriggers, <String>[
        'chat',
        'continue',
      ]);
      expect(converted.protection.locked, isTrue);
      expect(converted.protection.forbidOverride, isTrue);
      expect(converted.provenance.source, 'import');
      expect(converted.provenance.identifier, 'st:authorNote');
      expect(converted.provenance.extension, isTrue);
    });

    test('the serialized form stamps schemaVersion 2', () {
      final json = promptBlockV1ToV2(v1()).toJson();
      expect(json['schemaVersion'], 2);
    });
  });

  group('unknown keys (compat matrix section 7)', () {
    test('an unknown V1 key is preserved under extensions.legacy_v1', () {
      final raw = <String, dynamic>{
        'id': 'b1',
        'kind': 'custom',
        'name': 'block',
        'someForkOnlyField': <String, dynamic>{'nested': 1},
        'anotherOddity': 'kept',
      };
      final converted = promptBlockV1ToV2(
        PromptBlock.fromJson(raw),
        rawJson: raw,
      );

      final legacy = converted.extensions['legacy_v1'] as Map<String, dynamic>;
      expect(legacy['someForkOnlyField'], <String, dynamic>{'nested': 1});
      expect(legacy['anotherOddity'], 'kept');
    });

    test('known keys are not swept into legacy_v1', () {
      final raw = <String, dynamic>{
        'id': 'b1',
        'kind': 'custom',
        'name': 'block',
        'enabled': true,
        'content': 'c',
        'role': 'system',
        'placementPolicy': <String, dynamic>{'anchor': 'relative'},
        'activationPolicy': <String, dynamic>{'generationTriggers': <String>[]},
        'priorityPolicy': <String, dynamic>{'sortOrder': 1},
        'protectionPolicy': <String, dynamic>{'locked': false},
        'provenance': <String, dynamic>{'source': 'app'},
      };
      final converted = promptBlockV1ToV2(
        PromptBlock.fromJson(raw),
        rawJson: raw,
      );
      expect(converted.extensions, isEmpty);
    });

    test('isMarker in the input is ignored, not carried', () {
      // Section 5: V2 answers this from `kind`. A stale boolean would be a
      // second source of truth.
      final raw = <String, dynamic>{
        'id': 'b1',
        'kind': 'custom',
        'name': 'block',
        'isMarker': true,
      };
      final converted = promptBlockV1ToV2(
        PromptBlock.fromJson(raw),
        rawJson: raw,
      );
      expect(converted.extensions, isEmpty);
      expect(converted.isMarker, isFalse);
      expect(converted.toJson().containsKey('isMarker'), isFalse);
    });

    test('no raw json means no extensions rather than a crash', () {
      expect(promptBlockV1ToV2(v1()).extensions, isEmpty);
    });
  });

  group('list conversion', () {
    test('order is preserved and raw json is matched positionally', () {
      final blocks = <PromptBlock>[
        v1(id: 'a', kind: PromptBlockKind.systemPrompt),
        v1(id: 'b', kind: PromptBlockKind.marker),
      ];
      final raws = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a', 'extraA': 1},
        <String, dynamic>{'id': 'b', 'extraB': 2},
      ];
      final converted = promptBlocksV1ToV2(blocks, rawJson: raws);

      expect(converted.map((b) => b.id).toList(), <String>['a', 'b']);
      expect(
        (converted[0].extensions['legacy_v1']
            as Map<String, dynamic>)['extraA'],
        1,
      );
      expect(
        (converted[1].extensions['legacy_v1']
            as Map<String, dynamic>)['extraB'],
        2,
      );
    });

    test('a shorter rawJson list does not throw', () {
      final converted = promptBlocksV1ToV2(
        <PromptBlock>[v1(id: 'a'), v1(id: 'b')],
        rawJson: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a'},
        ],
      );
      expect(converted, hasLength(2));
      expect(converted[1].extensions, isEmpty);
    });
  });
}
