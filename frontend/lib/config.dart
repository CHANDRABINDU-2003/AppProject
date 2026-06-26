/// App-wide configuration.
class AppConfig {
  /// Base URL of the FastAPI core backend.
  ///
  /// - Android emulator: use http://10.0.2.2:8000  (host machine alias)
  /// - iOS simulator / web / desktop: use http://localhost:8000
  /// - Real device: use your computer's LAN IP, e.g. http://192.168.0.10:8000
  static const String apiBaseUrl = "http://localhost:8000";
}
