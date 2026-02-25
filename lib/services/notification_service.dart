import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background handler — must NOT be inside a class
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [BG] Notification received: ${message.notification?.title}');
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._(); // Private constructor — use static methods only

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel — matches AndroidManifest meta-data value
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'split_expenses_high',
    'Split Expenses Notifications',
    description: 'Alerts for new expenses, added members, and payments.',
    importance: Importance.high,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    // Register background handler first (FCM requirement)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️  Notification permission denied by user.');
      return;
    }

    await _setupLocalNotifications();
    await saveTokenToFirestore();

    _messaging.onTokenRefresh.listen((_) async {
      debugPrint('🔄 FCM token refreshed — updating Firestore…');
      await saveTokenToFirestore();
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onNotificationTap(initial);

    // Start listening to this user's Firestore notification docs
    startListeningToFirestoreNotifications();

    debugPrint('✅ NotificationService initialized');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Firestore real-time notification listener
  // Other devices write to users/{uid}/notifications → this device shows popup
  // ──────────────────────────────────────────────────────────────────────────

  static void startListeningToFirestoreNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final title = (data['title'] as String?) ?? '💬 Split Expenses';
        final body  = (data['body']  as String?) ?? 'You have a new notification.';

        debugPrint('🔔 [Firestore] New notification: $title');
        debugPrint('💬 Content: $body');

        await _showLocalNotification(
          title: title,
          body: body,
          id: change.doc.id.hashCode,
        );

        // Mark as read so it doesn't re-trigger on next snapshot
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(change.doc.id)
            .update({'isRead': true});
      }
    }, onError: (e) {
      debugPrint('❌ Firestore notification listener error: $e');
    });

    debugPrint('👂 Listening to Firestore notifications for ${user.uid}');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public send methods — write notification docs to target users' Firestore
  // ──────────────────────────────────────────────────────────────────────────

  /// Notifies all split members (except payer) when a new expense is added.
  static Future<void> sendExpenseNotification({
    required String groupName,
    required String groupId,
    required String expenseId,
    required String expenseTitle,
    required double totalAmount,
    required String payerName,
    required String payerUserId,
    required List<String> splitUserIds,
    required int splitCount,
  }) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [NOTIF] sendExpenseNotification() called');
    debugPrint('   Group     : $groupName ($groupId)');
    debugPrint('   Expense   : $expenseTitle (₹$totalAmount)');
    debugPrint('   Payer     : $payerName ($payerUserId)');
    debugPrint('   Split UIDs: $splitUserIds');
    debugPrint('   Split count: $splitCount');

    final recipients = splitUserIds.where((uid) => uid != payerUserId).toList();
    debugPrint('   Recipients (excl. payer): $recipients');

    if (recipients.isEmpty) {
      debugPrint('   ⚠️  No recipients — everyone is the payer, skipping.');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    final perPerson = (totalAmount / splitCount).toStringAsFixed(2);
    final title = '💸 New expense in "$groupName"';
    final body = '$payerName added "$expenseTitle" for ₹$totalAmount. '
                 'Your share: ₹$perPerson — Time to pay up!';

    debugPrint('   Title: $title');
    debugPrint('   Body : $body');

    await _sendFirestoreNotification(
      targetUserIds: recipients,
      title: title,
      body: body,
      type: 'expense_added',
      groupId: groupId,
      expenseId: expenseId,
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Notifies a newly added member when they are added to a group.
  static Future<void> sendMemberAddedNotification({
    required String groupName,
    required String groupId,
    required String addedByName,
    required List<String> newMemberUserIds,
  }) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [NOTIF] sendMemberAddedNotification() called');
    debugPrint('   Group      : $groupName ($groupId)');
    debugPrint('   Added by   : $addedByName');
    debugPrint('   New members: $newMemberUserIds');

    if (newMemberUserIds.isEmpty) {
      debugPrint('   ⚠️  No new members — skipping.');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    await _sendFirestoreNotification(
      targetUserIds: newMemberUserIds,
      title: '👥 You were added to a group!',
      body: '$addedByName added you to "$groupName". Check your expenses!',
      type: 'member_added',
      groupId: groupId,
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Notifies the debtor when their payment is marked as paid.
  static Future<void> sendPaymentConfirmedNotification({
    required String groupName,
    required String groupId,
    required String confirmedByName,
    required double amount,
    required String debtorUserId,
    String? note,
  }) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [NOTIF] sendPaymentConfirmedNotification() called');
    debugPrint('   Group        : $groupName ($groupId)');
    debugPrint('   Confirmed by : $confirmedByName');
    debugPrint('   Amount       : ₹$amount');
    debugPrint('   Debtor UID   : $debtorUserId');
    debugPrint('   Note         : ${note ?? "(none)"}');

    final body = (note != null && note.trim().isNotEmpty)
        ? '$confirmedByName confirmed your ₹$amount payment in "$groupName". Note: $note'
        : '$confirmedByName confirmed your payment of ₹$amount in "$groupName" ✅';

    await _sendFirestoreNotification(
      targetUserIds: [debtorUserId],
      title: '✅ Payment confirmed!',
      body: body,
      type: 'payment_confirmed',
      groupId: groupId,
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Sends a custom payment reminder from the group owner to members who owe money.
  static Future<void> sendReminderNotification({
    required String groupName,
    required String groupId,
    required String senderName,
    required String message,
    required List<String> targetUserIds,
  }) async {
    if (targetUserIds.isEmpty) return;
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [NOTIF] sendReminderNotification() called');
    debugPrint('   Sender     : $senderName');
    debugPrint('   Group      : $groupName');
    debugPrint('   Recipients : $targetUserIds');
    debugPrint('   Message    : $message');

    await _sendFirestoreNotification(
      targetUserIds: targetUserIds,
      title: '⏰ Payment Reminder from $senderName',
      body: message,
      type: 'payment_reminder',
      groupId: groupId,
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }


  // ──────────────────────────────────────────────────────────────────────────
  // Private: batch-write notification docs to Firestore
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _sendFirestoreNotification({
    required List<String> targetUserIds,
    required String title,
    required String body,
    required String type,
    String? groupId,
    String? expenseId,
  }) async {
    if (targetUserIds.isEmpty) return;

    debugPrint('📤 [NOTIF] Writing to Firestore for ${targetUserIds.length} user(s)…');

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final uid in targetUserIds) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc();

        debugPrint('   → Writing to users/$uid/notifications/${ref.id}');

        batch.set(ref, {
          'title': title,
          'body': body,
          'type': type,
          if (groupId != null) 'groupId': groupId,
          if (expenseId != null) 'expenseId': expenseId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ [NOTIF] Firestore batch commit succeeded!');
    } catch (e) {
      debugPrint('❌ [NOTIF] Firestore batch commit FAILED: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Local notifications setup
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 Local notification tapped: ${details.payload}');
      },
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FCM token management
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> saveTokenToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️  saveTokenToFirestore: no logged-in user — skipping.');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️  FCM token is null — skipping.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      debugPrint('✅ FCM token saved to Firestore for user ${user.uid}');
      debugPrint('');
      debugPrint('════════════════════════════════════════════════════════════');
      debugPrint('📋 YOUR FCM TOKEN (copy to test from Firebase Console):');
      debugPrint('');
      debugPrint(token);
      debugPrint('');
      debugPrint('HOW TO TEST:');
      debugPrint('  1. Firebase Console → Engage → Messaging');
      debugPrint('  2. New campaign → Firebase Notification messages');
      debugPrint('  3. Click "Send test message"');
      debugPrint('  4. Paste the token above → Add → Test');
      debugPrint('════════════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  static Future<void> removeTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': FieldValue.delete()});

      debugPrint('🗑️  FCM token removed from Firestore');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FCM message handlers
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    debugPrint('🔔 [FG] ${notification.title} — ${notification.body}');
    await _showLocalNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      id: message.hashCode,
    );
  }

  static void _onNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped — data: ${message.data}');
  }
}
