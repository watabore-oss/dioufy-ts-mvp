import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer les notifications push & SMS.
///
/// Le token FCM est enregistré dans la table `app_users.fcm_token`.
class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  /// initialise FCM et envoie le token au backend.
  static Future<void> init() async {
    NotificationSettings settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    }
    // écouter les messages en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received FCM message: ${message.messageId}');
      // TODO: afficher snackbar ou local notification
    });
  }

  static Future<void> _sendTokenToServer(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('app_users')
        .update({'fcm_token': token}).eq('id', user.id);
  }

  /// envoie une notification push via l'API tierce (Edge Function).
  static Future<void> sendPush(
      {required String userId,
      required String title,
      required String body}) async {
    await _supabase.functions.invoke('send-notification', body: {
      'user_id': userId,
      'title': title,
      'body': body,
    });
  }
}
