import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const graphqlEndpoint = 'https://mam.haramaintour.com/api/graphql';

String? _cachedToken;
SharedPreferences? _cachedPrefs;
FlutterSecureStorage? _cachedStorage;

Future<String?> _readToken() async {
  if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;

  // Try secure storage
  final s = _cachedStorage ?? FlutterSecureStorage();
  _cachedStorage = s;
  final t = await s.read(key: 'auth_token');
  if (t != null && t.isNotEmpty) {
    _cachedToken = t;
    return t;
  }

  // Fallback to SharedPreferences
  try {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    final fallback = _cachedPrefs?.getString('auth_token_fallback');
    if (fallback != null && fallback.isNotEmpty) {
      _cachedToken = fallback;
      // Also restore to secure storage for next time
      s.write(key: 'auth_token', value: fallback);
      return fallback;
    }
  } catch (_) {}
  return null;
}

void clearAuthCache() {
  _cachedToken = null;
}

Future<GraphQLClient> initGraphQLClient(FlutterSecureStorage storage) async {
  _cachedStorage = storage;
  // Pre-warm token cache
  await _readToken();

  final authLink = AuthLink(
    getToken: () async {
      final token = await _readToken();
      return token != null ? 'Bearer $token' : null;
    },
  );

  final httpLink = HttpLink(graphqlEndpoint);

  return GraphQLClient(
    cache: GraphQLCache(),
    link: authLink.concat(httpLink),
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.networkOnly),
    ),
  );
}
