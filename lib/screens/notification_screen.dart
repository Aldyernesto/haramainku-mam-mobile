import 'package:flutter/material.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  final NotificationProvider notif;
  const NotificationScreen({super.key, required this.notif});

  @override State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override void initState() {
    super.initState();
    widget.notif.addListener(_refresh);
    widget.notif.markAllRead();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override void dispose() { widget.notif.removeListener(_refresh); super.dispose(); }

  IconData _iconFor(String type) {
    switch (type) {
      case 'upload_complete': return Icons.cloud_done_rounded;
      case 'chat_mention': return Icons.alternate_email_rounded;
      case 'file_shared': return Icons.share_rounded;
      case 'project_created': return Icons.create_new_folder_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'upload_complete': return const Color(0xFF4CAF50);
      case 'chat_mention': return const Color(0xFF2196F3);
      case 'file_shared': return const Color(0xFFFF9800);
      case 'project_created': return AppTheme.gold;
      default: return AppTheme.onSurfaceVariant;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.notif.items;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.onSurfaceVariant, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: items.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none_rounded, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            const Text('No notifications yet', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 15)),
          ]))
        : RefreshIndicator(
            color: AppTheme.gold,
            onRefresh: () => widget.notif.markAllRead().then((_) => widget.notif.markAllRead()),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final n = items[i];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: n.read ? AppTheme.surfaceContainer : AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: !n.read ? Border(left: BorderSide(color: _colorFor(n.type), width: 3)) : null,
                  ),
                  child: Dismissible(
                    key: Key(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.check_rounded, color: AppTheme.gold),
                    ),
                    onDismissed: (_) {},
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(n.title), backgroundColor: AppTheme.surfaceContainerHigh, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _colorFor(n.type).withValues(alpha: 0.12)),
                            child: Icon(_iconFor(n.type), color: _colorFor(n.type), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: n.read ? FontWeight.w400 : FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(n.body, style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(_timeAgo(n.createdAt), style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11)),
                            ]),
                          ),
                          if (!n.read)
                            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: _colorFor(n.type))),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}
