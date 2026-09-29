/// Persists the preview selection so it outlives the widget that made it.
///
/// Implement this over whatever storage your app already uses, such as
/// `SharedPreferences`, and pass it to [DeviceLab.storage]. Reads and writes
/// are synchronous, so load your backing store before calling `runApp`.
abstract class DeviceLabStorage {
  /// Allows subclasses to be const.
  const DeviceLabStorage();

  /// The stored value for [key], or null when nothing was stored.
  String? read(String key);

  /// Stores [value] under [key].
  void write(String key, String value);
}

/// A [DeviceLabStorage] that remembers the selection for the lifetime of the
/// process.
///
/// This survives the preview being hidden, and the widget tree being rebuilt
/// or recreated, but not a full restart. Use it when you want the selection
/// to stick without wiring up real storage.
class SessionDeviceLabStorage extends DeviceLabStorage {
  /// Creates a session-scoped store. All instances share the same values.
  const SessionDeviceLabStorage();

  static final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  /// Forgets everything stored so far.
  static void clear() => _values.clear();
}
