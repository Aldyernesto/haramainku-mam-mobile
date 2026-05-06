import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const graphqlEndpoint = 'https://mam.haramaintour.com/api/graphql';

Future<GraphQLClient> initGraphQLClient(FlutterSecureStorage storage) async {
  final authLink = AuthLink(
    getToken: () async {
      final token = await storage.read(key: 'auth_token');
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
