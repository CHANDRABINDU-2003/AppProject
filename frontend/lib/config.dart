/// App-wide configuration.
class AppConfig {
  /// Base URL of the FastAPI core backend.
  ///
  /// Defaults to the public backend on Render, so any web/mobile build works
  /// for everyone out of the box. Override it for local development with:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
  ///
  /// Local-dev host cheatsheet (when overriding):
  /// - Android emulator:           http://10.0.2.2:8000  (host machine alias)
  /// - iOS simulator / web / desktop: http://localhost:8000
  /// - Real device on your LAN:    http://192.168.0.10:8000
  ///
  /// Note: free Render web services cold-start (~50s) after ~15 min idle.
  static const String apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "https://agripulse-backend-zqs2.onrender.com",
  );
}
