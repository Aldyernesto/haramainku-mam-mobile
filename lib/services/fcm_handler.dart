import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

final _localNotifs = FlutterLocalNotificationsPlugin();

Future<void> initFCM(GraphQLClient client) async {
  try {
    await _localNotifs.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    print('[FCM] local notifs initialized');
    await Firebase.initializeApp();
    print('[FCM] firebase initialized');
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, badge: true, sound: true);
    print('[FCM] permission granted');

    final token = await fcm.getToken();
    print('[FCM] token: $token');
    if (token != null) {
      final res = await client.mutate(MutationOptions(
        document: gql(r'mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'),
        variables: {'token': token},
      ));
      print('[FCM] registered: ${!res.hasException}');
    }

    fcm.onTokenRefresh.listen((t) {
      print('[FCM] token refreshed: $t');
      client.mutate(MutationOptions(
        document: gql(r'mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'),
        variables: {'token': t},
      )).catchError((e) => print('[FCM] refresh error: $e'));
    });

    FirebaseMessaging.onMessage.listen((msg) {
      _localNotifs.show(
        msg.hashCode,
        msg.notification?.title ?? 'Notification',
        msg.notification?.body ?? '',
        const NotificationDetails(android: AndroidNotificationDetails(
          'haramainku_push', 'HaramainKU Push',
          importance: Importance.max, priority: Priority.high,
          playSound: true, enableVibration: true,
        )),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      print('[FCM] message opened: ${msg.data}');
    });
  } catch (e) {
    print('[FCM] init error: $e');
  }
}
