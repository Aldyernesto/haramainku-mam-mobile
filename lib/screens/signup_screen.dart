import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  String _role = 'EDITOR';
  String? _error;
  bool _loading = false;

  Future<void> _signup() async {
    if (_pass.text.length < 8) { setState(() => _error = 'Password min 8 characters'); return; }
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final err = await auth.signup(_name.text.trim(), _email.text.trim(), _pass.text, _role);
    if (err != null) { setState(() { _error = err; _loading = false; }); return; }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3), title: const Text('MEDIA'), leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => Navigator.pop(context))),
    body: Container(color: AppTheme.surface, child: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 80),
        Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
        const SizedBox(height: 8),
        Text('Join the cinematic intelligence platform.', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        TextField(controller: _name, style: const TextStyle(color: AppTheme.onSurface), decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, color: AppTheme.onSurfaceVariant))),
        const SizedBox(height: 16),
        TextField(controller: _email, style: const TextStyle(color: AppTheme.onSurface), decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: AppTheme.onSurfaceVariant)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        TextField(controller: _pass, style: const TextStyle(color: AppTheme.onSurface), obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 8)', prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.onSurfaceVariant))),
        const SizedBox(height: 24),
        Text('I am a:', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _RoleCard(label: 'Editor', sub: 'Download & share', icon: Icons.download, selected: _role == 'EDITOR', onTap: () => setState(() => _role = 'EDITOR'))),
          const SizedBox(width: 12),
          Expanded(child: _RoleCard(label: 'Field Crew', sub: 'Upload & share', icon: Icons.upload, selected: _role == 'FIELD_CREW', onTap: () => setState(() => _role = 'FIELD_CREW'))),
        ]),
        const SizedBox(height: 20),
        if (_error != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: const TextStyle(color: AppTheme.gold, fontSize: 13))),
        ElevatedButton(onPressed: _loading ? null : _signup, child: Text(_loading ? 'Creating...' : 'Sign Up')),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Sign In')),
      ]),
    ))),
  );
}

class _RoleCard extends StatelessWidget {
  final String label, sub; final IconData icon; final bool selected; final VoidCallback onTap;
  const _RoleCard({required this.label, required this.sub, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: selected ? AppTheme.gold.withValues(alpha: 0.08) : AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppTheme.gold : Colors.white.withValues(alpha: 0.06))),
      child: Column(children: [
        Icon(icon, color: selected ? AppTheme.gold : AppTheme.onSurfaceVariant, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? AppTheme.gold : AppTheme.onSurface)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
    ),
  );
}
