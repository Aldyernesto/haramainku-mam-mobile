import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'config/graphql_config.dart';
import 'services/fcm_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = FlutterSecureStorage();

  try {
    final client = await initGraphQLClient(secureStorage);
    runApp(HaramainKUApp(client: client, secureStorage: secureStorage));
  } catch (e, st) {
    runApp(_ErrorApp(error: e, stack: st));
  }
}

class _ErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  const _ErrorApp({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF141310),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFefe749), size: 48),
                const SizedBox(height: 16),
                const Text('Startup Error', style: TextStyle(color: Color(0xFFefe749), fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$error', style: const TextStyle(color: Color(0xFFa0a0a0), fontSize: 13), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
