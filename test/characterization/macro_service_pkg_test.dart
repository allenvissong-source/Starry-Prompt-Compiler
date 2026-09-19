// Characterization tests for MacroService (extracted from the main-project
// dual-SUT test into a pure-Dart, in-package test).
//
// Source of truth: test/features/prompt_compiler/macro_service_characterization_test.dart
// (SUT=package groups). Kept verbatim except for import rewrites and stripping
// the `pkg.` prefix.
import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

void main() {
  group(
    'SUT=package | MacroService deterministic expansion (behavior baseline)',
    () {
      const ctx = MacroContext(
        userName: 'Alice',
        userDescription: 'A curious traveler.',
        characterName: 'Char',
        characterDescription: 'A wise mentor.',
        characterPersonality: 'calm',
        characterScenario: 'a quiet library',
        characterFirstMessage: 'Welcome.',
        characterExamples: 'Char: Hi.',
        characterSystemPrompt: 'Be helpful.',
        characterVersion: '1.0',
        postHistoryInstructions: 'Stay in character.',
        chatId: 'chat-1',
        messageCount: 3,
        lastMessage: 'last',
        lastUserMessage: 'from-user',
        lastCharacterMessage: 'from-char',
        currentInput: 'hello there',
        originalPrompt: 'ORIGINAL',
        idleDuration: 42,
      );
      final macro = MacroService(
        ctx,
        clock: FrozenClock(DateTime.utc(2025, 1, 1)),
        random: SeededRandomSource(0),
        locale: const LocaleTag('en_US'),
        logger: const NoopLogger(),
      );

      test('empty input is returned unchanged', () {
        expect(macro.process(''), '');
      });

      test('user macros: {{user}}/{{persona}} -> userName', () {
        expect(
          macro.process('Hi {{user}} and {{persona}}'),
          'Hi Alice and Alice',
        );
      });

      test('user description macros', () {
        expect(
          macro.process('{{user_description}}|{{persona_description}}'),
          'A curious traveler.|A curious traveler.',
        );
      });

      test('character macros: name/charname/version', () {
        expect(
          macro.process('{{char}}/{{charname}}/{{char_version}}/{{version}}'),
          'Char/Char/1.0/1.0',
        );
      });

      test('character field macros', () {
        expect(
          macro.process(
            '{{description}}|{{personality}}|{{scenario}}|{{first_mes}}|'
            '{{greeting}}|{{mes_example}}|{{examples}}|{{system_prompt}}|'
            '{{char_system_prompt}}|{{post_history_instructions}}|{{jailbreak}}',
          ),
          'A wise mentor.|calm|a quiet library|Welcome.|Welcome.|Char: Hi.|'
          'Char: Hi.|Be helpful.|Be helpful.|Stay in character.|Stay in character.',
        );
      });

      test('chat macros: last messages, count, chatId', () {
        expect(
          macro.process(
            '{{lastMessage}}|{{last_message}}|{{lastUserMessage}}|'
            '{{last_user_message}}|{{lastCharMessage}}|{{last_char_message}}|'
            '{{messageCount}}|{{message_count}}|{{chatId}}|{{chat_id}}',
          ),
          'last|last|from-user|from-user|from-char|from-char|3|3|chat-1|chat-1',
        );
      });

      test('special macros: newline/nl produce a newline; trim/noop empty', () {
        expect(macro.process('a{{newline}}b{{nl}}c'), 'a\nb\nc');
        expect(macro.process('x{{trim}}y{{noop}}z'), 'xyz');
      });

      test('special macros: original/input/idle_duration', () {
        expect(
          macro.process('{{original}}|{{input}}|{{idle_duration}}'),
          'ORIGINAL|hello there|42',
        );
      });

      test('macro matching is case-insensitive', () {
        expect(macro.process('{{USER}} {{Char}}'), 'Alice Char');
      });

      test('unknown macros are left verbatim', () {
        expect(macro.process('{{totally_unknown}}'), '{{totally_unknown}}');
      });

      group('conditional {{if::...}} macro', () {
        test('truthy non-empty condition renders then-branch', () {
          expect(macro.process('{{if::yes::THEN}}'), 'THEN');
        });
        test('empty/false/zero condition renders empty (no else)', () {
          expect(macro.process('{{if::::THEN}}'), '');
          expect(macro.process('{{if::0::THEN}}'), '');
          expect(macro.process('{{if::false::THEN}}'), '');
        });
        test(
          'falsey condition with 4 args yields empty (else is unreachable)',
          () {
            expect(macro.process('{{if::0::THEN::ELSE}}'), '');
          },
        );
        test('truthy condition with 4 args returns raw then::else text', () {
          expect(macro.process('{{if::a==a::EQ::NE}}'), 'EQ::NE');
          expect(macro.process('{{if::!0::T::F}}'), 'T::F');
        });
        test('falsey equality with 4 args yields empty', () {
          expect(macro.process('{{if::a==b::EQ::NE}}'), '');
        });
      });
    },
  );

  group(
    'SUT=package | MacroService nondeterministic macros (invariants only)',
    () {
      final macro = MacroService(const MacroContext());

      test('{{random}} yields an int in 0..100', () {
        for (var i = 0; i < 50; i++) {
          final out = int.parse(macro.process('{{random}}'));
          expect(out, inInclusiveRange(0, 100));
        }
      });

      test('{{random::min::max}} stays within bounds', () {
        for (var i = 0; i < 50; i++) {
          final out = int.parse(macro.process('{{random::5::9}}'));
          expect(out, inInclusiveRange(5, 9));
        }
      });

      test('{{random::min::max}} with min>=max returns min', () {
        expect(macro.process('{{random::9::9}}'), '9');
        expect(macro.process('{{random::9::3}}'), '9');
      });

      test('{{roll::NdM}} within [N, N*M]', () {
        for (var i = 0; i < 50; i++) {
          final out = int.parse(macro.process('{{roll::2d6}}'));
          expect(out, inInclusiveRange(2, 12));
        }
        for (var i = 0; i < 50; i++) {
          final out = int.parse(macro.process('{{roll::d20}}'));
          expect(out, inInclusiveRange(1, 20));
        }
      });

      test('{{pick::a::b::c}} returns one of the options', () {
        for (var i = 0; i < 50; i++) {
          expect(macro.process('{{pick::a::b::c}}'), anyOf('a', 'b', 'c'));
        }
      });

      test('{{uuid}} matches the v4 shape', () {
        final out = macro.process('{{uuid}}');
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(out),
          isTrue,
          reason: 'got $out',
        );
      });

      test('{{year}} is a 4-digit number; {{date}} is ISO yyyy-MM-dd', () {
        expect(RegExp(r'^\d{4}$').hasMatch(macro.process('{{year}}')), isTrue);
        expect(
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(macro.process('{{date}}')),
          isTrue,
        );
      });
    },
  );
}
