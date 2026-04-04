import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // Notifications are not supported on web
    if (kIsWeb) return;

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
    if (kIsWeb) return false;

    // Use permission_handler for reliable results in release builds
    final status = await Permission.notification.request();
    final granted = status.isGranted;
    debugPrint('NotificationService: Notification permission status = $status');

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Also ensure exact alarm permission for Android 12+
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final exactAlarmGranted =
            await android.requestExactAlarmsPermission() ?? false;
        debugPrint(
          'NotificationService: Exact alarm permission = $exactAlarmGranted',
        );
      }
    }

    return granted;
  }

  /// Check if all required permissions are granted
  Future<Map<String, bool>> checkPermissions() async {
    if (kIsWeb) return {'notifications': false, 'exactAlarms': false};

    final status = await Permission.notification.status;
    final isGranted = status.isGranted;

    final result = {
      'notifications': isGranted,
      'exactAlarms': isGranted, // Simplified for check
    };

    debugPrint(
      'NotificationService: Permissions check = $result (Status: $status)',
    );
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

  /// Pre-categorize words by status for efficient batch selection
  Map<int, List<Word>> _categorizeWordsByStatus(List<Word> words) {
    final Map<int, List<Word>> categorized = {
      0: [], // Forgot
      1: [], // Hard
      2: [], // Good
      3: [], // Easy
    };

    for (var word in words) {
      final status = word.status.clamp(0, 3);
      categorized[status]!.add(word);
    }

    // Shuffle each category once
    for (var list in categorized.values) {
      list.shuffle();
    }

    return categorized;
  }

  /// Select multiple words efficiently using batch selection with spaced repetition
  /// This is much faster than calling _selectWordBySpacedRepetition() many times
  /// Returns up to 'count' words, may return fewer if word pool is exhausted
  List<Word> _batchSelectWords(
    Map<int, List<Word>> categorizedWords,
    int count,
  ) {
    final List<Word> selected = [];
    final random = Random();

    // Calculate total available words
    final totalAvailable = categorizedWords.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    if (totalAvailable == 0) {
      debugPrint('NotificationService: No words available for selection');
      return selected;
    }

    // Adjust count if not enough words available
    final actualCount = count.clamp(0, totalAvailable);
    if (actualCount < count) {
      debugPrint(
        'NotificationService: Only $actualCount words available (requested $count)',
      );
    }

    // Keep track of selected indices per category to avoid duplicates
    final Map<int, int> categoryIndices = {0: 0, 1: 0, 2: 0, 3: 0};

    for (int i = 0; i < actualCount; i++) {
      final roll = random.nextDouble();
      int selectedStatus;

      // Spaced repetition probabilities:
      // 70% Forgot (status 0)
      // 20% Hard (status 1)
      // 8% Good (status 2)
      // 2% Easy (status 3)
      if (roll < 0.70) {
        selectedStatus = 0;
      } else if (roll < 0.90) {
        selectedStatus = 1;
      } else if (roll < 0.98) {
        selectedStatus = 2;
      } else {
        selectedStatus = 3;
      }

      // Try to get word from selected category
      Word? word = _getNextWordFromCategory(
        categorizedWords,
        selectedStatus,
        categoryIndices,
      );

      // Fallback: try other categories in priority order
      if (word == null) {
        for (var status in [0, 1, 2, 3]) {
          word = _getNextWordFromCategory(
            categorizedWords,
            status,
            categoryIndices,
          );
          if (word != null) break;
        }
      }

      if (word != null) {
        selected.add(word);
      } else {
        debugPrint('NotificationService: Could not find word at index $i');
        break; // Stop if no more words available
      }
    }

    debugPrint('NotificationService: Selected ${selected.length} words');
    return selected;
  }

  /// Get next word from a specific category
  Word? _getNextWordFromCategory(
    Map<int, List<Word>> categorizedWords,
    int status,
    Map<int, int> indices,
  ) {
    final category = categorizedWords[status]!;
    final currentIndex = indices[status]!;

    if (currentIndex < category.length) {
      final word = category[currentIndex];
      indices[status] = currentIndex + 1;
      return word;
    }

    return null;
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
  /// Optimized for large word lists (3000+ words)
  /// Returns the number of notifications scheduled
  Future<int> scheduleNext7Days() async {
    if (kIsWeb) return 0;
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
      return 0;
    }

    if (allWords.isEmpty) {
      debugPrint('NotificationService: No words found');
      return 0;
    }

    debugPrint('NotificationService: Found ${allWords.length} words');

    final now = tz.TZDateTime.now(tz.local);
    final List<tz.TZDateTime> scheduleTimes = [];

    // Calculate all schedule times first
    // TODAY
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
        scheduleTimes.add(todaySlot);
      }
    }

    // Next 7 days
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      for (int slotIndex = 0; slotIndex < _dailySchedules.length; slotIndex++) {
        final schedule = _dailySchedules[slotIndex];
        final hour = schedule['hour']!;
        final minute = schedule['minute']!;

        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + dayIndex,
          hour,
          minute,
        );

        scheduleTimes.add(scheduledDate);
      }
    }

    debugPrint(
      'NotificationService: Calculated ${scheduleTimes.length} time slots',
    );

    // Batch select words all at once (much faster than individual selection)
    debugPrint(
      'NotificationService: Batch selecting ${scheduleTimes.length} words from ${allWords.length} words',
    );
    final categorizedWords = _categorizeWordsByStatus(allWords);
    final selectedWords = _batchSelectWords(
      categorizedWords,
      scheduleTimes.length,
    );

    if (selectedWords.isEmpty) {
      debugPrint('NotificationService: No words selected');
      return 0;
    }

    // Schedule all notifications
    int totalScheduled = 0;
    for (int i = 0; i < scheduleTimes.length && i < selectedWords.length; i++) {
      final notificationId = 1000 + i;
      try {
        await _scheduleReminderNotification(
          id: notificationId,
          word: selectedWords[i],
          scheduledDate: scheduleTimes[i],
          isPersistentMode: isPersistentMode,
        );
        totalScheduled++;
      } catch (e) {
        debugPrint(
          'NotificationService: Error scheduling notification $notificationId: $e',
        );
      }
    }

    debugPrint('NotificationService: Total scheduled: $totalScheduled');
    return totalScheduled;
  }

  /// Schedule notifications with custom times from user settings
  /// Optimized for large word lists (3000+ words)
  /// Returns the number of notifications scheduled
  Future<int> scheduleWithCustomTimes(
    List<Map<String, int>> customSchedules,
  ) async {
    if (kIsWeb) return 0;
    await _notifications.cancelAll();
    await PersistentNotificationChannel.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    if (customSchedules.isEmpty) {
      debugPrint('NotificationService: No custom schedules provided');
      return 0;
    }

    List<Word> allWords = [];
    bool isPersistentMode = false;
    try {
      allWords = await _firestoreService.getAllWords();
      final settings = await _firestoreService.fetchUserSettings();
      isPersistentMode = settings['isPersistentMode'] ?? false;
    } catch (e) {
      debugPrint('NotificationService: Error fetching data: $e');
      return 0;
    }

    if (allWords.isEmpty) {
      debugPrint('NotificationService: No words found');
      return 0;
    }

    debugPrint('NotificationService: Found ${allWords.length} words');

    final now = tz.TZDateTime.now(tz.local);
    final List<tz.TZDateTime> scheduleTimes = [];

    // Calculate all schedule times
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
          scheduleTimes.add(scheduledDate);
        }
      }
    }

    debugPrint(
      'NotificationService: Calculated ${scheduleTimes.length} time slots',
    );

    // Batch select words all at once
    debugPrint(
      'NotificationService: Batch selecting ${scheduleTimes.length} words from ${allWords.length} words',
    );
    final categorizedWords = _categorizeWordsByStatus(allWords);
    final selectedWords = _batchSelectWords(
      categorizedWords,
      scheduleTimes.length,
    );

    if (selectedWords.isEmpty) {
      debugPrint('NotificationService: No words selected');
      return 0;
    }

    // Schedule all notifications
    int totalScheduled = 0;
    for (int i = 0; i < scheduleTimes.length && i < selectedWords.length; i++) {
      final notificationId = 1000 + i;
      try {
        await _scheduleReminderNotification(
          id: notificationId,
          word: selectedWords[i],
          scheduledDate: scheduleTimes[i],
          isPersistentMode: isPersistentMode,
        );
        totalScheduled++;
      } catch (e) {
        debugPrint(
          'NotificationService: Error scheduling notification $notificationId: $e',
        );
      }
    }

    debugPrint('NotificationService: Total custom scheduled: $totalScheduled');
    return totalScheduled;
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
    if (isPersistentMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
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
    if (kIsWeb) return;
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
    if (kIsWeb) return [];
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
    await PersistentNotificationChannel.cancelAll();
  }
}
