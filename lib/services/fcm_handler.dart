import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

final _localNotifs = FlutterLocalNotificationsPlugin();

Future<void> initFCM(GraphQLClient client) async {
  try {
    await Firebase.initializeApp();
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await fcm.getToken();
    if (token != null) {
      client.mutate(MutationOptions(
        document: gql(r'''mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'''),
        variables: {'token': token},
      )).catchError((_) {});
    }

    fcm.onTokenRefresh.listen((t) {
      client.mutate(MutationOptions(
        document: gql(r'''mutation RegisterFcmToken($token: String!) { registerFcmToken(token: $token) }'''),
        variables: {'token': t},
      )).catchError((_) {});
    });

    await _localNotifs.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));

    FirebaseMessaging.onMessage.listen((msg) {
      _localNotifs.show(msg.hashCode, msg.notification?.title ?? '', msg.notification?.body ?? '',
        const NotificationDetails(android: AndroidNotificationDetails('haramainku', 'HaramainKU', importance: Importance.high, priority: Priority.high)));
    });
  } catch (_) {}
}
