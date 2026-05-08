import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';

class NotificationProvider extends ChangeNotifier {
  final GraphQLClient _client;
  int _unread = 0;
  List<_NotifItem> _items = [];
  Timer? _timer;

  int get unreadCount => _unread;
  List<_NotifItem> get items => _items;
  bool get hasUnread => _unread > 0;

  NotificationProvider(this._client) { _fetch(); _startPolling(); }

  static NotificationProvider of(BuildContext context) {
    return Provider.of<NotificationProvider>(context, listen: false);
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final res = await _client.query(QueryOptions(
        document: gql(r'''
          query {
            notifications { id type title body data read createdAt }
            unreadNotificationCount
          }
        '''),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (res.hasException) { debugPrint('[notif] ${res.exception}'); return; }
      final raw = res.data?['notifications'] as List? ?? [];
      _items = raw.map((n) => _NotifItem(
        id: n['id'], type: n['type'] ?? '',
        title: n['title'] ?? '', body: n['body'] ?? '',
        data: n['data'] is String ? n['data'] : (n['data'] != null ? n['data'].toString() : null),
        read: n['read'] ?? false,
        createdAt: DateTime.tryParse(n['createdAt'] ?? '') ?? DateTime.now(),
      )).toList();
      _unread = res.data?['unreadNotificationCount'] ?? 0;
      notifyListeners();
    } catch (e) { debugPrint('[notif] fetch error: $e'); }
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
