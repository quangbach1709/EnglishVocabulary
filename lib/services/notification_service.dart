import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/word.dart';
import 'firestore_service.dart';

/// Enum representing the 3 psychological notification strategies
enum NotificationStrategy {
  microQuiz, // Strategy A: 40% - Action buttons with quiz
  fillBlank, // Strategy B: 30% - Fill-in-the-blank
  emotional, // Strategy C: 30% - SOS urgency trigger
}

/// Singleton service for managing vocabulary reminder notifications
/// with 3 psychological strategies for better retention
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  // Notification channel constants for Android
  static const String _channelId = 'vocabulary_reminders';
  static const String _channelName = 'Vocabulary Reminders';
  static const String _channelDescription =
      'Daily vocabulary review notifications with interactive quizzes';

  // Action button identifiers
  static const String actionMarkKnown = 'MARK_KNOWN';
  static const String actionOpenApp = 'OPEN_APP';
  // Legacy action identifiers for Micro-Quiz strategy
  static const String actionCorrect = 'action_correct';
  static const String actionDistractor = 'action_distractor';

  // Scheduling configuration
  static const int _notificationHour = 9; // 9:00 AM
  static const int _notificationMinute = 0;

  /// Callback for handling notification taps
  /// Returns the wordId from payload so the app can navigate to flashcard
  static String? _lastTappedWordId;
  static String? get lastTappedWordId => _lastTappedWordId;
  static void clearLastTappedWordId() => _lastTappedWordId = null;

  /// Flag to indicate if we should navigate to flashcard
  static bool _shouldNavigateToFlashcard = false;
  static bool get shouldNavigateToFlashcard => _shouldNavigateToFlashcard;
  static void clearNavigationFlag() => _shouldNavigateToFlashcard = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
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

    // Create notification channel for Android
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
      granted = await android.requestNotificationsPermission() ?? false;
    }
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    debugPrint('NotificationService: Permission granted = $granted');
    return granted;
  }

  /// Create Android notification channel with action buttons support
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

  /// Handle notification response when app is in foreground/background
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      'NotificationService: Response - action: ${response.actionId}, payload: ${response.payload}',
    );

    final notificationId = response.id;
    final wordId = response.payload;
    final actionId = response.actionId;

    if (wordId == null || wordId.isEmpty) {
      debugPrint('NotificationService: No payload, ignoring');
      return;
    }

    // Handle different actions
    if (actionId == actionMarkKnown) {
      // User tapped "I know this" - mark word as reviewed and cancel notification
      _handleMarkKnown(wordId, notificationId);
    } else if (actionId == actionOpenApp ||
        actionId == actionCorrect ||
        actionId == actionDistractor ||
        actionId == null) {
      // User tapped notification body, "Learn Now", or quiz buttons
      // Set navigation flag and cancel notification
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
      if (notificationId != null) {
        NotificationService()._cancelNotification(notificationId);
      }
      debugPrint('NotificationService: Navigate to flashcard for "$wordId"');
    }
  }

  /// Handle notification response when app was terminated
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint(
      'NotificationService: Background response - action: ${response.actionId}, payload: ${response.payload}',
    );

    final notificationId = response.id;
    final wordId = response.payload;
    final actionId = response.actionId;

    if (wordId == null || wordId.isEmpty) return;

    if (actionId == actionMarkKnown) {
      // Handle "I know this" in background
      _handleMarkKnown(wordId, notificationId);
    } else {
      // Open app and navigate to flashcard
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
      if (notificationId != null) {
        NotificationService()._cancelNotification(notificationId);
      }
    }
  }

  /// Handle "I know this" action - update word status and cancel notification
  static void _handleMarkKnown(String wordId, int? notificationId) {
    debugPrint('NotificationService: Marking "$wordId" as known');

    // Update word status in Firestore (status 2 = Good)
    final firestoreService = FirestoreService();
    firestoreService
        .updateWordStatus(
          wordId,
          2, // Status 2 = Good (Yellow)
          DateTime.now().add(const Duration(days: 3)), // Next review in 3 days
        )
        .then((_) {
          debugPrint('NotificationService: Word "$wordId" marked as known');
        })
        .catchError((e) {
          debugPrint('NotificationService: Error marking word as known: $e');
        });

    // Cancel the sticky notification
    if (notificationId != null) {
      NotificationService()._cancelNotification(notificationId);
    }
  }

  /// Cancel a specific notification by ID
  Future<void> _cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('NotificationService: Cancelled notification $id');
  }

  /// Schedule notifications for the next 7 days
  /// Call this when the app opens to pre-schedule notifications
  Future<void> scheduleNext7Days() async {
    // Cancel all existing scheduled notifications first
    await _notifications.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    // Fetch priority words (Forgot and Hard status)
    List<Word> priorityWords = [];
    try {
      priorityWords = await _firestoreService.getPriorityWords();
      debugPrint(
        'NotificationService: Fetched ${priorityWords.length} priority words',
      );
    } catch (e) {
      debugPrint('NotificationService: Error fetching words: $e');
    }

    // If no priority words, fetch all words as fallback
    if (priorityWords.isEmpty) {
      try {
        final allWords = await _firestoreService.getAllWords();
        if (allWords.isNotEmpty) {
          priorityWords = allWords..shuffle();
          if (priorityWords.length > 14) {
            priorityWords = priorityWords.sublist(0, 14);
          }
        }
        debugPrint(
          'NotificationService: Using ${priorityWords.length} fallback words',
        );
      } catch (e) {
        debugPrint('NotificationService: Error fetching fallback words: $e');
        return;
      }
    }

    if (priorityWords.isEmpty) {
      debugPrint(
        'NotificationService: No words available, skipping scheduling',
      );
      return;
    }

    // Schedule 7 notifications, one for each day
    for (int day = 0; day < 7; day++) {
      final word = priorityWords[day % priorityWords.length];
      final strategy = _selectStrategy(word, priorityWords);
      final scheduledDate = _getScheduledDate(day + 1);

      await _scheduleNotification(
        id: day,
        word: word,
        strategy: strategy,
        scheduledDate: scheduledDate,
        distractorWord: _getDistractorWord(word, priorityWords),
      );

      debugPrint(
        'NotificationService: Scheduled day ${day + 1} - ${strategy.name} for "${word.word}"',
      );
    }

    debugPrint(
      'NotificationService: Successfully scheduled 7 days of notifications',
    );
  }

  /// Select notification strategy based on word properties and randomization
  NotificationStrategy _selectStrategy(Word word, List<Word> allWords) {
    // Force Emotional SOS for forgotten words (status == 0)
    if (word.status == 0) {
      return NotificationStrategy.emotional;
    }

    final rand = Random().nextDouble();

    // 40% chance for Micro-Quiz (need at least 2 words for distractor)
    if (rand < 0.40 && allWords.length >= 2) {
      return NotificationStrategy.microQuiz;
    }

    // 30% chance for Fill-in-the-Blank (only if examples exist)
    if (rand < 0.70 && word.examplesEn.isNotEmpty) {
      return NotificationStrategy.fillBlank;
    }

    // 30% Emotional trigger (fallback)
    return NotificationStrategy.emotional;
  }

  /// Get a random distractor word different from the target
  Word _getDistractorWord(Word targetWord, List<Word> allWords) {
    if (allWords.length < 2) return targetWord;

    final shuffled = List<Word>.from(allWords)..shuffle();
    return shuffled.firstWhere(
      (w) => w.english != targetWord.english,
      orElse: () => targetWord,
    );
  }

  /// Calculate the scheduled date for a notification
  tz.TZDateTime _getScheduledDate(int daysFromNow) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysFromNow,
      _notificationHour,
      _notificationMinute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (daysFromNow == 0 && scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Build common action buttons for sticky notifications
  List<AndroidNotificationAction> _buildStickyActions() {
    return <AndroidNotificationAction>[
      const AndroidNotificationAction(
        actionMarkKnown,
        '✅ I know this',
        showsUserInterface: false, // Dismiss without opening app
        cancelNotification: false, // We handle cancellation manually
      ),
      const AndroidNotificationAction(
        actionOpenApp,
        '📖 Learn Now',
        showsUserInterface: true, // Opens the app
        cancelNotification: false,
      ),
    ];
  }

  /// Schedule a single notification with the selected strategy
  Future<void> _scheduleNotification({
    required int id,
    required Word word,
    required NotificationStrategy strategy,
    required tz.TZDateTime scheduledDate,
    required Word distractorWord,
  }) async {
    final content = _buildNotificationContent(word, strategy, distractorWord);

    // Build Android notification details with STICKY configuration
    AndroidNotificationDetails androidDetails;

    // Common sticky notification settings
    final stickyActions = _buildStickyActions();

    if (strategy == NotificationStrategy.microQuiz) {
      // Micro-Quiz strategy with quiz buttons + sticky actions
      final quizActions = <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionCorrect,
          word.word, // Correct answer
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          actionDistractor,
          distractorWord.word, // Distractor answer
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ];

      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true, // STICKY: Cannot be swiped away
        autoCancel: false, // STICKY: Won't dismiss on tap
        styleInformation: BigTextStyleInformation(content['body']!),
        actions: quizActions,
      );
    } else {
      // Other strategies - sticky notification with standard actions
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true, // STICKY: Cannot be swiped away
        autoCancel: false, // STICKY: Won't dismiss on tap
        styleInformation: BigTextStyleInformation(content['body']!),
        actions: stickyActions,
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      content['title'],
      content['body'],
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: word.english, // Word ID for navigation
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Build notification content based on strategy
  Map<String, String> _buildNotificationContent(
    Word word,
    NotificationStrategy strategy,
    Word distractorWord,
  ) {
    switch (strategy) {
      case NotificationStrategy.microQuiz:
        return {
          'title': '⚡ Quick Quiz: ${word.meaningVi}?',
          'body': 'Choose the correct English word below!',
        };

      case NotificationStrategy.fillBlank:
        final example = word.examplesEn.first;
        final maskedExample = _maskWordInSentence(example, word.word);
        return {
          'title': '🧩 Missing Word Challenge',
          'body': '$maskedExample (${word.meaningVi})\nTap to reveal!',
        };

      case NotificationStrategy.emotional:
        return {
          'title': '🚨 SOS! Memory Fading...',
          'body':
              "You haven't reviewed '${word.word}' recently! It's about to disappear from your brain. 🧠",
        };
    }
  }

  /// Replace target word with underscores in the sentence
  String _maskWordInSentence(String sentence, String targetWord) {
    // Case-insensitive replacement
    final regex = RegExp(targetWord, caseSensitive: false);
    final underscores = '_' * targetWord.length;
    return sentence.replaceAll(regex, underscores);
  }

  /// Show an immediate test notification (for debugging)
  Future<void> showTestNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: _buildStickyActions(),
    );

    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '🎯 Test Notification',
      'This is a STICKY notification. Use the buttons to dismiss!',
      notificationDetails,
      payload: 'test_word',
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('NotificationService: All notifications cancelled');
  }

  /// Get pending notification requests (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
