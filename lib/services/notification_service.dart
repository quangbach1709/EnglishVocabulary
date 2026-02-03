import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/word.dart';
import 'firestore_service.dart';

/// Enum representing game modes for interactive notifications
enum GameMode {
  multipleChoice, // Game A: Chọn từ đúng
  directInput, // Game B: Điền từ
}

/// Singleton service for interactive vocabulary learning notifications
/// Features: Spaced repetition, Multiple Choice, Direct Input games
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  // Notification channel constants
  static const String _channelId = 'vocabulary_games';
  static const String _channelName = 'Vocabulary Games';
  static const String _channelDescription =
      'Interactive vocabulary learning games with quizzes';

  // ============================================
  // Action Button Identifiers
  // ============================================
  static const String actionOpenApp = 'OPEN_APP';
  static const String actionShowAnswer = 'SHOW_ANSWER';
  static const String actionCorrect = 'CORRECT';
  static const String actionWrong1 = 'WRONG_1';
  static const String actionWrong2 = 'WRONG_2';
  static const String inputReplyKey = 'INPUT_REPLY';

  // ============================================
  // Scheduling Configuration: 3 times per day
  // ============================================
  static const List<Map<String, int>> _dailySchedules = [
    {'hour': 8, 'minute': 0}, // Morning
    {'hour': 12, 'minute': 0}, // Noon
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
  /// Priority 1 (80%): status == 0 (Forgot) or status == 1 (Hard)
  /// Priority 2 (20%): status >= 2 (Mastered) for review
  Future<Word?> _selectWordBySpacedRepetition(List<Word> allWords) async {
    if (allWords.isEmpty) return null;

    final random = Random();
    final roll = random.nextDouble();

    // Priority words: Forgot (0) or Hard (1)
    final priorityWords = allWords
        .where((w) => w.status == 0 || w.status == 1)
        .toList();

    // Review words: Good (2) or Easy (3)
    final reviewWords = allWords.where((w) => w.status >= 2).toList();

    List<Word> pool;

    if (roll < 0.80 && priorityWords.isNotEmpty) {
      // 80% chance: Pick from priority words
      pool = priorityWords;
      debugPrint(
        'NotificationService: Selected from priority pool (${pool.length} words)',
      );
    } else if (reviewWords.isNotEmpty) {
      // 20% chance: Pick from review words
      pool = reviewWords;
      debugPrint(
        'NotificationService: Selected from review pool (${pool.length} words)',
      );
    } else {
      // Fallback: Use all words
      pool = allWords;
      debugPrint(
        'NotificationService: Fallback to all words (${pool.length} words)',
      );
    }

    pool.shuffle();
    return pool.first;
  }

  /// Get distractor words for multiple choice (different from target)
  List<Word> _getDistractorWords(
    Word targetWord,
    List<Word> allWords,
    int count,
  ) {
    final distractors = <Word>[];
    final shuffled = List<Word>.from(allWords)..shuffle();

    for (final word in shuffled) {
      if (word.english != targetWord.english && distractors.length < count) {
        distractors.add(word);
      }
    }

    return distractors;
  }

  // ============================================
  // Notification Response Handlers
  // ============================================

  /// Handle notification response when app is in foreground/background
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      'NotificationService: Response - action: ${response.actionId}, '
      'payload: ${response.payload}, input: ${response.input}',
    );

    final notificationId = response.id;
    final payload = response.payload;
    final actionId = response.actionId;
    final userInput = response.input;

    // CRITICAL: Cancel the persistent notification immediately
    if (notificationId != null) {
      NotificationService()._cancelNotification(notificationId);
    }

    if (payload == null || payload.isEmpty) {
      debugPrint('NotificationService: No payload, ignoring');
      return;
    }

    // Parse payload JSON
    Map<String, dynamic> payloadData;
    try {
      payloadData = jsonDecode(payload);
    } catch (e) {
      // Legacy payload format (just word ID)
      payloadData = {'wordId': payload, 'type': 'unknown'};
    }

    final wordId = payloadData['wordId'] as String? ?? payload;
    // gameType could be 'multipleChoice' or 'directInput' - used for logging
    final correctAnswer = payloadData['correctAnswer'] as String? ?? '';

    // Handle based on action
    switch (actionId) {
      case actionCorrect:
        // User clicked correct answer
        _handleCorrectAnswer(wordId);
        debugPrint('NotificationService: Correct answer for "$wordId"');
        break;

      case actionWrong1:
      case actionWrong2:
        // User clicked wrong answer - navigate to learn
        _lastTappedWordId = wordId;
        _shouldNavigateToFlashcard = true;
        debugPrint('NotificationService: Wrong answer, navigate to flashcard');
        break;

      case actionShowAnswer:
        // Show answer - display a follow-up notification
        NotificationService()._showAnswerNotification(wordId, correctAnswer);
        break;

      case actionOpenApp:
      default:
        // Check if there's user input (Direct Input mode)
        if (userInput != null && userInput.isNotEmpty) {
          _handleDirectInput(wordId, userInput, correctAnswer);
        } else {
          // Navigate to flashcard
          _lastTappedWordId = wordId;
          _shouldNavigateToFlashcard = true;
          debugPrint(
            'NotificationService: Navigate to flashcard for "$wordId"',
          );
        }
        break;
    }
  }

  /// Handle notification response when app was terminated
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint(
      'NotificationService: Background response - action: ${response.actionId}, '
      'payload: ${response.payload}',
    );

    final notificationId = response.id;
    final payload = response.payload;
    final actionId = response.actionId;

    // Cancel the persistent notification
    if (notificationId != null) {
      NotificationService()._cancelNotification(notificationId);
    }

    if (payload == null || payload.isEmpty) return;

    // Parse payload
    Map<String, dynamic> payloadData;
    try {
      payloadData = jsonDecode(payload);
    } catch (e) {
      payloadData = {'wordId': payload};
    }

    final wordId = payloadData['wordId'] as String? ?? payload;

    if (actionId == actionCorrect) {
      _handleCorrectAnswer(wordId);
    } else if (actionId == actionWrong1 || actionId == actionWrong2) {
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
    } else {
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
    }
  }

  /// Handle correct answer - update word status
  static void _handleCorrectAnswer(String wordId) {
    debugPrint('NotificationService: Marking "$wordId" as reviewed');

    final firestoreService = FirestoreService();
    firestoreService
        .updateWordStatus(
          wordId,
          2, // Status 2 = Good
          DateTime.now().add(const Duration(days: 3)),
        )
        .then((_) {
          debugPrint('NotificationService: Word "$wordId" marked as reviewed');
        })
        .catchError((e) {
          debugPrint('NotificationService: Error updating word: $e');
        });
  }

  /// Handle direct input from user
  static void _handleDirectInput(
    String wordId,
    String userInput,
    String correctAnswer,
  ) {
    // Normalize both strings for comparison
    final normalizedInput = userInput.trim().toLowerCase();
    final normalizedCorrect = correctAnswer.trim().toLowerCase();

    if (normalizedInput == normalizedCorrect) {
      // Correct!
      _handleCorrectAnswer(wordId);
      debugPrint('NotificationService: Direct input CORRECT for "$wordId"');
    } else {
      // Wrong - navigate to learn
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
      debugPrint(
        'NotificationService: Direct input WRONG - expected "$correctAnswer", got "$userInput"',
      );

      // Show feedback notification
      NotificationService()._showWrongAnswerNotification(wordId, correctAnswer);
    }
  }

  /// Show notification with the answer
  Future<void> _showAnswerNotification(
    String wordId,
    String correctAnswer,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        '✅ Đáp án đúng là:\n\n"$correctAnswer"\n\nNhấn để học thêm!',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      998, // Special ID for answer notification
      '📖 Đáp án',
      'Từ: $wordId - $correctAnswer',
      notificationDetails,
      payload: wordId,
    );
  }

  /// Show wrong answer feedback notification
  Future<void> _showWrongAnswerNotification(
    String wordId,
    String correctAnswer,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        '❌ Sai rồi!\n\nĐáp án đúng là: "$correctAnswer"\n\nNhấn để ôn lại ngay!',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      997, // Special ID for wrong answer notification
      '❌ Sai rồi!',
      'Đáp án: $correctAnswer',
      notificationDetails,
      payload: wordId,
    );
  }

  /// Cancel a specific notification by ID
  Future<void> _cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('NotificationService: Cancelled notification $id');
  }

  // ============================================
  // Scheduling Logic
  // ============================================

  /// Schedule notifications for the next 7 days
  /// 3 notifications per day = 21 total
  Future<void> scheduleNext7Days() async {
    // Cancel all existing notifications
    await _notifications.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    // Fetch all words
    List<Word> allWords = [];
    try {
      allWords = await _firestoreService.getAllWords();
      debugPrint('NotificationService: Fetched ${allWords.length} words');
    } catch (e) {
      debugPrint('NotificationService: Error fetching words: $e');
      return;
    }

    if (allWords.length < 3) {
      debugPrint(
        'NotificationService: Not enough words (need at least 3), skipping',
      );
      return;
    }

    int totalScheduled = 0;
    final random = Random();

    // Outer loop: 7 days
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      // Inner loop: 3 time slots
      for (int slotIndex = 0; slotIndex < _dailySchedules.length; slotIndex++) {
        final schedule = _dailySchedules[slotIndex];
        final hour = schedule['hour']!;
        final minute = schedule['minute']!;

        // Select word using spaced repetition
        final word = await _selectWordBySpacedRepetition(allWords);
        if (word == null) continue;

        // Randomly select game mode
        final gameMode = random.nextBool()
            ? GameMode.multipleChoice
            : GameMode.directInput;

        // Get distractors for multiple choice
        final distractors = _getDistractorWords(word, allWords, 2);

        final scheduledDate = _getScheduledDate(
          daysFromNow: dayIndex + 1,
          hour: hour,
          minute: minute,
        );

        // Unique ID: (dayIndex * 10) + slotIndex
        final notificationId = (dayIndex * 10) + slotIndex;

        await _scheduleGameNotification(
          id: notificationId,
          word: word,
          gameMode: gameMode,
          scheduledDate: scheduledDate,
          distractors: distractors,
        );

        debugPrint(
          'NotificationService: Scheduled ID $notificationId - '
          'Day ${dayIndex + 1}, ${hour}h - ${gameMode.name} for "${word.word}"',
        );

        totalScheduled++;
      }
    }

    debugPrint('NotificationService: Scheduled $totalScheduled notifications');
  }

  /// Calculate scheduled date
  tz.TZDateTime _getScheduledDate({
    required int daysFromNow,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysFromNow,
      hour,
      minute,
    );

    if (daysFromNow == 0 && scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  // ============================================
  // Game Notification Builders
  // ============================================

  /// Schedule a game notification
  Future<void> _scheduleGameNotification({
    required int id,
    required Word word,
    required GameMode gameMode,
    required tz.TZDateTime scheduledDate,
    required List<Word> distractors,
  }) async {
    late NotificationDetails notificationDetails;
    late String title;
    late String body;
    late String payload;

    switch (gameMode) {
      case GameMode.multipleChoice:
        final result = _buildMultipleChoiceNotification(word, distractors);
        title = result['title']!;
        body = result['body']!;
        payload = result['payload']!;
        notificationDetails = result['details'] as NotificationDetails;
        break;

      case GameMode.directInput:
        final result = _buildDirectInputNotification(word);
        title = result['title']!;
        body = result['body']!;
        payload = result['payload']!;
        notificationDetails = result['details'] as NotificationDetails;
        break;
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Build Multiple Choice notification (Game Mode A)
  Map<String, dynamic> _buildMultipleChoiceNotification(
    Word word,
    List<Word> distractors,
  ) {
    final title = '🎯 Nghĩa của "${word.word}" là gì?';
    final body = 'Phát âm: [${word.ipa}]\nChọn đáp án đúng bên dưới!';

    // Create payload with game data
    final payload = jsonEncode({
      'type': 'multipleChoice',
      'wordId': word.english,
      'correctAnswer': word.meaningVi,
    });

    // Build shuffled action buttons
    final actions = <Map<String, dynamic>>[
      {'id': actionCorrect, 'label': word.meaningVi},
    ];

    for (int i = 0; i < distractors.length && i < 2; i++) {
      actions.add({
        'id': i == 0 ? actionWrong1 : actionWrong2,
        'label': distractors[i].meaningVi,
      });
    }

    // Shuffle the actions so correct isn't always first
    actions.shuffle();

    final androidActions = actions.map((a) {
      final isCorrect = a['id'] == actionCorrect;
      return AndroidNotificationAction(
        a['id'] as String,
        a['label'] as String,
        showsUserInterface: !isCorrect, // Open app if wrong
        cancelNotification: false,
      );
    }).toList();

    // Add "Open App" button
    androidActions.add(
      const AndroidNotificationAction(
        actionOpenApp,
        '📖 Mở App',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    );

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      styleInformation: BigTextStyleInformation(body),
      actions: androidActions,
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

  /// Build Direct Input notification (Game Mode B)
  Map<String, dynamic> _buildDirectInputNotification(Word word) {
    final title = '✍️ Điền nghĩa tiếng Việt:';
    final body =
        'Word: ${word.word} [${word.ipa}]\n\nNhập đáp án hoặc nhấn "Hiện đáp án"';

    // Create payload with game data
    final payload = jsonEncode({
      'type': 'directInput',
      'wordId': word.english,
      'correctAnswer': word.meaningVi,
    });

    // Build actions with input field
    final androidActions = <AndroidNotificationAction>[
      // Input field action
      AndroidNotificationAction(
        actionOpenApp,
        'Trả lời',
        showsUserInterface: true,
        cancelNotification: false,
        inputs: <AndroidNotificationActionInput>[
          const AndroidNotificationActionInput(
            label: 'Nhập đáp án...',
            allowFreeFormInput: true,
          ),
        ],
      ),
      // Show answer button
      const AndroidNotificationAction(
        actionShowAnswer,
        '👀 Hiện đáp án',
        showsUserInterface: false,
        cancelNotification: false,
      ),
      // Open app button
      const AndroidNotificationAction(
        actionOpenApp,
        '📖 Mở App',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      styleInformation: BigTextStyleInformation(body),
      actions: androidActions,
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
    try {
      words = await _firestoreService.getAllWords();
    } catch (e) {
      debugPrint('NotificationService: Error fetching words: $e');
      return;
    }

    if (words.length < 3) {
      debugPrint('NotificationService: Not enough words for test');
      return;
    }

    final random = Random();
    final testWord = words[random.nextInt(words.length)];
    final distractors = _getDistractorWords(testWord, words, 2);
    final gameMode = random.nextBool()
        ? GameMode.multipleChoice
        : GameMode.directInput;

    late NotificationDetails details;
    late String title;
    late String body;
    late String payload;

    if (gameMode == GameMode.multipleChoice) {
      final result = _buildMultipleChoiceNotification(testWord, distractors);
      title = result['title']!;
      body = result['body']!;
      payload = result['payload']!;
      details = result['details'] as NotificationDetails;
    } else {
      final result = _buildDirectInputNotification(testWord);
      title = result['title']!;
      body = result['body']!;
      payload = result['payload']!;
      details = result['details'] as NotificationDetails;
    }

    await _notifications.show(999, title, body, details, payload: payload);

    debugPrint(
      'NotificationService: Test - ${gameMode.name} for "${testWord.word}"',
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('NotificationService: All notifications cancelled');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
