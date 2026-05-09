import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/fcm_handler.dart';
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
  String? _initialRoute;

  @override void initState() {
    super.initState();
    _check();
    initFCM(widget.client);
  }

  Future<void> _check() async {
    final show = await OnboardingScreen.shouldShow();
    // Quick auth check: token exists → go home, else login
    final token = await widget.secureStorage.read(key: 'auth_token');
    // Also check SharedPreferences fallback
    String? fallbackToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      fallbackToken = prefs.getString('auth_token_fallback');
    } catch (_) {}
    final hasToken = (token != null && token.isNotEmpty) || (fallbackToken != null && fallbackToken.isNotEmpty);

    String route;
    if (show) {
      route = '/onboarding';
    } else if (hasToken) {
      route = '/home';
    } else {
      route = '/';
    }
    if (mounted) setState(() { _showOnboarding = show; _initialRoute = route; _checking = false; });
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
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(widget.client, widget.secureStorage)),
          ChangeNotifierProvider(create: (_) => NotificationProvider(widget.client)),
        ],
        child: MaterialApp(
          title: 'HaramainKU MAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          initialRoute: _initialRoute ?? '/',
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
