import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../models/grammar_topic.dart';

/// Singleton service for Firestore operations on vocabulary and grammar data
class FirestoreService {
  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dynamic user ID from Firebase Auth
  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirestoreException('User not authenticated');
    }
    return user.uid;
  }

  // Collection paths (now dynamic based on authenticated user)
  String get _vocabularyPath => 'users/$_userId/vocabulary';
  String get _grammarPath => 'users/$_userId/grammar_topics';

  /// Reference to the vocabulary collection
  CollectionReference<Map<String, dynamic>> get _vocabularyCollection =>
      _firestore.collection(_vocabularyPath);

  /// Reference to the grammar collection
  CollectionReference<Map<String, dynamic>> get _grammarCollection =>
      _firestore.collection(_grammarPath);

  // ============================================
  // Vocabulary Methods
  // ============================================

  /// Adds a new word to Firestore
  Future<void> addWord(Word word) async {
    try {
      await _vocabularyCollection
          .doc(word.english)
          .set(word.toMap())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to add word: $e');
    }
  }

  /// Deletes a word from Firestore
  Future<void> deleteWord(String englishWord) async {
    try {
      await _vocabularyCollection
          .doc(englishWord.toLowerCase())
          .delete()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to delete word: $e');
    }
  }

  /// Fetches all words from the vocabulary collection
  Future<List<Word>> getAllWords() async {
    try {
      final querySnapshot = await _vocabularyCollection
          .get()
          .timeout(const Duration(seconds: 15));
      return querySnapshot.docs.map((doc) => Word.fromMap(doc.data())).toList();
    } catch (e) {
      throw FirestoreException('Failed to fetch words: $e');
    }
  }

  /// Fetches "Cram" words (Status 0 or 1)
  Future<List<Word>> getCramWords() async {
    try {
      final querySnapshot = await _vocabularyCollection
          .where('status', whereIn: [0, 1])
          .get()
          .timeout(const Duration(seconds: 15));
      return querySnapshot.docs.map((doc) => Word.fromMap(doc.data())).toList();
    } catch (e) {
      throw FirestoreException('Failed to fetch cram words: $e');
    }
  }

  /// Fetches priority words for notifications
  Future<List<Word>> getPriorityWords() async {
    try {
      final querySnapshot = await _vocabularyCollection
          .where('status', whereIn: [0, 1])
          .limit(14)
          .get()
          .timeout(const Duration(seconds: 15));
      final words = querySnapshot.docs
          .map((doc) => Word.fromMap(doc.data()))
          .toList();
      words.shuffle();
      return words;
    } catch (e) {
      throw FirestoreException('Failed to fetch priority words: $e');
    }
  }

  /// Updates the status and nextReviewDate for a specific word
  Future<void> updateWordStatus(
    String englishWord,
    int status,
    DateTime nextReview,
  ) async {
    try {
      await _vocabularyCollection.doc(englishWord.toLowerCase()).update({
        'status': status,
        'next_review_date': Timestamp.fromDate(nextReview),
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to update word status: $e');
    }
  }

  /// Mark word as 'Forgot' (Reset SRS)
  Future<void> markWordAsForgot(Word word) async {
    try {
      final updatedWord = word.copyWith(
        status: 0,
        interval: 0,
        nextReviewDate: DateTime.now(),
        easeFactor: (word.easeFactor - 0.2).clamp(1.3, 2.5),
      );
      await updateWord(updatedWord);
    } catch (e) {
      throw FirestoreException('Failed to mark word as forgot: $e');
    }
  }

  /// Updates a word completely
  Future<void> updateWord(Word word) async {
    try {
      await _vocabularyCollection
          .doc(word.english)
          .update(word.toMap())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to update word: $e');
    }
  }

  /// Gets a single word
  Future<Word?> getWord(String englishWord) async {
    try {
      final docSnapshot = await _vocabularyCollection
          .doc(englishWord.toLowerCase())
          .get()
          .timeout(const Duration(seconds: 15));
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return Word.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get word: $e');
    }
  }

  /// Checks if a word exists
  Future<bool> wordExists(String englishWord) async {
    try {
      final docSnapshot = await _vocabularyCollection
          .doc(englishWord.toLowerCase())
          .get()
          .timeout(const Duration(seconds: 10));
      return docSnapshot.exists;
    } catch (e) {
      throw FirestoreException('Failed to check word existence: $e');
    }
  }

  /// Gets a stream of all words
  Stream<List<Word>> wordsStream() {
    return _vocabularyCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Word.fromMap(doc.data())).toList(),
    );
  }

  /// Batch add multiple words with timeout
  Future<void> addWords(List<Word> words) async {
    try {
      final batch = _firestore.batch();
      for (final word in words) {
        batch.set(_vocabularyCollection.doc(word.english), word.toMap());
      }
      await batch.commit().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw FirestoreException('Thời gian gửi dữ liệu quá lâu. Vui lòng kiểm tra mạng!'),
          );
    } catch (e) {
      throw FirestoreException('Lỗi thêm hàng loạt: $e');
    }
  }

  /// Batch update multiple words with timeout
  Future<void> updateWords(List<Word> words) async {
    try {
      final batch = _firestore.batch();
      for (final word in words) {
        batch.set(
          _vocabularyCollection.doc(word.english),
          word.toMap(),
          SetOptions(merge: true),
        );
      }
      await batch.commit().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw FirestoreException('Kết nối Firestore bị quá hạn. Vui lòng kiểm tra mạng!'),
          );
    } catch (e) {
      throw FirestoreException('Lỗi cập nhật hàng loạt: $e');
    }
  }

  /// Batch delete multiple words with timeout
  Future<void> deleteWords(List<String> englishWords) async {
    try {
      final batch = _firestore.batch();
      for (final englishWord in englishWords) {
        batch.delete(_vocabularyCollection.doc(englishWord.toLowerCase()));
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw FirestoreException('Failed to delete words: $e');
    }
  }

  /// Deletes all words in the collection
  Future<void> deleteAllWords() async {
    try {
      final querySnapshot = await _vocabularyCollection.get();
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw FirestoreException('Failed to delete all words: $e');
    }
  }

  // ============================================
  // Grammar Methods
  // ============================================

  /// Saves a grammar topic
  Future<void> saveGrammarTopic(GrammarTopic topic) async {
    try {
      await _grammarCollection
          .doc(topic.id)
          .set(topic.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to save grammar topic: $e');
    }
  }

  /// Fetches all grammar topics
  Future<List<GrammarTopic>> getAllGrammarTopics() async {
    try {
      final querySnapshot = await _grammarCollection
          .get()
          .timeout(const Duration(seconds: 15));
      return querySnapshot.docs
          .map((doc) => GrammarTopic.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to fetch grammar topics: $e');
    }
  }

  /// Deletes a grammar topic by ID
  Future<void> deleteGrammarTopic(String topicId) async {
    try {
      await _grammarCollection
          .doc(topicId)
          .delete()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to delete grammar topic: $e');
    }
  }

  // ============================================
  // User Settings Methods
  // ============================================

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('users').doc(_userId);

  Future<Map<String, dynamic>> fetchUserSettings() async {
    try {
      final doc = await _settingsDoc.get().timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return {
        'apiKey': '',
        'modelName': 'gemini-1.5-flash',
        'speechRate': 0.5,
        'ttsLanguage': 'en-US',
        'isPersistentMode': false,
      };
    } catch (e) {
      throw FirestoreException('Failed to fetch user settings: $e');
    }
  }

  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsDoc
          .set(settings, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FirestoreException('Failed to save user settings: $e');
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    try {
      await _settingsDoc
          .set({key: value}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw FirestoreException('Failed to update setting: $e');
    }
  }
}

class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);

  @override
  String toString() => 'FirestoreException: $message';
}
