import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/word.dart';
import 'firestore_service.dart';
import 'persistent_notification_channel.dart';

/// Singleton service for vocabulary learning reminders
/// Features: Spaced repetition reminders
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  // Notification channel constants
  static const String _channelId = 'vocabulary_reminders';
  static const String _channelName = 'Vocabulary Reminders';
  static const String _channelDescription =
      'Vocabulary learning reminders using spaced repetition';

  // ============================================
  // Action Button Identifiers
  // ============================================
  static const String actionOpenApp = 'OPEN_APP';

  // ============================================
  // Scheduling Configuration: 5 times per day for better learning
  // ============================================
  static const List<Map<String, int>> _dailySchedules = [
    {'hour': 8, 'minute': 0}, // Morning
    {'hour': 10, 'minute': 30}, // Mid-morning
    {'hour': 12, 'minute': 30}, // Noon
    {'hour': 16, 'minute': 0}, // Afternoon
    {'hour': 20, 'minute': 0}, // Evening
  ];

  // ============================================
  // Navigation State
  // ============================================
  static String? _lastTappedWordId;
  static String? get lastTappedWordId => _lastTappedWordId;
  static void clearLastTappedWordId() => _lastTappedWordId = null;

  static bool _shouldNavigateToFlashcard = false;
  static bool get shouldNavigateToFlashcard => _shouldNavigateToFlashcard;
  static void clearNavigationFlag() => _shouldNavigateToFlashcard = false;

  // ============================================
  // Initialization
  // ============================================

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Android initialization settings — use a dedicated monochrome drawable
    // so the status bar shows a clean branded icon instead of a solid square.
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Create notification channel
    await _createNotificationChannel();

    debugPrint('NotificationService: Initialized successfully');
  }

  /// Request notification permissions (iOS and Android 13+)
  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool granted = false;

    if (android != null) {
      // Request notification permission
      granted = await android.requestNotificationsPermission() ?? false;
      debugPrint('NotificationService: Notification permission = $granted');

      // Request exact alarm permission for Android 12+
      final exactAlarmGranted =
          await android.requestExactAlarmsPermission() ?? false;
      debugPrint(
        'NotificationService: Exact alarm permission = $exactAlarmGranted',
      );
    }

    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    debugPrint('NotificationService: Permission granted = $granted');
    return granted;
  }

  /// Check if all required permissions are granted
  Future<Map<String, bool>> checkPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final result = <String, bool>{'notifications': false, 'exactAlarms': false};

    if (android != null) {
      result['notifications'] =
          await android.areNotificationsEnabled() ?? false;
      // Note: There's no direct API to check exact alarm permission status
      // But we can assume it's granted if notifications are enabled
      result['exactAlarms'] = result['notifications']!;
    }

    debugPrint('NotificationService: Permissions check = $result');
    return result;
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ============================================
  // Vocabulary Selection (Spaced Repetition)
  // ============================================

  /// Select a word using spaced repetition algorithm
  Future<Word?> _selectWordBySpacedRepetition(List<Word> allWords) async {
    if (allWords.isEmpty) return null;

    final random = Random();
    final roll = random.nextDouble();

    final forgotWords = allWords.where((w) => w.status == 0).toList();
    final hardWords = allWords.where((w) => w.status == 1).toList();
    final goodWords = allWords.where((w) => w.status == 2).toList();
    final easyWords = allWords.where((w) => w.status >= 3).toList();

    List<Word> pool;

    if (roll < 0.70 && forgotWords.isNotEmpty) {
      pool = forgotWords;
    } else if (roll < 0.90 && hardWords.isNotEmpty) {
      pool = hardWords;
    } else if (roll < 0.98 && goodWords.isNotEmpty) {
      pool = goodWords;
    } else if (easyWords.isNotEmpty) {
      pool = easyWords;
    } else if (forgotWords.isNotEmpty) {
      pool = forgotWords;
    } else {
      pool = allWords;
    }

    pool.shuffle();
    return pool.first;
  }

  // ============================================
  // Notification Response Handlers
  // ============================================

  /// Handle notification response when app is in foreground/background
  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint(
      'NotificationService: Response - action: ${response.actionId}, payload: ${response.payload}',
    );

    final notificationId = response.id;
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      if (notificationId != null) {
        NotificationService()._cancelNotification(notificationId);
      }
      return;
    }

    // Parse payload JSON
    Map<String, dynamic> payloadData;
    try {
      payloadData = jsonDecode(payload);
    } catch (e) {
      payloadData = {'wordId': payload};
    }

    final wordId = payloadData['wordId'] as String? ?? payload;
    final isPersistent = payloadData['persistent'] == true;

    // Only cancel notification if NOT in persistent/hardcore mode
    if (notificationId != null && !isPersistent) {
      await NotificationService()._cancelNotification(notificationId);
    }

    // Navigate to flashcard
    _lastTappedWordId = wordId;
    _shouldNavigateToFlashcard = true;
    debugPrint('NotificationService: Navigate to flashcard for "$wordId"');
  }

  /// Handle notification response when app was terminated
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _onNotificationResponse(response);
  }

  /// Cancel a specific notification by ID
  Future<void> _cancelNotification(int id) async {
    await _notifications.cancel(id);
    await PersistentNotificationChannel.cancelAlarm(id);
    debugPrint('NotificationService: Cancelled notification $id');
  }

  // ============================================
  // Scheduling Logic
  // ============================================

  /// Schedule notifications for TODAY and the next 7 days
  Future<void> scheduleNext7Days() async {
    await _notifications.cancelAll();
    await PersistentNotificationChannel.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    List<Word> allWords = [];
    bool isPersistentMode = false;
    try {
      allWords = await _firestoreService.getAllWords();
      final settings = await _firestoreService.fetchUserSettings();
      isPersistentMode = settings['isPersistentMode'] ?? false;
    } catch (e) {
      debugPrint('NotificationService: Error fetching data: $e');
      return;
    }

    if (allWords.isEmpty) return;

    int totalScheduled = 0;
    final now = tz.TZDateTime.now(tz.local);

    // Schedule for TODAY
    for (int slotIndex = 0; slotIndex < _dailySchedules.length; slotIndex++) {
      final schedule = _dailySchedules[slotIndex];
      final hour = schedule['hour']!;
      final minute = schedule['minute']!;

      final todaySlot = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (todaySlot.isAfter(now)) {
        final word = await _selectWordBySpacedRepetition(allWords);
        if (word == null) continue;

        final notificationId = 1000 + slotIndex;
        await _scheduleReminderNotification(
          id: notificationId,
          word: word,
          scheduledDate: todaySlot,
          isPersistentMode: isPersistentMode,
        );
        totalScheduled++;
      }
    }

    // Schedule for the next 7 days
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      for (int slotIndex = 0; slotIndex < _dailySchedules.length; slotIndex++) {
        final schedule = _dailySchedules[slotIndex];
        final hour = schedule['hour']!;
        final minute = schedule['minute']!;

        final word = await _selectWordBySpacedRepetition(allWords);
        if (word == null) continue;

        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + dayIndex,
          hour,
          minute,
        );

        final notificationId = (dayIndex * 10) + slotIndex;
        await _scheduleReminderNotification(
          id: notificationId,
          word: word,
          scheduledDate: scheduledDate,
          isPersistentMode: isPersistentMode,
        );
        totalScheduled++;
      }
    }

    debugPrint('NotificationService: Total scheduled: $totalScheduled');
  }

  /// Schedule notifications with custom times from user settings
  Future<void> scheduleWithCustomTimes(
    List<Map<String, int>> customSchedules,
  ) async {
    await _notifications.cancelAll();
    await PersistentNotificationChannel.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    if (customSchedules.isEmpty) return;

    List<Word> allWords = [];
    bool isPersistentMode = false;
    try {
      allWords = await _firestoreService.getAllWords();
      final settings = await _firestoreService.fetchUserSettings();
      isPersistentMode = settings['isPersistentMode'] ?? false;
    } catch (e) {
      debugPrint('NotificationService: Error fetching data: $e');
      return;
    }

    if (allWords.isEmpty) return;

    int totalScheduled = 0;
    final now = tz.TZDateTime.now(tz.local);

    for (int dayIndex = 0; dayIndex <= 7; dayIndex++) {
      for (int slotIndex = 0; slotIndex < customSchedules.length; slotIndex++) {
        final schedule = customSchedules[slotIndex];
        final hour = schedule['hour'] ?? 8;
        final minute = schedule['minute'] ?? 0;

        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + dayIndex,
          hour,
          minute,
        );

        if (scheduledDate.isAfter(now)) {
          final word = await _selectWordBySpacedRepetition(allWords);
          if (word == null) continue;

          final notificationId = (dayIndex * 100) + slotIndex;
          await _scheduleReminderNotification(
            id: notificationId,
            word: word,
            scheduledDate: scheduledDate,
            isPersistentMode: isPersistentMode,
          );
          totalScheduled++;
        }
      }
    }
    debugPrint('NotificationService: Total custom scheduled: $totalScheduled');
  }

  // ============================================
  // Reminder Notification Builders
  // ============================================

  /// Schedule a reminder notification
  Future<void> _scheduleReminderNotification({
    required int id,
    required Word word,
    required tz.TZDateTime scheduledDate,
    bool isPersistentMode = false,
  }) async {
    final result = _buildReminderNotification(
      word,
      isPersistentMode: isPersistentMode,
    );

    // Trên Android với persistent mode: dùng native alarm + setDeleteIntent
    // để notification tự re-show khi bị dismiss (Android 14+ không ngăn swipe nữa).
    if (isPersistentMode && Platform.isAndroid) {
      await PersistentNotificationChannel.scheduleAlarm(
        id: id,
        timeMs: scheduledDate.millisecondsSinceEpoch,
        title: result['title']!,
        body: result['body']!,
        payload: result['payload']!,
      );
      return;
    }

    await _notifications.zonedSchedule(
      id,
      result['title']!,
      result['body']!,
      scheduledDate,
      result['details'] as NotificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: result['payload']!,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Build a simple reminder notification
  Map<String, dynamic> _buildReminderNotification(
    Word word, {
    bool isPersistentMode = false,
  }) {
    final title = '💡 Ôn tập từ: ${word.word}';
    final body = 'Phát âm: [${word.ipa}]\nNghĩa: ${word.primaryShortMeaning}';

    final payload = jsonEncode({
      'wordId': word.english,
      'wordText': word.word,
      'type': 'reminder',
      'persistent': isPersistentMode,
    });

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      ongoing: isPersistentMode,
      autoCancel: !isPersistentMode,
      styleInformation: BigTextStyleInformation(body),
      // Explicit monochrome icon for the status bar
      icon: 'ic_notification',
      // Tint the icon with the app's primary blue colour
      color: const Color(0xFF2196F3),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return {
      'title': title,
      'body': body,
      'payload': payload,
      'details': NotificationDetails(android: androidDetails, iOS: iosDetails),
    };
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    List<Word> words = [];
    bool isPersistentMode = false;
    try {
      words = await _firestoreService.getAllWords();
      final settings = await _firestoreService.fetchUserSettings();
      isPersistentMode = settings['isPersistentMode'] ?? false;
    } catch (e) {
      debugPrint('NotificationService: Error fetching data: $e');
      return;
    }

    if (words.isEmpty) return;

    final random = Random();
    final testWord = words[random.nextInt(words.length)];
    final result = _buildReminderNotification(
      testWord,
      isPersistentMode: isPersistentMode,
    );

    await _notifications.show(
      999,
      result['title']!,
      result['body']!,
      result['details'] as NotificationDetails,
      payload: result['payload']!,
    );
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await PersistentNotificationChannel.cancelAll();
  }
}
