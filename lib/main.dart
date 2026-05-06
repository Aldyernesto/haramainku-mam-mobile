import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'config/graphql_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = FlutterSecureStorage();

  final client = await initGraphQLClient(secureStorage);

  runApp(HaramainKUApp(client: client, secureStorage: secureStorage));
}
