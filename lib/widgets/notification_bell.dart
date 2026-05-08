import 'package:flutter/material.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_screen.dart';
import '../theme/app_theme.dart';

class NotificationBell extends StatelessWidget {
  final NotificationProvider? notif;
  const NotificationBell({super.key, this.notif});

  @override
  Widget build(BuildContext context) {
    final n = notif ?? NotificationProvider.of(context);
    if (n == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: n,
      builder: (context, _) {
        final unread = n.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                color: unread > 0 ? AppTheme.gold : AppTheme.onSurfaceVariant,
                size: 24,
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen(notif: n)));
              },
            ),
            if (unread > 0)
              Positioned(
                right: 6, top: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
                  child: Text(
                    unread > 99 ? '99+' : unread.toString(),
                    style: const TextStyle(color: Color(0xFF141310), fontSize: 10, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
