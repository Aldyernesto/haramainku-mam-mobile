import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const graphqlEndpoint = 'https://mam.haramaintour.com/api/graphql';

Future<String?> _readToken(FlutterSecureStorage storage) async {
  final t = await storage.read(key: 'auth_token');
  if (t != null && t.isNotEmpty) return t;
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token_fallback');
  } catch (_) { return null; }
}

Future<GraphQLClient> initGraphQLClient(FlutterSecureStorage storage) async {
  final authLink = AuthLink(
    getToken: () async {
      final token = await _readToken(storage);
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
