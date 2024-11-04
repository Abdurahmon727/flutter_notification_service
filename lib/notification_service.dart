import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    handleNotifications();
  }

  ///
  static Future<void> handleNotifications() async {
    /// foreground
    FirebaseMessaging.onMessage.listen(
      (message) {
        debugPrint('Notification: foreground received $message');
      },
    );

    /// background/terminated
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundNotification);
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
