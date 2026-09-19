/// Minimal logger contract used by macros / regex.
///
/// Replaces the Flutter `debugPrint` / `kDebugMode` pair that the host code
/// currently uses. The prompt compiler must not depend on Flutter, so callers
/// wire up whatever sink they want (or [NoopLogger] to discard).
abstract class Logger {
  const Logger();

  void debug(String message);
  void info(String message);
  void warn(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Discards every log call. Default for pure tests and any production caller
/// that does not care about diagnostics.
class NoopLogger extends Logger {
  const NoopLogger();

  @override
  void debug(String message) {}
  @override
  void info(String message) {}
  @override
  void warn(String message) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Forwards every level to a caller-supplied sink so hosts can plug in any
/// logging framework without pulling it into this package.
class CallbackLogger extends Logger {
  const CallbackLogger(this._sink);
  final void Function(
    String level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ])
  _sink;

  @override
  void debug(String message) => _sink('debug', message);
  @override
  void info(String message) => _sink('info', message);
  @override
  void warn(String message) => _sink('warn', message);
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _sink('error', message, error, stackTrace);
}
