import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  bool _initialized = false;

  // Stream controller for notification taps
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  // Stream controller for foreground messages
  final _foregroundMessageController = 
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  /// Initialize Firebase and setup messaging
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      debugPrint('🔥 Firebase initialized successfully');

      // Now initialize messaging (after Firebase is ready)
      _messaging = FirebaseMessaging.instance;

      // Request permission for notifications (iOS)
      await _requestPermission();

      // Setup local notifications for foreground
      await _setupLocalNotifications();

      // Setup message handlers
      await _setupMessageHandlers();

      // Get FCM token (but don't register yet - wait for login)
      await _getTokenOnly();

      // Listen for token refresh (register only if already logged in)
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      _initialized = true;
      debugPrint('✅ Firebase Messaging initialized');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }
  }

  /// Request notification permission (iOS and Android 13+)
  Future<void> _requestPermission() async {
    // Request permission for both iOS and Android 13+
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');
  }

  /// Setup local notifications for foreground messages
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Local notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = _parsePayload(response.payload!);
            _notificationTapController.add(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Setup Firebase message handlers
  Future<void> _setupMessageHandlers() async {
    // Background handler (must be set before app starts)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📨=== FOREGROUND MESSAGE RECEIVED ===');
      debugPrint('📨 Message ID: ${message.messageId}');
      debugPrint('📨 Title: ${message.notification?.title}');
      debugPrint('📨 Body: ${message.notification?.body}');
      debugPrint('📨 Data: ${message.data}');
      _foregroundMessageController.add(message);
      await _handleForegroundMessage(message);
    });

    // Message opened app (when app is in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📨 Message opened app: ${message.messageId}');
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📨 App opened from terminated state via notification');
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Handling foreground message: ${message.messageId}');
    debugPrint('📨 Message data: ${message.data}');
    
    final notification = message.notification;
    final android = message.notification?.android;
    
    debugPrint('📨 Notification: $notification');
    debugPrint('📨 Android details: $android');

    if (notification != null) {
      debugPrint('📨 Showing local notification: ${notification.title}');
      
      AndroidBitmap<Object>? largeIcon;
      final imageUrl = message.data['image'];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl.toString()));
          if (response.statusCode == 200) {
            largeIcon = ByteArrayAndroidBitmap(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error downloading image for largeIcon: $e');
        }
      }

      try {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              largeIcon: largeIcon,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: _encodePayload(message.data),
        );
        debugPrint('✅ Local notification shown successfully');
      } catch (e) {
        debugPrint('❌ Error showing local notification: $e');
      }
    } else {
      debugPrint('⚠️ No notification payload in message');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('🔔 Notification tapped with data: $data');
    _notificationTapController.add(data);

    // Navigate based on notification type
    final type = data['type'] ?? data['notification_type'];
    final category = data['category'];
    final image = data['image'];
    final rentalId = data['rental_id'];
    final vehicleId = data['vehicle_id'];
    
    if (category != null) debugPrint('🔔 Category: $category');
    if (image != null) debugPrint('🔔 Image: $image');

    // The actual navigation should be handled by a navigator service
    // or by listening to onNotificationTap stream in the UI
  }

  /// Get FCM token only (without registering - called at app startup)
  Future<void> _getTokenOnly() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token obtained: ${_fcmToken?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Get FCM token and register with backend
  Future<void> _getAndRegisterToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _registerDeviceWithBackend(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
    _fcmToken = newToken;
    // Only register if user has a valid token (logged in)
    final headers = await _apiService.getHeaders();
    if (headers.containsKey('Authorization')) {
      await _registerDeviceWithBackend(newToken);
    } else {
      debugPrint('⏳ Token refresh deferred - user not logged in');
    }
  }

  /// Register device with backend API
  Future<void> _registerDeviceWithBackend(String token) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final response = await _apiService.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        deviceName: deviceInfo['deviceName'] ?? 'Unknown Device',
        appVersion: deviceInfo['appVersion'] ?? '1.0.0',
      );

      if (response['success'] == true) {
        debugPrint('✅ Device registered with backend');
      } else {
        debugPrint('❌ Device registration failed: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    String deviceName = 'Unknown Device';
    String appVersion = '1.0.0';

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name ?? 'iOS Device';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {
      'deviceName': deviceName,
      'appVersion': appVersion,
    };
  }

  /// Manually trigger device registration (call after login)
  Future<void> registerDeviceAfterLogin() async {
    if (_fcmToken != null) {
      await _registerDeviceWithBackend(_fcmToken!);
    } else {
      await _getAndRegisterToken();
    }
  }

  /// Unregister device (call on logout)
  Future<void> unregisterDevice() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('✅ Device unregistered');
    } catch (e) {
      debugPrint('❌ Error unregistering device: $e');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Parse payload string to map
  Map<String, dynamic> _parsePayload(String payload) {
    final parts = payload.split('&');
    final map = <String, dynamic>{};
    for (final part in parts) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        map[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
      }
    }
    return map;
  }

  /// Encode map to payload string
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
    _foregroundMessageController.close();
  }
}
