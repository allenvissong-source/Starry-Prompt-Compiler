/// Port for variable persistence used by [VariableEngine] and downstream
/// macros. This is a **pure interface** — no IO, no async surprises: every
/// method returns synchronously (mirrors the current in-memory behavior of
/// the host `VariablesService`; host-side persistence is orchestrated via the
/// adapter's `flush` / `initialize` methods, not through this port).
///
/// Scopes:
/// - **local**: per-chat variables identified by `chatId`.
/// - **global**: app-wide variables (no `chatId`).
///
/// Adapters that need to persist to durable storage (e.g. SharedPreferences)
/// should mutate their in-memory map on the store calls and schedule a flush
/// via their own lifecycle hooks.
abstract class VariableStore {
  const VariableStore();

  // ---------------- Local (per-chat) ----------------

  /// Get a local variable. Returns `''` (empty string) when absent, matching
  /// the host `VariablesService.getLocalVariable` contract.
  dynamic getLocal(String chatId, String name, {String? index});

  /// Set a local variable. When `index` is provided, the value is written
  /// into the sub-slot of the existing container (list index or map key).
  /// `asType` coerces the value ("number" / "int" / "bool" / "string").
  void setLocal(
    String chatId,
    String name,
    dynamic value, {
    String? index,
    String? asType,
  });

  /// Whether a local variable exists.
  bool existsLocal(String chatId, String name);

  /// Delete a local variable.
  void deleteLocal(String chatId, String name);

  /// Return an unmodifiable snapshot of all local variables for `chatId`.
  Map<String, dynamic> getAllLocal(String chatId);

  /// Remove every local variable for `chatId`.
  void clearLocal(String chatId);

  /// Import local variables from chat metadata (`metadata['variables']`).
  void importLocalFromMetadata(String chatId, Map<String, dynamic>? metadata);

  /// Export local variables to the shape expected by chat metadata.
  /// Returns `null` when nothing is stored, matching host semantics.
  Map<String, dynamic>? exportLocalToMetadata(String chatId);

  // ---------------- Global (app-wide) ----------------

  /// Get a global variable. Returns `''` when absent.
  dynamic getGlobal(String name, {String? index});

  /// Set a global variable. Adapters that persist should schedule a flush.
  void setGlobal(
    String name,
    dynamic value, {
    String? index,
    String? asType,
  });

  bool existsGlobal(String name);

  void deleteGlobal(String name);

  Map<String, dynamic> getAllGlobal();

  void clearGlobal();
}
