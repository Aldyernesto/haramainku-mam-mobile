import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

const _getDevices = '''
  query GetLinkedDevices {
    linkedDevices { id deviceName isActive createdAt }
  }
''';

const _disconnectDevice = '''
  mutation DisconnectDevice(\$deviceId: ID!) {
    disconnectDevice(deviceId: \$deviceId)
  }
''';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3), title: const Text('Settings'), leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => Navigator.pop(context))),
      body: Container(color: AppTheme.surface,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 100, 16, 40), children: [
          // Profile
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.gold.withValues(alpha: 0.1)), child: const Icon(Icons.person, size: 28, color: AppTheme.gold)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.email ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3))),
                  child: Text(user?.roleLabel ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.gold))),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          _Section(title: 'Privacy & Security', items: [
            _SettingItem(icon: Icons.devices_outlined, title: 'Linked Devices', trailing: 'Manage', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()))),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Account', items: [
            _SettingItem(icon: Icons.logout, title: 'Logout', danger: true, onTap: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, '/');
            }),
          ]),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceVariant, letterSpacing: 1))),
    Container(decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(16)), child: Column(children: items)),
  ]);
}

class _SettingItem extends StatelessWidget {
  final IconData icon; final String title; final String? trailing; final bool danger; final VoidCallback onTap;
  const _SettingItem({required this.icon, required this.title, this.trailing, this.danger = false, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: danger ? Colors.redAccent : AppTheme.onSurfaceVariant, size: 22),
    title: Text(title, style: TextStyle(fontSize: 15, color: danger ? Colors.redAccent : AppTheme.onSurface)),
    trailing: trailing != null ? Text(trailing!, style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant)) : const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

// Linked Devices Screen
class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});
  @override State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(_getDevices), fetchPolicy: FetchPolicy.networkOnly),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading) return Scaffold(appBar: _bar(), body: const Center(child: CircularProgressIndicator(color: AppTheme.gold)));
        if (result.hasException) return Scaffold(appBar: _bar(), body: Center(child: Text('Error: ${result.exception}', style: const TextStyle(color: Colors.redAccent))));
        final devices = (result.data?['linkedDevices'] as List<dynamic>?) ?? [];
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _bar(),
          body: Container(color: AppTheme.surface,
            child: devices.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.devices, size: 48, color: AppTheme.gold.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('No linked devices', style: TextStyle(fontSize: 16, color: AppTheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Scan QR from Studio Access to link', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
                ]))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 100, 16, 40), itemCount: devices.length, itemBuilder: (_, i) {
                  final d = devices[i];
                  final active = d['isActive'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(14), border: active ? Border.all(color: AppTheme.gold.withValues(alpha: 0.2)) : null),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: active ? AppTheme.gold.withValues(alpha: 0.1) : AppTheme.onSurfaceVariant.withValues(alpha: 0.05)), child: Icon(Icons.phone_android, size: 20, color: active ? AppTheme.gold : AppTheme.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['deviceName'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurface)),
                        const SizedBox(height: 4),
                        Text('Linked on ${_fmtDate(d['createdAt'])}', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                      ])),
                      if (active)
                        TextButton(onPressed: () => _disconnect(context, d['id'], d['deviceName'], refetch),
                          child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                    ]),
                  );
                }),
          ),
        );
      },
    );
  }

  Future<void> _disconnect(BuildContext ctx, String deviceId, String name, VoidCallback? refetch) async {
    final ok = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      title: const Text('Disconnect Device', style: TextStyle(color: AppTheme.onSurface)),
      content: Text('Disconnect "$name"? This device will no longer be linked to your account.', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
      ],
    ));
    if (ok != true) return;
    final client = GraphQLProvider.of(ctx).value;
    await client.mutate(MutationOptions(document: gql(_disconnectDevice), variables: {'deviceId': deviceId}));
    refetch?.call();
  }

  AppBar _bar() => AppBar(backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3), title: const Text('Linked Devices'), leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => Navigator.pop(context)));

  String _fmtDate(String? iso) {
    if (iso == null) return 'Unknown';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
