import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/user.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveUser(User user) async {
    final userJson = jsonEncode({
      'id': user.id,
      'email': user.email,
      'role': user.role,
      'kyber_public_key': user.kyberPublicKey,
      'created_at': user.createdAt.toIso8601String(),
    });
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<User?> getCurrentUser() async {
    final userStr = await _storage.read(key: _userKey);
    if (userStr == null) return null;
    try {
      final json = jsonDecode(userStr);
      return User.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    // A more thorough check would decode the JWT and check expiration
    return token != null;
  }
}
