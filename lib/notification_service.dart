import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';

abstract class NotificationService {
  /// init
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final fcm = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM: $fcm');
      await Clipboard.setData(ClipboardData(text: fcm.toString()));
    } on Exception {
      debugPrint('FAILED TO GET FCM');
    }

    /// request permission
    final isDenied = await Permission.notification.isDenied;
    if (isDenied) {
      await Permission.notification.request();
    }

    /// handle notifications
    await handleNotifications();
  }

  static bool isFlutterLocalNotificationsInitialized = false;

  static late FlutterLocalNotificationsPlugin localNotificationsPlugin;
  static const channel = AndroidNotificationChannel(
    'General', // id
    'General', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  ///
  static Future<void> handleNotifications() async {
    if (isFlutterLocalNotificationsInitialized) {
      return;
    }

    localNotificationsPlugin = FlutterLocalNotificationsPlugin();

    /// Create an Android Notification Channel.
    ///
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    isFlutterLocalNotificationsInitialized = true;
    if (Platform.isAndroid) {
      await localNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        ),
        onDidReceiveNotificationResponse: (message) {
          debugPrint(
              "onDidReceiveNotificationResponse Data: ${message.payload}");
        },
      );
    }

    /// foreground
    FirebaseMessaging.onMessage.listen(
      (message) {
        debugPrint('Notification: foreground received $message');
        showLocalNotification(message);
      },
    );

    /// background/terminated
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundNotification);
  }

  static showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null && !kIsWeb) {
      await localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  debugPrint('Notification: background/terminated received $message');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
