// services/auth_service.dart
import 'dart:convert';
import 'package:contact_list/services/db.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _rememberedUserIdKey = 'remembered_user_id';
  static const String _rememberedUsernameKey = 'remembered_username';

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final dbHelper = DbHelper();
    final user = await dbHelper.getUserByUsername(username);
    final hashedInput = _hashPassword(password);

    if (user?.id != null && user!.passwordHash == hashedInput) {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setInt(_rememberedUserIdKey, user.id!);
        await prefs.setString(_rememberedUsernameKey, username);
      } else {
        await prefs.remove(_rememberedUserIdKey);
        await prefs.remove(_rememberedUsernameKey);
      }
      return {'success': true, 'userId': user.id};
    }
    return {'success': false, 'userId': null};
  }

  Future<int?> getRememberedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_rememberedUserIdKey);
  }

  Future<String?> getRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedUsernameKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUserIdKey);
    await prefs.remove(_rememberedUsernameKey);
  }

  // Register a new user with optional photo
  Future<bool> register(String username, String password, {String? photoPath}) async {
    final hashed = _hashPassword(password);
    final user = User(
      username: username, 
      passwordHash: hashed,
      photoPath: photoPath,
    );
    final dbHelper = DbHelper();

    try {
      final userId = await dbHelper.insertUser(user);
      return userId > 0;
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }
}
