import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

const _pairDevice = '''mutation PairDevice(\$qrToken: String!, \$deviceName: String!) {
  pairDevice(qrToken: \$qrToken, deviceName: \$deviceName) {
    device { id deviceName isActive }
  }
}''';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _camCtrl = MobileScannerController();
  String? _status;
  bool _loading = false;
  bool _paired = false;
  late AnimationController _pulse;

  @override void initState() { super.initState(); _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); }
  @override void dispose() { _camCtrl.dispose(); _pulse.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture, GraphQLClient client) {
    if (_paired || _loading) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    // Parse QR URL: haramainku-mam://pair?token=XXX
    final uri = Uri.tryParse(code);
    final qrToken = uri?.queryParameters['token'];
    if (qrToken == null) return;

    _pair(qrToken, client);
  }

  Future<void> _pair(String qrToken, GraphQLClient client) async {
    setState(() { _loading = true; _status = 'Connecting...'; });
    try {
      final result = await client.mutate(MutationOptions(
        document: gql(_pairDevice),
        variables: {'qrToken': qrToken, 'deviceName': 'HaramainKU Mobile'},
      ));
      if (result.hasException) {
        setState(() { _status = 'Failed: ${result.exception}'; _loading = false; });
        return;
      }
      if (mounted) {
        setState(() { _status = 'Device Linked!'; _loading = false; _paired = true; });
        Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context, true); });
      }
    } catch (e) {
      if (mounted) setState(() { _status = 'Failed: $e'; _loading = false; });
    }
  }

  void _showManualEntry(BuildContext context, GraphQLClient client) {
    final ctrl = TextEditingController();
    String? _err;
    bool _busy = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      title: Text(_busy ? 'Connecting...' : 'Enter QR Token', style: const TextStyle(color: AppTheme.onSurface)),
      content: _busy
        ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
        : TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppTheme.onSurface), decoration: InputDecoration(hintText: 'Paste QR token here', hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant), errorText: _err)),
      actions: _busy ? null : [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant))),
        TextButton(onPressed: () async {
          final t = ctrl.text.trim();
          if (t.isEmpty) return;
          setDlg(() => _busy = true);
          try {
            final result = await client.mutate(MutationOptions(
              document: gql(_pairDevice),
              variables: {'qrToken': t, 'deviceName': 'HaramainKU Mobile'},
            ));
            if (result.hasException) {
              final ex = result.exception!;
              final msgs = ex.graphqlErrors.map((e) => e.message).join(', ');
              setDlg(() { _busy = false; _err = msgs.isNotEmpty ? msgs : ex.toString(); });
            } else {
              Navigator.pop(ctx);
              if (mounted) {
                setState(() { _loading = true; _status = 'Device Linked!'; _paired = true; });
                Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context, true); });
              }
            }
          } catch (e) {
            setDlg(() { _busy = false; _err = e.toString(); });
          }
        }, child: const Text('Connect', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700))),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(fit: StackFit.expand, children: [
        // Camera scanner
        MobileScanner(controller: _camCtrl, onDetect: (capture) => _onDetect(capture, client)),
        // Pulsing frame overlay
        Center(child: IgnorePointer(child: AnimatedBuilder(animation: _pulse, builder: (_, child) => Container(
          width: 220, height: 220,
          decoration: BoxDecoration(border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4 + _pulse.value * 0.3), width: 3), borderRadius: BorderRadius.circular(20)),
        )))),
        // Hint text
        const Positioned(bottom: 100, left: 0, right: 0, child: Center(child: Text('Point camera at QR code\non Studio Access screen', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 15)))),
        // Loading overlay
        if (_loading) Container(color: Colors.black87, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 3)),
          const SizedBox(height: 32),
          const Icon(Icons.link, size: 48, color: AppTheme.gold),
          const SizedBox(height: 20),
          Text(_status ?? 'Connecting...', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.gold)),
          const SizedBox(height: 8),
          const Text('Linking to HaramainKU Studio', style: TextStyle(fontSize: 14, color: Colors.white54)),
        ]))),
        // Bottom status
        if (_paired) Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)), child: const Text('Device Linked!', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600, fontSize: 16))))),
      ]),
    );
  }
}
