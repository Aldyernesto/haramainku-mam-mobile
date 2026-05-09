import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const graphqlEndpoint = 'https://mam.haramaintour.com/api/graphql';

String? _cachedToken;
SharedPreferences? _cachedPrefs;
FlutterSecureStorage? _cachedStorage;

Future<String?> _readToken() async {
  if (_cachedToken != null && _cachedToken!.isNotEmpty) {
    print('[TOKEN] cache hit');
    return _cachedToken;
  }
  print('[TOKEN] cache miss, reading storage...');

  final s = _cachedStorage ?? FlutterSecureStorage();
  _cachedStorage = s;
  final t = await s.read(key: 'auth_token');
  print('[TOKEN] secure storage: ${t != null ? "found (${t.length} chars)" : "NOT FOUND"}');

  if (t != null && t.isNotEmpty) {
    _cachedToken = t;
    return t;
  }

  try {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    final fallback = _cachedPrefs?.getString('auth_token_fallback');
    print('[TOKEN] shared prefs: ${fallback != null ? "found (${fallback.length} chars)" : "NOT FOUND"}');
    if (fallback != null && fallback.isNotEmpty) {
      _cachedToken = fallback;
      s.write(key: 'auth_token', value: fallback);
      return fallback;
    }
  } catch (e) { print('[TOKEN] shared prefs error: $e'); }
  print('[TOKEN] no token found anywhere');
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
