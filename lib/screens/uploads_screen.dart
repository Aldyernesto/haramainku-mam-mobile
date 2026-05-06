import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';

class UploadsScreen extends StatefulWidget {
  const UploadsScreen({super.key});
  @override State<UploadsScreen> createState() => _UploadsScreenState();
}

class _UploadsScreenState extends State<UploadsScreen> {
  final List<_Task> _tasks = [];

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r == null || r.files.isEmpty) return;
    setState(() { for (final f in r.files) _tasks.add(_Task(name: f.name, size: f.size, progress: 0)); });
    // TODO: Wire GraphQL initiateUpload + REST chunk upload + completeUpload
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3), title: const Text('Uploads'), leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => Navigator.pop(context))),
    body: Container(color: AppTheme.surface,
      child: _tasks.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_upload_outlined, size: 64, color: AppTheme.gold.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No active uploads', style: TextStyle(fontSize: 16, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('Tap + to select files', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
            ]))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 100, 16, 100), itemCount: _tasks.length, itemBuilder: (_, i) {
              final t = _tasks[i];
              return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(t.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${t.progress}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gold)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: t.progress / 100, backgroundColor: Colors.white.withValues(alpha: 0.05), valueColor: const AlwaysStoppedAnimation(AppTheme.gold), minHeight: 4)),
                  const SizedBox(height: 4),
                  Text(_fmt(t.size), style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                ]),
              );
            }),
    ),
    floatingActionButton: FloatingActionButton(onPressed: _pick, backgroundColor: AppTheme.gold, child: const Icon(Icons.add, color: Color(0xFF1e1c00))),
  );

  String _fmt(int b) {
    if (b < 1048576) return '${(b/1024).toStringAsFixed(0)} KB';
    if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB';
    return '${(b/1073741824).toStringAsFixed(1)} GB';
  }
}

class _Task {
  final String name; final int size; int progress;
  _Task({required this.name, required this.size, required this.progress});
}
