import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

final _localNotifs = FlutterLocalNotificationsPlugin();

Future<void> initFCM(GraphQLClient client) async {
  // Android channel for foreground notifications
  await _localNotifs.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  try {
    await Firebase.initializeApp();
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await fcm.getToken();
    debugPrint('[FCM] Token: $token');
    if (token != null) {
      final res = await client.mutate(MutationOptions(
        document: gql(r'mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'),
        variables: {'token': token},
      ));
      debugPrint('[FCM] Registered: ${!res.hasException}');
    }

    fcm.onTokenRefresh.listen((t) {
      debugPrint('[FCM] Token refreshed: $t');
      client.mutate(MutationOptions(
        document: gql(r'mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'),
        variables: {'token': t},
      )).catchError((e) => debugPrint('[FCM] refresh error: $e'));
    });

    // Foreground messages → local notification with sound
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

    // Background tap → open app
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM] Message opened: ${msg.data}');
    });
  } catch (e) {
    debugPrint('[FCM] Init error: $e');
  }
}
