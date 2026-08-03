import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('VariableEngine + InMemoryVariableStore (D-2 parity)', () {
    late InMemoryVariableStore store;
    late VariableEngine engine;

    setUp(() {
      store = InMemoryVariableStore();
      engine = VariableEngine(store: store);
    });

    test('resolveVariable: local overrides global, else returns name', () {
      store.setGlobal('name', 'Alice');
      store.setLocal('c1', 'name', 'Bob');

      expect(engine.resolveVariable('name', chatId: 'c1'), 'Bob');
      expect(engine.resolveVariable('name'), 'Alice');
      expect(engine.resolveVariable('unknown'), 'unknown');
    });

    test('addLocal: numeric add, string concat, list append', () {
      store.setLocal('c1', 'count', 3);
      expect(engine.addLocal('c1', 'count', 4), 7);
      expect(store.getLocal('c1', 'count'), 7);

      store.setLocal('c1', 'greet', 'hi');
      expect(engine.addLocal('c1', 'greet', '!'), 'hi!');

      store.setLocal('c1', 'list', '[1,2]');
      final result = engine.addLocal('c1', 'list', 3);
      expect(result, [1, 2, 3]);
    });

    test('increment / decrement local & global', () {
      store.setGlobal('score', 10);
      expect(engine.incrementGlobal('score'), 11);
      expect(engine.decrementGlobal('score'), 10);

      store.setLocal('c1', 'x', 5);
      expect(engine.incrementLocal('c1', 'x'), 6);
      expect(engine.decrementLocal('c1', 'x'), 5);
    });

    // Host baseline behavior: macros run in FIXED pattern-iteration order —
    // set → add → inc → dec → get (locals), then the same for globals. So
    // testing a chained expression means the final `get` sees the terminal
    // value, not an intermediate one. This is deliberate parity with the
    // legacy `VariablesService.processVariableMacros`.
    test('processVariableMacros: setvar + getvar (single-pass simple case)', () {
      final out = engine.processVariableMacros(
        '[{{setvar::greet::hi}}][{{getvar::greet}}]',
        chatId: 'c1',
      );
      expect(out, '[][hi]');
      expect(store.getLocal('c1', 'greet'), 'hi');
    });

    test('processVariableMacros: local chain reflects fixed pass order', () {
      store.setLocal('c1', 'a', 1);
      // Pass order: set (n/a) → add (a=1+5=6.0) → inc (a=7.0) → dec (a=6.0)
      //                                        → get(both)=6.0.
      // Values become doubles because `addLocal` normalizes via
      // `double.tryParse`, matching host `VariablesService.addLocalVariable`.
      final out = engine.processVariableMacros(
        'inc={{incvar::a}} dec={{decvar::a}} add={{addvar::a::5}} g=[{{getvar::a}}]',
        chatId: 'c1',
      );
      // Integer-valued doubles stringify as `6.0` on the Dart VM but `6` on
      // dart2js/web (a platform `.toString()` divergence, not a logic diff).
      // Accept both forms so this parity gate passes on VM and web alike.
      expect(out, anyOf('inc=7.0 dec=6.0 add= g=[6.0]', 'inc=7 dec=6 add= g=[6]'));
    });

    test('processVariableMacros: setglobalvar + getglobalvar', () {
      final out = engine.processVariableMacros(
        '[{{setglobalvar::name::Alice}}][{{getglobalvar::name}}]',
      );
      expect(out, '[][Alice]');
      expect(store.getGlobal('name'), 'Alice');
    });

    test('processVariableMacros: global chain reflects fixed pass order', () {
      store.setGlobal('g', 7);
      // Pass order: set (n/a) → add (g=7+3=10.0) → inc (g=11.0) → dec (g=10.0)
      //                                        → get(both)=10.0.
      final out = engine.processVariableMacros(
        'inc={{incglobalvar::g}} dec={{decglobalvar::g}} '
        'add={{addglobalvar::g::3}} v=[{{getglobalvar::g}}]',
      );
      // Integer-valued doubles stringify as `10.0` on the Dart VM but `10` on
      // dart2js/web. Accept both platform forms (see local-chain note above).
      expect(out, anyOf('inc=11.0 dec=10.0 add= v=[10.0]', 'inc=11 dec=10 add= v=[10]'));
    });

    test('local macros expand to empty when chatId is null', () {
      final out = engine.processVariableMacros('x={{getvar::foo}}|{{incvar::bar}}');
      expect(out, 'x=|');
    });

    test('import / export local via metadata', () {
      store.importLocalFromMetadata('c1', {'variables': {'k': 'v', 'n': 42}});
      expect(store.getAllLocal('c1'), {'k': 'v', 'n': 42});

      final exported = store.exportLocalToMetadata('c1');
      expect(exported, {'variables': {'k': 'v', 'n': 42}});

      expect(store.exportLocalToMetadata('empty'), isNull);
    });

    test('getLocal returns "" when missing; getLocal coerces numeric strings', () {
      expect(store.getLocal('c1', 'missing'), '');
      store.setLocal('c1', 'x', '3.14');
      expect(store.getLocal('c1', 'x'), closeTo(3.14, 1e-9));
      store.setLocal('c1', 'y', '42');
      expect(store.getLocal('c1', 'y'), 42);
    });

    test('indexed set/get for local list & map', () {
      store.setLocal('c1', 'arr', null, index: '2', asType: 'int');
      // arr backfilled to [null, null, 0]
      expect(store.getLocal('c1', 'arr', index: '2'), 0);

      store.setLocal('c1', 'obj', 'v', index: 'key');
      expect(store.getLocal('c1', 'obj', index: 'key'), 'v');
    });

    test('empty variable name throws ArgumentError', () {
      expect(() => store.setLocal('c1', '', 1), throwsArgumentError);
      expect(() => store.setGlobal('', 1), throwsArgumentError);
    });
  });
}
