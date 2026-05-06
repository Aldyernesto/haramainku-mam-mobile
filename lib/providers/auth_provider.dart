import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/user.dart';

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

  Future<void> _loadUser() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      await _fetchMe();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchMe() async {
    const query = '''query Me { me { id name email role active } }''';
    try {
      final result = await _client.query(QueryOptions(document: gql(query)));
      if (result.data?['me'] != null) {
        _user = User.fromJson(result.data!['me']);
      }
    } catch (_) {}
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
    await _storage.write(key: 'auth_token', value: data['token']);
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
    await _storage.write(key: 'auth_token', value: data['token']);
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
}
