import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

/// Wire-compatibility contract for the persisted `prompt_block` payload.
///
/// The catalog already holds rows written by the V1 model's `toJson`. This
/// suite pins that the V2-based codec reads and writes those exact bytes, so a
/// row rewritten by this build is still readable by a client that has not
/// migrated.
///
/// The hazard being guarded is quiet, which is why it is worth a suite of its
/// own: `LegacyPromptBlock.fromJson` resolved an unknown kind with
/// `orElse: () => custom`. An old client handed a namespaced
/// `"core:systemPrompt"` would not throw — it would silently file the block as
/// `custom`. So "the write still parses" is not the bar; "the write is
/// byte-identical" is.
void main() {
  /// A block written the way V1's `toJson` wrote one, with every policy object
  /// away from its default so a dropped field cannot hide behind a coincidence.
  Map<String, dynamic> legacyJson() => <String, dynamic>{
    'id': 'block-9',
    'promptProfileId': 'profile-9',
    'kind': 'authorNote',
    'name': 'Author note',
    'enabled': false,
    'content': 'stay in character',
    'role': 'system',
    'placementPolicy': <String, dynamic>{
      'anchor': 'absolute',
      'injectionPosition': 1,
      'depth': 4,
    },
    'activationPolicy': <String, dynamic>{
      'generationTriggers': <String>['normal', 'continue'],
    },
    'priorityPolicy': <String, dynamic>{'sortOrder': 7, 'injectionOrder': 3},
    'protectionPolicy': <String, dynamic>{
      'locked': true,
      'forbidOverride': true,
    },
    'provenance': <String, dynamic>{
      'source': 'imported',
      'identifier': 'author-note',
      'extension': true,
    },
  };

  group('legacy wire round trip', () {
    test('a fully-populated legacy block round trips byte for byte', () {
      final original = legacyJson();

      final restored = promptBlockToLegacyJson(
        promptBlockFromLegacyJson(original),
      );

      expect(restored, original);
    });

    test('a minimal legacy block round trips to V1 defaults', () {
      // What V1 emitted for a block left at its defaults: anchor present,
      // the three policy objects present, optional keys absent.
      final original = <String, dynamic>{
        'id': 'b1',
        'kind': 'custom',
        'name': 'plain',
        'enabled': true,
        'content': '',
        'placementPolicy': <String, dynamic>{'anchor': 'relative'},
        'activationPolicy': <String, dynamic>{'generationTriggers': <String>[]},
        'priorityPolicy': <String, dynamic>{'sortOrder': 0},
        'protectionPolicy': <String, dynamic>{
          'locked': false,
          'forbidOverride': false,
        },
        'provenance': <String, dynamic>{'source': 'local', 'extension': false},
      };

      expect(
        promptBlockToLegacyJson(promptBlockFromLegacyJson(original)),
        original,
      );
    });

    test('every one of the 15 kinds survives as its bare name', () {
      // The namespace must never reach the wire: a namespaced kind read by an
      // unmigrated client silently becomes `custom`.
      for (final kind in LegacyPromptBlockKind.values) {
        final wire = promptBlockToLegacyJson(
          promptBlockFromLegacyJson(<String, dynamic>{
            'id': 'b',
            'kind': kind.name,
            'name': 'n',
          }),
        );
        expect(
          wire['kind'],
          kind.name,
          reason: '${kind.name} must stay bare on the wire',
        );
        expect(wire['kind'].toString().contains(':'), isFalse);
      }
    });

    test('an unknown kind degrades exactly as V1 did', () {
      // V1's `orElse: () => custom`. Reproduced deliberately: changing it here
      // would be a behaviour change disguised as a migration.
      final block = promptBlockFromLegacyJson(<String, dynamic>{
        'id': 'b',
        'kind': 'someFutureKindV9',
        'name': 'n',
      });
      expect(block.kind, 'core:custom');
      expect(promptBlockToLegacyJson(block)['kind'], 'custom');
    });

    test('an unknown wire key survives the round trip', () {
      final original = legacyJson()
        ..['someForkOnlyField'] = <String, int>{'nested': 1};

      final restored = promptBlockToLegacyJson(
        promptBlockFromLegacyJson(original),
      );

      expect(restored['someForkOnlyField'], <String, int>{'nested': 1});
      expect(restored, original);
    });

    test('an incoming isMarker is dropped rather than echoed', () {
      // V2 answers this from `kind`; echoing the boolean back would preserve a
      // second source of truth that can contradict it.
      final restored = promptBlockToLegacyJson(
        promptBlockFromLegacyJson(<String, dynamic>{
          'id': 'b',
          'kind': 'custom',
          'name': 'n',
          'isMarker': true,
        }),
      );
      expect(restored.containsKey('isMarker'), isFalse);
    });

    test('the V2 model itself never leaks onto the wire', () {
      // schemaVersion / placement / activation / priority / protection /
      // extensions are V2 spellings. None may appear in a legacy payload.
      final wire = promptBlockToLegacyJson(
        promptBlockFromLegacyJson(legacyJson()),
      );
      for (final v2Key in <String>[
        'schemaVersion',
        'placement',
        'activation',
        'priority',
        'protection',
        'extensions',
      ]) {
        expect(
          wire.containsKey(v2Key),
          isFalse,
          reason: '$v2Key is a V2 spelling and must not reach the wire',
        );
      }
    });

    test('the legacy reader agrees with the V1-object converter', () {
      // Two independent paths to the same V2 block: parse the wire directly,
      // or build the V1 object and convert it. They must not disagree, or the
      // stored rows and the in-memory objects mean different things.
      final json = legacyJson();

      final viaWire = promptBlockFromLegacyJson(json);
      final viaModel = promptBlockFromLegacy(LegacyPromptBlock.fromJson(json));

      expect(viaWire.toJson(), viaModel.toJson());
    });
  });
}
