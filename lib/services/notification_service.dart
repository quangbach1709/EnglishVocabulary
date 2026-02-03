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
  /// Priority 1 (70%): status == 0 (Forgot) - Chua thuoc, can on luyen nhieu
  /// Priority 2 (20%): status == 1 (Hard) - Kho, can on luyen
  /// Priority 3 (8%): status == 2 (Good) - Da thuoc, on tap dinh ky
  /// Priority 4 (2%): status >= 3 (Easy) - Thao roi, on tap it
  Future<Word?> _selectWordBySpacedRepetition(List<Word> allWords) async {
    if (allWords.isEmpty) return null;

    final random = Random();
    final roll = random.nextDouble();

    // Status 0: Chua thuoc (Forgot) - can on nhieu nhat
    final forgotWords = allWords.where((w) => w.status == 0).toList();

    // Status 1: Kho (Hard) - can on thuong xuyen
    final hardWords = allWords.where((w) => w.status == 1).toList();

    // Status 2: Da thuoc (Good) - on tap dinh ky
    final goodWords = allWords.where((w) => w.status == 2).toList();

    // Status 3+: Thao roi (Easy) - on tap it
    final easyWords = allWords.where((w) => w.status >= 3).toList();

    List<Word> pool;
    String poolName;

    if (roll < 0.70 && forgotWords.isNotEmpty) {
      // 70% chance: Pick from forgot words (status 0)
      pool = forgotWords;
      poolName = 'FORGOT (status=0)';
    } else if (roll < 0.90 && hardWords.isNotEmpty) {
      // 20% chance: Pick from hard words (status 1)
      pool = hardWords;
      poolName = 'HARD (status=1)';
    } else if (roll < 0.98 && goodWords.isNotEmpty) {
      // 8% chance: Pick from good words (status 2)
      pool = goodWords;
      poolName = 'GOOD (status=2)';
    } else if (easyWords.isNotEmpty) {
      // 2% chance: Pick from easy words (status 3+)
      pool = easyWords;
      poolName = 'EASY (status>=3)';
    } else if (forgotWords.isNotEmpty) {
      // Fallback to forgot words
      pool = forgotWords;
      poolName = 'FALLBACK-FORGOT';
    } else if (hardWords.isNotEmpty) {
      pool = hardWords;
      poolName = 'FALLBACK-HARD';
    } else if (goodWords.isNotEmpty) {
      pool = goodWords;
      poolName = 'FALLBACK-GOOD';
    } else {
      // Ultimate fallback: Use all words
      pool = allWords;
      poolName = 'ALL-WORDS';
    }

    debugPrint(
      'NotificationService: Selected from $poolName pool (${pool.length} words)',
    );

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
        // User clicked wrong answer - show feedback notification
        _lastTappedWordId = wordId;
        _shouldNavigateToFlashcard = true;
        debugPrint('NotificationService: Wrong answer for "$wordId"');

        // Show wrong answer notification with correct answer
        NotificationService()._showWrongAnswerNotification(
          wordId,
          correctAnswer,
        );
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
    final userInput = response.input;

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
    final correctAnswer = payloadData['correctAnswer'] as String? ?? '';

    if (actionId == actionCorrect) {
      _handleCorrectAnswer(wordId);
    } else if (actionId == actionWrong1 || actionId == actionWrong2) {
      // Wrong answer in multiple choice - show feedback
      _lastTappedWordId = wordId;
      _shouldNavigateToFlashcard = true;
      NotificationService()._showWrongAnswerNotification(wordId, correctAnswer);
    } else if (actionId == actionShowAnswer) {
      // Show answer
      NotificationService()._showAnswerNotification(wordId, correctAnswer);
    } else if (userInput != null && userInput.isNotEmpty) {
      // Direct input mode
      _handleDirectInput(wordId, userInput, correctAnswer);
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
    // Check if answer is correct using flexible matching
    final isCorrect = _isAnswerCorrect(userInput, correctAnswer);

    if (isCorrect) {
      // Correct!
      _handleCorrectAnswer(wordId);
      debugPrint('NotificationService: Direct input CORRECT for "$wordId"');

      // Show success notification
      NotificationService()._showCorrectAnswerNotification(
        wordId,
        correctAnswer,
      );
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

  /// Flexible answer matching
  /// Returns true if userInput matches any acceptable form of correctAnswer
  static bool _isAnswerCorrect(String userInput, String correctAnswer) {
    // Normalize input
    final input = _normalizeText(userInput);
    final correct = _normalizeText(correctAnswer);

    // 1. Exact match after normalization
    if (input == correct) return true;

    // 2. Split correct answer by common separators and check each part
    // Separators: comma, semicolon, slash, "hoặc", "hay", parentheses content
    final separators = RegExp(r'[,;/]|\s+hoặc\s+|\s+hay\s+');
    final correctParts = correct
        .split(separators)
        .map((s) => _normalizeText(s))
        .where((s) => s.isNotEmpty)
        .toList();

    // Check if input matches any part exactly
    for (final part in correctParts) {
      if (input == part) return true;
    }

    // 3. Check if input is contained in correct answer (for partial match)
    // e.g., correct = "học sinh, sinh viên", input = "học sinh" -> match
    if (correct.contains(input) && input.length >= 2) return true;

    // 4. Check if any part of correct answer is contained in input
    for (final part in correctParts) {
      if (part.isNotEmpty && input.contains(part) && part.length >= 2)
        return true;
    }

    // 5. Remove content in parentheses from correct answer and check
    // e.g., correct = "học sinh (n)", input = "học sinh" -> match
    final correctWithoutParens = _normalizeText(
      correct.replaceAll(RegExp(r'\([^)]*\)'), ''),
    );
    if (input == correctWithoutParens) return true;

    // 6. Check similarity for typo tolerance (Levenshtein-like)
    // If the input is very similar (>80% match), consider it correct
    for (final part in correctParts) {
      if (_calculateSimilarity(input, part) > 0.8) return true;
    }

    return false;
  }

  /// Normalize text for comparison
  static String _normalizeText(String text) {
    var result = text.trim().toLowerCase();
    // Replace multiple spaces with single space
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    // Remove trailing punctuation
    result = result.replaceAll(RegExp(r'[.,!?;:]+$'), '');
    return result;
  }

  /// Calculate similarity between two strings (0.0 to 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.isEmpty) return 1.0;

    // Simple similarity based on common characters
    int matches = 0;
    for (int i = 0; i < shorter.length; i++) {
      if (i < longer.length && shorter[i] == longer[i]) {
        matches++;
      }
    }

    return matches / longer.length;
  }

  /// Show notification with the answer (when user clicks "Show Answer")
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

  /// Show correct answer feedback notification (when user answers correctly)
  Future<void> _showCorrectAnswerNotification(
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
      timeoutAfter: 5000, // Auto dismiss after 5 seconds
      styleInformation: BigTextStyleInformation(
        '🎉 Chính xác!\n\n"$correctAnswer"\n\nGiỏi lắm, tiếp tục phát huy!',
      ),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      996, // Special ID for correct answer notification
      '✅ Đúng rồi!',
      correctAnswer,
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

  /// Schedule notifications for TODAY and the next 7 days
  /// 5 notifications per day = up to 40 total
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
    final now = tz.TZDateTime.now(tz.local);

    // ========================================
    // STEP 1: Schedule for TODAY (remaining time slots)
    // ========================================
    for (int slotIndex = 0; slotIndex < _dailySchedules.length; slotIndex++) {
      final schedule = _dailySchedules[slotIndex];
      final hour = schedule['hour']!;
      final minute = schedule['minute']!;

      // Check if this time slot is still in the future
      final todaySlot = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (todaySlot.isAfter(now)) {
        // This slot is still in the future today - schedule it!
        final word = await _selectWordBySpacedRepetition(allWords);
        if (word == null) continue;

        final gameMode = random.nextBool()
            ? GameMode.multipleChoice
            : GameMode.directInput;
        final distractors = _getDistractorWords(word, allWords, 2);

        // Unique ID for today: 1000 + slotIndex
        final notificationId = 1000 + slotIndex;

        await _scheduleGameNotification(
          id: notificationId,
          word: word,
          gameMode: gameMode,
          scheduledDate: todaySlot,
          distractors: distractors,
        );

        debugPrint(
          'NotificationService: Scheduled TODAY ID $notificationId - '
          '${hour}:${minute.toString().padLeft(2, '0')} - ${gameMode.name} for "${word.word}"',
        );
        totalScheduled++;
      }
    }

    // ========================================
    // STEP 2: Schedule for the next 7 days
    // ========================================
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
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

        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + dayIndex,
          hour,
          minute,
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
          'Day +$dayIndex, ${hour}:${minute.toString().padLeft(2, '0')} - ${gameMode.name} for "${word.word}"',
        );

        totalScheduled++;
      }
    }

    debugPrint(
      'NotificationService: Total scheduled: $totalScheduled notifications',
    );

    // Log pending notifications for debugging
    final pending = await getPendingNotifications();
    debugPrint(
      'NotificationService: Pending notifications count: ${pending.length}',
    );
    for (final p in pending.take(5)) {
      debugPrint('  - ID ${p.id}: ${p.title}');
    }
  }

  /// Schedule notifications with custom times from user settings
  Future<void> scheduleWithCustomTimes(
    List<Map<String, int>> customSchedules,
  ) async {
    // Cancel all existing notifications
    await _notifications.cancelAll();
    debugPrint('NotificationService: Cancelled all existing notifications');

    if (customSchedules.isEmpty) {
      debugPrint('NotificationService: No custom schedules provided');
      return;
    }

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
    final now = tz.TZDateTime.now(tz.local);

    // ========================================
    // STEP 1: Schedule for TODAY (remaining time slots)
    // ========================================
    for (int slotIndex = 0; slotIndex < customSchedules.length; slotIndex++) {
      final schedule = customSchedules[slotIndex];
      final hour = schedule['hour'] ?? 8;
      final minute = schedule['minute'] ?? 0;

      // Check if this time slot is still in the future
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

        final gameMode = random.nextBool()
            ? GameMode.multipleChoice
            : GameMode.directInput;
        final distractors = _getDistractorWords(word, allWords, 2);

        final notificationId = 1000 + slotIndex;

        await _scheduleGameNotification(
          id: notificationId,
          word: word,
          gameMode: gameMode,
          scheduledDate: todaySlot,
          distractors: distractors,
        );

        debugPrint(
          'NotificationService: Scheduled TODAY ID $notificationId - '
          '${hour}:${minute.toString().padLeft(2, '0')} - ${gameMode.name} for "${word.word}"',
        );
        totalScheduled++;
      }
    }

    // ========================================
    // STEP 2: Schedule for the next 7 days
    // ========================================
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      for (int slotIndex = 0; slotIndex < customSchedules.length; slotIndex++) {
        final schedule = customSchedules[slotIndex];
        final hour = schedule['hour'] ?? 8;
        final minute = schedule['minute'] ?? 0;

        final word = await _selectWordBySpacedRepetition(allWords);
        if (word == null) continue;

        final gameMode = random.nextBool()
            ? GameMode.multipleChoice
            : GameMode.directInput;
        final distractors = _getDistractorWords(word, allWords, 2);

        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + dayIndex,
          hour,
          minute,
        );

        final notificationId = (dayIndex * 100) + slotIndex;

        await _scheduleGameNotification(
          id: notificationId,
          word: word,
          gameMode: gameMode,
          scheduledDate: scheduledDate,
          distractors: distractors,
        );

        debugPrint(
          'NotificationService: Scheduled ID $notificationId - '
          'Day +$dayIndex, ${hour}:${minute.toString().padLeft(2, '0')} - ${gameMode.name} for "${word.word}"',
        );

        totalScheduled++;
      }
    }

    debugPrint(
      'NotificationService: Total scheduled with custom times: $totalScheduled notifications',
    );

    final pending = await getPendingNotifications();
    debugPrint(
      'NotificationService: Pending notifications count: ${pending.length}',
    );
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
      // Show a simple notification to verify notifications work
      await _showSimpleNotification(
        'Test Notification',
        'Notifications are working! But you need at least 3 words.',
      );
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

  /// Show a simple notification (for testing purposes)
  Future<void> _showSimpleNotification(String title, String body) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      autoCancel: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(888, title, body, notificationDetails);
    debugPrint('NotificationService: Simple notification shown');
  }

  /// Schedule a test notification in [seconds] seconds
  /// This helps verify that scheduled notifications work
  Future<void> scheduleTestNotificationIn(int seconds) async {
    List<Word> words = [];
    try {
      words = await _firestoreService.getAllWords();
    } catch (e) {
      debugPrint('NotificationService: Error fetching words: $e');
      return;
    }

    if (words.length < 3) {
      debugPrint('NotificationService: Not enough words for scheduled test');
      return;
    }

    final random = Random();
    final testWord = words[random.nextInt(words.length)];
    final distractors = _getDistractorWords(testWord, words, 2);
    final gameMode = random.nextBool()
        ? GameMode.multipleChoice
        : GameMode.directInput;

    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    await _scheduleGameNotification(
      id: 777,
      word: testWord,
      gameMode: gameMode,
      scheduledDate: scheduledDate,
      distractors: distractors,
    );

    debugPrint(
      'NotificationService: Scheduled test in $seconds seconds for "${testWord.word}"',
    );
  }

  /// Get debug info about notification status
  Future<Map<String, dynamic>> getDebugInfo() async {
    final pending = await getPendingNotifications();
    final permissions = await checkPermissions();

    return {
      'permissionsGranted': permissions,
      'pendingCount': pending.length,
      'pendingNotifications': pending
          .take(10)
          .map(
            (p) => {
              'id': p.id,
              'title': p.title,
              'body': p.body?.substring(
                0,
                (p.body?.length ?? 0) > 50 ? 50 : p.body?.length ?? 0,
              ),
            },
          )
          .toList(),
    };
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
