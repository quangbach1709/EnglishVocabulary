import '../models/word.dart';
import '../services/firestore_service.dart';

/// Repository layer that wraps FirestoreService for vocabulary data
class WordRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// Gets all words from Firestore
  Future<List<Word>> getWords() async {
    return await _firestoreService.getAllWords();
  }

  /// Adds a new word to Firestore
  Future<void> addWord(Word word) async {
    await _firestoreService.addWord(word);
  }

  /// Deletes a word by its English text
  Future<void> deleteWord(String englishWord) async {
    await _firestoreService.deleteWord(englishWord);
  }

  /// Updates a word in Firestore
  Future<void> updateWord(Word word) async {
    await _firestoreService.updateWord(word);
  }

  /// Checks if a word exists
  Future<bool> wordExists(String englishWord) async {
    return await _firestoreService.wordExists(englishWord);
  }

  /// Gets a stream of words for real-time updates
  Stream<List<Word>> wordsStream() {
    return _firestoreService.wordsStream();
  }

  /// Batch add multiple words
  Future<void> addWords(List<Word> words) async {
    await _firestoreService.addWords(words);
  }

  /// Updates word SRS status
  Future<void> updateWordStatus(
    String englishWord,
    int status,
    DateTime nextReview,
  ) async {
    await _firestoreService.updateWordStatus(englishWord, status, nextReview);
  }
}
