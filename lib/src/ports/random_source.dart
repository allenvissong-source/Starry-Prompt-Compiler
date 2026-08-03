import 'dart:math' as math;

/// Abstraction over random-number generation.
///
/// Callers may only require the subset of [math.Random] surface that the
/// prompt compiler actually needs: an integer in a half-open range, a double
/// in [0, 1), and a boolean. Additional methods should be added deliberately.
abstract class RandomSource {
  const RandomSource();

  /// Returns an integer in the half-open range `[0, max)`.
  int nextInt(int max);

  /// Returns a double in `[0.0, 1.0)`.
  double nextDouble();

  /// Returns a boolean with 50/50 probability.
  bool nextBool();
}

/// Cryptographically-secure random source. Non-deterministic; do not use in
/// goldens.
class SecureRandomSource extends RandomSource {
  SecureRandomSource() : _random = math.Random.secure();
  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
  @override
  double nextDouble() => _random.nextDouble();
  @override
  bool nextBool() => _random.nextBool();
}

/// Deterministic PRNG seeded by the caller. Used everywhere in goldens.
///
/// Wraps `dart:math`'s [math.Random] rather than reimplementing the algorithm
/// so that behaviour matches the Dart platform's canonical LCG exactly.
class SeededRandomSource extends RandomSource {
  SeededRandomSource(int seed) : _random = math.Random(seed);
  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
  @override
  double nextDouble() => _random.nextDouble();
  @override
  bool nextBool() => _random.nextBool();
}
