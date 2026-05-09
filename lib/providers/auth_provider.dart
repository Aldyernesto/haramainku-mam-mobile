import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/user.dart';
import '../config/graphql_config.dart';

class AuthProvider extends ChangeNotifier {
  final GraphQLClient _client;
  final FlutterSecureStorage _storage;

  User? _user;
  bool _isLoading = true;

  AuthProvider(this._client, this._storage) {
    _loadUser();
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  Future<String?> get token => _readToken();

  Future<String?> _readToken() async {
    // Try secure storage first
    final t = await _storage.read(key: 'auth_token');
    if (t != null && t.isNotEmpty) return t;
    // Fallback to SharedPreferences (some devices lose KeyStore keys)
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token_fallback');
    } catch (_) { return null; }
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token_fallback', token);
    } catch (_) {}
    clearAuthCache(); // re-warm cache with new token
  }

  Future<void> _loadUser() async {
    final token = await _readToken();
    if (token != null) {
      await _fetchMe();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchMe() async {
    const query = '''query Me { me { id name email role active } }''';
    // Retry up to 3 times for network flakiness on app start
    for (int i = 0; i < 3; i++) {
      try {
        final result = await _client.query(QueryOptions(
          document: gql(query),
          fetchPolicy: FetchPolicy.networkOnly,
        ));
        if (result.data?['me'] != null) {
          _user = User.fromJson(result.data!['me']);
          break; // success
        }
      } catch (_) {
        if (i < 2) await Future.delayed(const Duration(seconds: 2));
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Called after QR pairing stores a new token
  Future<bool> refreshFromToken() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    const query = '''query Me { me { id name email role active } }''';
    try {
      final result = await _client.query(QueryOptions(document: gql(query)));
      if (result.data?['me'] != null) {
        _user = User.fromJson(result.data!['me']);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> googleLogin(String token) async {
    await _saveToken(token);
    await _fetchMe();
  }

  Future<String?> login(String email, String password) async {
    const mutation = '''
      mutation Login(\$email: String!, \$password: String!) {
        login(email: \$email, password: \$password) {
          success
          message
          token
          user { id name email role active }
        }
      }
    ''';

    final result = await _client.mutate(MutationOptions(
      document: gql(mutation),
      variables: {'email': email, 'password': password},
    ));

    if (result.hasException) return result.exception.toString();

    final data = result.data?['login'];
    if (data == null || data['success'] != true) {
      return data?['message'] ?? 'Login failed';
    }

    _user = User.fromJson(data['user']);
    await _saveToken(data['token']);
    notifyListeners();
    return null;
  }

  Future<String?> signup(String name, String email, String password, String role) async {
    const mutation = '''
      mutation Signup(\$input: CreateUserInput!) {
        register(input: \$input) {
          success
          message
          token
          user { id name email role active }
        }
      }
    ''';

    final result = await _client.mutate(MutationOptions(
      document: gql(mutation),
      variables: {
        'input': {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        },
      },
    ));

    if (result.hasException) return result.exception.toString();

    final data = result.data?['register'];
    if (data == null || data['success'] != true) {
      return data?['message'] ?? 'Signup failed';
    }

    _user = User.fromJson(data['user']);
    await _saveToken(data['token']);
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'auth_token');
    try { (await SharedPreferences.getInstance()).remove('auth_token_fallback'); } catch (_) {}
    clearAuthCache();
    notifyListeners();
  }
}
