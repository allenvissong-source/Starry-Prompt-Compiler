import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('Clock', () {
    test('FrozenClock returns the same instant on every call', () {
      final t = DateTime.utc(2025, 1, 1, 12, 34, 56);
      final clock = FrozenClock(t);
      expect(clock.now(), t);
      expect(clock.now(), t);
    });

    test('FrozenClock value equality', () {
      final a = FrozenClock(DateTime.utc(2025, 1, 1));
      final b = FrozenClock(DateTime.utc(2025, 1, 1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('SystemClock returns advancing wall-clock time', () async {
      const clock = SystemClock();
      final first = clock.now();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = clock.now();
      expect(second.isAfter(first) || second.isAtSameMomentAs(first), isTrue);
    });
  });

  group('RandomSource', () {
    test('SeededRandomSource is deterministic for a given seed', () {
      final a = SeededRandomSource(0);
      final b = SeededRandomSource(0);
      for (var i = 0; i < 32; i++) {
        expect(a.nextInt(1 << 20), b.nextInt(1 << 20));
      }
    });

    test('SeededRandomSource nextDouble stays in [0,1)', () {
      final r = SeededRandomSource(42);
      for (var i = 0; i < 128; i++) {
        final v = r.nextDouble();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('SecureRandomSource honours the bounds', () {
      final r = SecureRandomSource();
      for (var i = 0; i < 32; i++) {
        expect(r.nextInt(10), inInclusiveRange(0, 9));
      }
    });
  });

  group('LocaleTag', () {
    test('defaults to en_US', () {
      expect(const LocaleTag().tag, 'en_US');
    });

    test('value equality on tag', () {
      expect(const LocaleTag('zh_CN'), const LocaleTag('zh_CN'));
      expect(const LocaleTag('en_US'), isNot(const LocaleTag('zh_CN')));
    });
  });

  group('Logger', () {
    test('NoopLogger swallows every level without throwing', () {
      const logger = NoopLogger();
      expect(() {
        logger.debug('d');
        logger.info('i');
        logger.warn('w');
        logger.error('e', Exception('boom'), StackTrace.current);
      }, returnsNormally);
    });

    test('CallbackLogger forwards every level to the sink', () {
      final captured = <String>[];
      final logger = CallbackLogger((level, message, [error, stackTrace]) {
        captured.add('$level:$message');
      });
      logger.debug('d');
      logger.info('i');
      logger.warn('w');
      logger.error('e');
      expect(captured, ['debug:d', 'info:i', 'warn:w', 'error:e']);
    });
  });
}
