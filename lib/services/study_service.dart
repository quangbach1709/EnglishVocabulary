import '../models/word.dart';
import '../repositories/word_repository.dart';

class StudyService {
  final WordRepository _repository = WordRepository();

  /// Generates a daily study queue consisting of words due for review
  /// and a limited number of new words.
  Future<List<Word>> generateDailyQueue({int newWordsLimit = 20}) async {
    final allWords = await _repository.getWords();
    final now = DateTime.now();

    // Query 1 (Review Words): nextReviewDate <= now AND status > 0 (box > 1)
    // We treat status > 0 as words that have been studied at least once.
    final reviewWords = allWords.where((word) {
      final isDue = word.nextReviewDate != null &&
          (word.nextReviewDate!.isBefore(now) ||
              word.nextReviewDate!.isAtSameMomentAs(now));
      final isReview = (word.status) > 0;
      return isDue && isReview;
    }).toList();

    // Query 2 (New Words): status == 0 (box == 1)
    // Words with status 0 are those never studied or marked as "Forgot".
    // For "New" words, we usually look for those that haven't been scheduled yet.
    final newWords = allWords.where((word) {
      final isNew = (word.status) == 0;
      return isNew;
    }).toList();

    // Limit new words and shuffle for variety
    newWords.shuffle();
    final limitedNewWords = newWords.take(newWordsLimit).toList();

    // Merge & Shuffle
    final dailyQueue = [...reviewWords, ...limitedNewWords];
    dailyQueue.shuffle();

    return dailyQueue;
  }

  /// Helper to get counts for the home screen display
  Future<Map<String, int>> getDailyCounts() async {
    final allWords = await _repository.getWords();
    final now = DateTime.now();

    final reviewCount = allWords.where((word) {
      final isDue = word.nextReviewDate != null &&
          (word.nextReviewDate!.isBefore(now) ||
              word.nextReviewDate!.isAtSameMomentAs(now));
      final isReview = (word.status) > 0;
      return isDue && isReview;
    }).length;

    final newCount = allWords.where((word) => word.status == 0).length;

    return {
      'review': reviewCount,
      'new': newCount,
    };
  }
}
