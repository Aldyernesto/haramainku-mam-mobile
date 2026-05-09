import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

final _localNotifs = FlutterLocalNotificationsPlugin();

class NotificationProvider extends ChangeNotifier {
  final GraphQLClient _client;
  int _unread = 0;
  List<_NotifItem> _items = [];
  Timer? _timer;
  int _lastSoundAt = 0; // debounce sound (ms timestamp)

  int get unreadCount => _unread;
  List<_NotifItem> get items => _items;
  bool get hasUnread => _unread > 0;

  NotificationProvider(this._client) { _fetch(); _startPolling(); _initSound(); }

  static NotificationProvider of(BuildContext context) {
    return Provider.of<NotificationProvider>(context, listen: false);
  }

  void _initSound() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifs.initialize(const InitializationSettings(android: android, iOS: ios));
    // Request Android 13+ notification permission
    try {
      final android = _localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final prevCount = _unread;
      final res = await _client.query(QueryOptions(
        document: gql(r'''
          query {
            notifications { id type title body data read createdAt }
            unreadNotificationCount
          }
        '''),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (res.hasException) return;
      final raw = res.data?['notifications'] as List? ?? [];
      _items = raw.map((n) => _NotifItem(
        id: n['id'], type: n['type'] ?? '',
        title: n['title'] ?? '', body: n['body'] ?? '',
        data: n['data'] is String ? n['data'] : (n['data'] != null ? n['data'].toString() : null),
        read: n['read'] ?? false,
        createdAt: DateTime.tryParse(n['createdAt'] ?? '') ?? DateTime.now(),
      )).toList();
      _unread = res.data?['unreadNotificationCount'] ?? 0;

      // Play sound when new notifications arrive (debounce 5s for bulk)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_unread > prevCount && (now - _lastSoundAt) > 5000) {
        _lastSoundAt = now;
        final latest = _items.isNotEmpty ? _items.first : null;
        if (latest != null) {
          _localNotifs.show(
            latest.hashCode,
            latest.title,
            latest.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'haramainku_general', 'HaramainKU',
                importance: Importance.high, priority: Priority.high,
                playSound: true, enableVibration: true,
              ),
            ),
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _client.mutate(MutationOptions(
        document: gql(r'''mutation { markNotificationsRead }'''),
      ));
      for (final item in _items) { item.read = true; }
      _unread = 0;
      notifyListeners();
    } catch (e) { debugPrint('[notif] markRead error: $e'); }
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }
}

class _NotifItem {
  final String id, type, title, body;
  final String? data;
  bool read;
  final DateTime createdAt;
  _NotifItem({required this.id, required this.type, required this.title, required this.body, this.data, this.read = false, required this.createdAt});
}
