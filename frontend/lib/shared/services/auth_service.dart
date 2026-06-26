import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/models/user.dart';

/// Handles register / login / logout and remembers the current user.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _api = ApiService.instance;
  AppUser? currentUser;

  /// Returns the logged-in user, or null. Used on app start to skip login.
  Future<AppUser?> tryAutoLogin() async {
    await _api.loadToken();
    if (!_api.isLoggedIn) return null;
    try {
      final me = await _api.get("/auth/me");
      currentUser = AppUser.fromJson(me);
      return currentUser;
    } catch (_) {
      await _api.setToken(null); // token expired/invalid
      return null;
    }
  }

  Future<AppUser> login(String email, String password) async {
    final res = await _api.postForm("/auth/login", {
      "username": email, // backend treats username as email
      "password": password,
    });
    await _api.setToken(res["access_token"]);
    currentUser = AppUser.fromJson(res["user"]);
    return currentUser!;
  }

  /// Creates the account but does NOT log in — the user is sent back to the
  /// login screen to sign in explicitly afterwards.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    int? regionId,
  }) async {
    await _api.post("/auth/register", {
      "name": name,
      "email": email,
      "password": password,
      "role": role,
      "region_id": regionId,
    });
  }

  Future<void> logout() async {
    await _api.setToken(null);
    currentUser = null;
  }
}
