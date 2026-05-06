import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    return !seen;
  }

  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  void _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(children: [
        PageView(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            // Page 1: Welcome
            _OnboardPage(
              image: 'assets/welcome.png',
              title: 'HaramainKU\nMedia Manager',
              subtitle: 'Cinematic Asset Intelligence\nfor Hajj & Umrah Production Team',
              isAsset: true,
            ),
            // Page 2: Features
            _OnboardPage(
              icon: Icons.upload_file,
              title: 'Upload & Manage',
              subtitle: 'Chunked upload 10MB, unlimited nested folders,\npowerful search, and real-time collaboration',
              isAsset: false,
            ),
            // Page 3: Connect
            _OnboardPage(
              icon: Icons.qr_code_scanner,
              title: 'QR Connect',
              subtitle: 'Scan QR from WebApp Studio Access\nto link your device instantly.\nOne account, all devices synced.',
              isAsset: false,
              showButton: true,
              onDone: _done,
            ),
          ],
        ),
        // Dots
        Positioned(bottom: 120, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _page == i ? 24 : 8, height: 8,
          decoration: BoxDecoration(color: _page == i ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
        )))),
        // Skip
        if (_page < 2) Positioned(top: 60, right: 20, child: TextButton(onPressed: () => _ctrl.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), child: const Text('Skip', style: TextStyle(color: Color(0xFFefe749), fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String? image;
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool isAsset;
  final bool showButton;
  final VoidCallback? onDone;

  const _OnboardPage({
    this.image, this.icon,
    required this.title, required this.subtitle,
    this.isAsset = false, this.showButton = false, this.onDone,
  });

  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isAsset && image != null)
        Image.asset(image!, height: 280)
      else if (image != null)
        Image.asset(image!, height: 280)
      else
        Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.gold.withValues(alpha: 0.08), border: Border.all(color: AppTheme.gold.withValues(alpha: 0.15))), child: Icon(icon, size: 64, color: AppTheme.gold)),
      const SizedBox(height: 48),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFefe749), height: 1.2)),
      const SizedBox(height: 20),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFFa0a0a0), height: 1.5)),
      if (showButton) ...[
        const SizedBox(height: 48),
        SizedBox(width: 220, child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFefe749), foregroundColor: const Color(0xFF141310), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          child: const Text('Get Started'),
        )),
      ],
    ]));
  }
}
