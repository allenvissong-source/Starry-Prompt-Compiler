/// Abstraction over wall-clock time.
///
/// Production code should treat time as an injected dependency. Tests inject
/// [FrozenClock] to make golden output stable byte-for-byte.
abstract class Clock {
  const Clock();

  /// Returns the current instant. Implementations must be pure with respect to
  /// their own state: repeated calls to [FrozenClock.now] must yield the same
  /// value, and calls to [SystemClock.now] must consult the host wall clock.
  DateTime now();
}

/// Reads the host wall clock. Non-deterministic; do not use inside goldens.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Freezes the wall clock at a caller-provided instant.
///
/// Two [FrozenClock] instances with the same [frozen] value compare equal so
/// that consumers using them as `const` can be canonicalised.
class FrozenClock extends Clock {
  const FrozenClock(this.frozen);

  final DateTime frozen;

  @override
  DateTime now() => frozen;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FrozenClock && other.frozen == frozen;

  @override
  int get hashCode => frozen.hashCode;
}
