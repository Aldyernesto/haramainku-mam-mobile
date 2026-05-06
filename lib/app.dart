import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class HaramainKUApp extends StatelessWidget {
  final GraphQLClient client;
  final FlutterSecureStorage secureStorage;

  const HaramainKUApp({
    super.key,
    required this.client,
    required this.secureStorage,
  });

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: ValueNotifier(client),
      child: ChangeNotifierProvider(
        create: (_) => AuthProvider(client, secureStorage),
        child: MaterialApp(
          title: 'HaramainKU MAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          initialRoute: '/',
          routes: {
            '/': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/home': (_) => const HomeScreen(),
          },
        ),
      ),
    );
  }
}
