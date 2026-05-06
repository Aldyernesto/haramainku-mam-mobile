import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

class HaramainKUApp extends StatefulWidget {
  final GraphQLClient client;
  final FlutterSecureStorage secureStorage;

  const HaramainKUApp({
    super.key,
    required this.client,
    required this.secureStorage,
  });

  @override State<HaramainKUApp> createState() => _HaramainKUAppState();
}

class _HaramainKUAppState extends State<HaramainKUApp> {
  bool _checking = true;
  bool _showOnboarding = false;

  @override void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final show = await OnboardingScreen.shouldShow();
    if (mounted) setState(() { _showOnboarding = show; _checking = false; });
  }

  @override Widget build(BuildContext context) {
    if (_checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(backgroundColor: Color(0xFF141310), body: Center(child: CircularProgressIndicator(color: Color(0xFFefe749)))),
      );
    }
    return GraphQLProvider(
      client: ValueNotifier(widget.client),
      child: ChangeNotifierProvider(
        create: (_) => AuthProvider(widget.client, widget.secureStorage),
        child: MaterialApp(
          title: 'HaramainKU MAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          initialRoute: _showOnboarding ? '/onboarding' : '/',
          routes: {
            '/onboarding': (_) => const OnboardingScreen(),
            '/': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/home': (_) => const HomeScreen(),
          },
        ),
      ),
    );
  }
}
